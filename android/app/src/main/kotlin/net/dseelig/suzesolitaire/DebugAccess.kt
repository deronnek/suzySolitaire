package net.dseelig.suzesolitaire

import java.math.BigInteger
import java.security.AlgorithmParameters
import java.security.KeyFactory
import java.security.MessageDigest
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.security.spec.ECParameterSpec
import java.security.spec.ECPoint
import java.security.spec.ECPublicKeySpec
import java.util.Base64
import net.dseelig.suzesolitaire.game.Card
import net.dseelig.suzesolitaire.game.Table

// The Debug section of the menu, for trying out things that are hard to reach by playing, such as winning, and the other
// sets of card faces.  Debuggable builds always have it.  Others have it only on phones unlocked for an engineer, as in
// the iOS app: a long press on the score shows the phone's code, scripts/debug-unlock.sh signs it with a private key kept
// off the repo, and the signature pasted back unlocks that phone alone.  (Android can't tell a Play testing track from
// the store itself, so unlike iOS a store copy can be unlocked too, by someone with the key.)
object DebugAccess {
    const val UNLOCK_KEY = "DebugUnlock"
    const val CARD_FACES_KEY = "DebugCardFaces"

    // The public half of the key scripts/debug-unlock.sh signs with, as an uncompressed P-256 point (the iOS app's too)
    private const val PUBLIC_KEY = "BPe5Gm1nJoI/ZZacIF5VhIe+55zySg73efHpT+6dJJk0VuFfQ2noCjMKqcBT0odK6c2mpAgP2cjhrZk/Qjpozjk="

    private val publicKey: ECPublicKey by lazy {
        val point = Base64.getDecoder().decode(PUBLIC_KEY)
        val params = AlgorithmParameters.getInstance("EC").apply { init(ECGenParameterSpec("secp256r1")) }
            .getParameterSpec(ECParameterSpec::class.java)
        val x = BigInteger(1, point.copyOfRange(1, 33))
        val y = BigInteger(1, point.copyOfRange(33, 65))
        KeyFactory.getInstance("EC").generatePublic(ECPublicKeySpec(ECPoint(x, y), params)) as ECPublicKey
    }

    // Eight letters and digits that stand for this phone, from its ID for this app's signing key (Settings.Secure
    // ANDROID_ID), made the way the iOS app makes them so the same script signs both.  They change only on a factory reset.
    fun deviceCode(deviceId: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest("Suze Solitaire $deviceId".toByteArray())
        // Crockford's base 32, which leaves out letters that look like digits
        val alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
        val bits = digest.take(5).fold(0L) { acc, byte -> acc shl 8 or (byte.toLong() and 0xff) }
        return (0 until 8).map { alphabet[(bits shr (35 - 5 * it) and 31).toInt()] }.joinToString("")
    }

    // An unlock is the key's signature of "Suze Solitaire debug unlock <code>", in URL-safe base 64, as
    // scripts/debug-unlock.sh prints it
    fun isValid(unlock: String, code: String): Boolean = runCatching {
        val der = Base64.getUrlDecoder().decode(unlock.filterNot(Char::isWhitespace).trimEnd('='))
        Signature.getInstance("SHA256withECDSA").run {
            initVerify(publicKey)
            update("Suze Solitaire debug unlock $code".toByteArray())
            verify(der)
        }
    }.getOrDefault(false)

    // How a code shows on screen, as ABCD-1234
    fun pretty(code: String) = code.take(4) + "-" + code.drop(4)

    // AppStore/Screenshots/game-almost-won.json, as the iOS app's Debug menu deals it: one card from winning, which
    // Auto Moves puts up when it's on
    val ALMOST_WON = Table(
        blind = emptyList(), deck = emptyList(), deal = emptyList(),
        upper = listOf(listOf(45, 46, 47, 48, 49, 50, 51, 39, 40, 41), listOf(32, 33, 34, 35, 36, 37, 38, 26, 27),
                       listOf(6, 7, 8, 9, 10, 11, 12, 0), listOf(19, 20, 21, 22, 23, 24, 25, 13, 14)).map { it.map(::Card) },
        lower = listOf(listOf(5, 30, 3, 28, 1), listOf(31, 4, 16), listOf(18, 43, 29, 2), listOf(44, 17, 42, 15)).map { it.map(::Card) },
        starter = 7,
    )
}
