package net.dseelig.suzesolitaire.ui

import android.content.res.Resources
import android.graphics.ImageDecoder
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import net.dseelig.suzesolitaire.R
import net.dseelig.suzesolitaire.game.Card
import java.io.File

// The card faces, in Card number order (see Card).  The small art, with big corner indexes, is for the phone layout;
// the large art, with pips, for the roomy one, as in the iOS app.
object CardArt {
    private val small = intArrayOf(
        R.drawable.small_club1,
        R.drawable.small_club2,
        R.drawable.small_club3,
        R.drawable.small_club4,
        R.drawable.small_club5,
        R.drawable.small_club6,
        R.drawable.small_club7,
        R.drawable.small_club8,
        R.drawable.small_club9,
        R.drawable.small_club10,
        R.drawable.small_club11,
        R.drawable.small_club12,
        R.drawable.small_club13,
        R.drawable.small_diamond1,
        R.drawable.small_diamond2,
        R.drawable.small_diamond3,
        R.drawable.small_diamond4,
        R.drawable.small_diamond5,
        R.drawable.small_diamond6,
        R.drawable.small_diamond7,
        R.drawable.small_diamond8,
        R.drawable.small_diamond9,
        R.drawable.small_diamond10,
        R.drawable.small_diamond11,
        R.drawable.small_diamond12,
        R.drawable.small_diamond13,
        R.drawable.small_heart1,
        R.drawable.small_heart2,
        R.drawable.small_heart3,
        R.drawable.small_heart4,
        R.drawable.small_heart5,
        R.drawable.small_heart6,
        R.drawable.small_heart7,
        R.drawable.small_heart8,
        R.drawable.small_heart9,
        R.drawable.small_heart10,
        R.drawable.small_heart11,
        R.drawable.small_heart12,
        R.drawable.small_heart13,
        R.drawable.small_spade1,
        R.drawable.small_spade2,
        R.drawable.small_spade3,
        R.drawable.small_spade4,
        R.drawable.small_spade5,
        R.drawable.small_spade6,
        R.drawable.small_spade7,
        R.drawable.small_spade8,
        R.drawable.small_spade9,
        R.drawable.small_spade10,
        R.drawable.small_spade11,
        R.drawable.small_spade12,
        R.drawable.small_spade13,
    )
    private val large = intArrayOf(
        R.drawable.large_club1,
        R.drawable.large_club2,
        R.drawable.large_club3,
        R.drawable.large_club4,
        R.drawable.large_club5,
        R.drawable.large_club6,
        R.drawable.large_club7,
        R.drawable.large_club8,
        R.drawable.large_club9,
        R.drawable.large_club10,
        R.drawable.large_club11,
        R.drawable.large_club12,
        R.drawable.large_club13,
        R.drawable.large_diamond1,
        R.drawable.large_diamond2,
        R.drawable.large_diamond3,
        R.drawable.large_diamond4,
        R.drawable.large_diamond5,
        R.drawable.large_diamond6,
        R.drawable.large_diamond7,
        R.drawable.large_diamond8,
        R.drawable.large_diamond9,
        R.drawable.large_diamond10,
        R.drawable.large_diamond11,
        R.drawable.large_diamond12,
        R.drawable.large_diamond13,
        R.drawable.large_heart1,
        R.drawable.large_heart2,
        R.drawable.large_heart3,
        R.drawable.large_heart4,
        R.drawable.large_heart5,
        R.drawable.large_heart6,
        R.drawable.large_heart7,
        R.drawable.large_heart8,
        R.drawable.large_heart9,
        R.drawable.large_heart10,
        R.drawable.large_heart11,
        R.drawable.large_heart12,
        R.drawable.large_heart13,
        R.drawable.large_spade1,
        R.drawable.large_spade2,
        R.drawable.large_spade3,
        R.drawable.large_spade4,
        R.drawable.large_spade5,
        R.drawable.large_spade6,
        R.drawable.large_spade7,
        R.drawable.large_spade8,
        R.drawable.large_spade9,
        R.drawable.large_spade10,
        R.drawable.large_spade11,
        R.drawable.large_spade12,
        R.drawable.large_spade13,
    )

    fun faceResource(card: Card, roomy: Boolean) = (if (roomy) large else small)[card.id]

    // A set of faces decoded at the size they're drawn, rather than the art's full 500 x 726, which would take about
    // 1.5MB a card
    class Faces(val widthPx: Int, val roomy: Boolean, val faces: List<ImageBitmap>, val back: ImageBitmap)

    fun decode(resources: Resources, widthPx: Int, roomy: Boolean, customBack: File?): Faces {
        val heightPx = (widthPx * TableLayout.ASPECT).toInt()
        fun decode(source: ImageDecoder.Source) = ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
            decoder.setTargetSize(widthPx, heightPx)
        }.asImageBitmap()
        val faces = Card.all.map { decode(ImageDecoder.createSource(resources, faceResource(it, roomy))) }
        val back = customBack?.takeIf { it.exists() }?.let { runCatching { decode(ImageDecoder.createSource(it)) }.getOrNull() }
            ?: decode(ImageDecoder.createSource(resources, R.drawable.card_back))
        return Faces(widthPx, roomy, faces, back)
    }
}
