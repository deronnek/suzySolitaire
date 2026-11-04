package net.dseelig.suzesolitaire.store

import android.app.Activity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

// Unlimited Undo, a one-time purchase.  The app sees it through this, so tests and screenshots can stand in for
// Google Play (see FakeUpgradeStore).
interface UpgradeStore {
    val state: StateFlow<UpgradeState>

    // Checks what's owned and loads the price; called when the app starts and whenever it comes back to the front, so
    // purchases made elsewhere, approved later or refunded are noticed
    suspend fun refresh()

    suspend fun buy(activity: Activity): PurchaseOutcome

    companion object {
        // The same product ID as the iOS app's in-app purchase
        const val PRODUCT_ID = "unlimited_undo"
    }
}

data class UpgradeState(
    val owned: Boolean = false,
    // The price as Google Play shows it to this person, such as "$5.00", once it's loaded
    val price: String? = null,
    // Bought, but waiting for payment or approval
    val pending: Boolean = false,
)

sealed interface PurchaseOutcome {
    data object Purchased : PurchaseOutcome
    data object Pending : PurchaseOutcome
    data object Cancelled : PurchaseOutcome
    data class Failed(val message: String) : PurchaseOutcome
}

// A store that sells instantly, for tests and screenshot builds
class FakeUpgradeStore(owned: Boolean = false, price: String = "$5.00") : UpgradeStore {
    private val mutableState = MutableStateFlow(UpgradeState(owned = owned, price = price))
    override val state: StateFlow<UpgradeState> = mutableState

    override suspend fun refresh() {}

    override suspend fun buy(activity: Activity): PurchaseOutcome {
        mutableState.value = mutableState.value.copy(owned = true)
        return PurchaseOutcome.Purchased
    }

    fun refund() {
        mutableState.value = mutableState.value.copy(owned = false)
    }
}
