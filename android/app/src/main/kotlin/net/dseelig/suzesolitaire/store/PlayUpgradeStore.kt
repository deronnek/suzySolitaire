package net.dseelig.suzesolitaire.store

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.acknowledgePurchase
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.coroutines.resume

// Unlimited Undo through Google Play Billing.  Google Play keeps purchases with the Google account, so they come back on
// a new phone or after reinstalling without a Restore button: refresh asks Play what this account owns.  A purchase has
// to be acknowledged within three days or Play refunds it, so every one is acknowledged as soon as it's seen.
class PlayUpgradeStore(context: Context, private val scope: CoroutineScope) : UpgradeStore {
    private val mutableState = MutableStateFlow(UpgradeState(owned = OwnedCache.read(context)))
    override val state: StateFlow<UpgradeState> = mutableState
    private val appContext = context.applicationContext
    private var product: ProductDetails? = null
    private var purchaseResult: CompletableDeferred<PurchaseOutcome>? = null
    private val connecting = Mutex()

    private val client: BillingClient = BillingClient.newBuilder(context)
        .setListener { result, purchases -> onPurchasesUpdated(result, purchases) }
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection()
        .build()

    override suspend fun refresh() {
        if (!connect()) {
            return
        }
        val result = client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build())
        if (result.billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
            val ours = result.purchasesList.filter { UpgradeStore.PRODUCT_ID in it.products }
            ours.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }.forEach { acknowledge(it) }
            // A refunded or cancelled purchase is no longer listed
            setOwned(ours.any { it.purchaseState == Purchase.PurchaseState.PURCHASED },
                pending = ours.any { it.purchaseState == Purchase.PurchaseState.PENDING })
        }
        loadProduct()
    }

    override suspend fun buy(activity: Activity): PurchaseOutcome {
        if (!connect()) {
            return PurchaseOutcome.Failed("Google Play couldn't be reached. Try again later.")
        }
        val product = loadProduct() ?: return PurchaseOutcome.Failed("Unlimited Undo isn't available from Google Play yet. Try again later.")
        val offer = product.oneTimePurchaseOfferDetailsList?.firstOrNull()
        val details = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(product)
            .apply { offer?.offerToken?.let(::setOfferToken) }
            .build()
        val outcome = CompletableDeferred<PurchaseOutcome>()
        purchaseResult = outcome
        val launch = client.launchBillingFlow(activity, BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(details)).build())
        if (launch.responseCode != BillingClient.BillingResponseCode.OK) {
            purchaseResult = null
            return outcomeFor(launch)
        }
        return outcome.await()
    }

    private fun onPurchasesUpdated(result: BillingResult, purchases: List<Purchase>?) {
        val ours = purchases.orEmpty().filter { UpgradeStore.PRODUCT_ID in it.products }
        val outcome = when {
            result.responseCode != BillingClient.BillingResponseCode.OK -> outcomeFor(result)
            ours.any { it.purchaseState == Purchase.PurchaseState.PURCHASED } -> PurchaseOutcome.Purchased
            ours.any { it.purchaseState == Purchase.PurchaseState.PENDING } -> PurchaseOutcome.Pending
            else -> PurchaseOutcome.Cancelled
        }
        when (outcome) {
            PurchaseOutcome.Purchased -> setOwned(true, pending = false)
            PurchaseOutcome.Pending -> setOwned(state.value.owned, pending = true)
            else -> {}
        }
        purchaseResult?.complete(outcome)
        purchaseResult = null
        // Acknowledge in the background; refresh catches any that fail
        if (outcome == PurchaseOutcome.Purchased) {
            scope.launch { ours.forEach { acknowledge(it) } }
        }
    }

    private fun outcomeFor(result: BillingResult): PurchaseOutcome = when (result.responseCode) {
        BillingClient.BillingResponseCode.USER_CANCELED -> PurchaseOutcome.Cancelled
        BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> {
            setOwned(true, pending = false)
            PurchaseOutcome.Purchased
        }
        BillingClient.BillingResponseCode.SERVICE_UNAVAILABLE, BillingClient.BillingResponseCode.SERVICE_DISCONNECTED,
        BillingClient.BillingResponseCode.NETWORK_ERROR -> PurchaseOutcome.Failed("Google Play couldn't be reached. Try again later.")
        BillingClient.BillingResponseCode.BILLING_UNAVAILABLE -> PurchaseOutcome.Failed("Purchases aren't available on this device or account.")
        else -> PurchaseOutcome.Failed("Google Play couldn't complete the purchase (${result.debugMessage.ifEmpty { "error ${result.responseCode}" }}).")
    }

    private suspend fun acknowledge(purchase: Purchase) {
        if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED && !purchase.isAcknowledged) {
            client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build())
        }
    }

    private suspend fun loadProduct(): ProductDetails? {
        product?.let { return it }
        if (!connect()) {
            return null
        }
        val query = QueryProductDetailsParams.newBuilder().setProductList(listOf(
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(UpgradeStore.PRODUCT_ID)
                .setProductType(BillingClient.ProductType.INAPP)
                .build())).build()
        val result = client.queryProductDetails(query)
        product = result.productDetailsList?.firstOrNull()
        product?.oneTimePurchaseOfferDetailsList?.firstOrNull()?.formattedPrice?.let { price ->
            mutableState.value = mutableState.value.copy(price = price)
        }
        return product
    }

    private suspend fun connect(): Boolean = connecting.withLock {
        if (client.isReady) {
            return true
        }
        suspendCancellableCoroutine { continuation ->
            client.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(result: BillingResult) {
                    if (continuation.isActive) {
                        continuation.resume(result.responseCode == BillingClient.BillingResponseCode.OK)
                    }
                }

                override fun onBillingServiceDisconnected() {
                    if (continuation.isActive) {
                        continuation.resume(false)
                    }
                }
            })
        }
    }

    private fun setOwned(owned: Boolean, pending: Boolean) {
        mutableState.value = mutableState.value.copy(owned = owned, pending = pending && !owned)
        OwnedCache.write(appContext, owned)
    }
}

// What Google Play said last time, so Unlimited Undo is on from the first frame instead of after Play answers
private object OwnedCache {
    private const val PREFS = "purchases"
    private const val KEY = "unlimitedUndoOwned"

    fun read(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY, false)

    fun write(context: Context, owned: Boolean) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY, owned).apply()
}
