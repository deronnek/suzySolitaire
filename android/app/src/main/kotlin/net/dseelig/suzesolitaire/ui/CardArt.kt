package net.dseelig.suzesolitaire.ui

import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ImageDecoder
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import net.dseelig.suzesolitaire.R
import net.dseelig.suzesolitaire.game.Card
import java.io.File

// The four sets of card faces, made from the iOS app's SVGs (see scripts/import-cards.py, CardVectors and VectorArt):
// big corner ranks for the small cards
// of a phone-sized table, or the full design for a roomy table's big cards, each with its ranks in Arial or Abril
// Fatface.  The game uses the Arial ones; the Debug menu can show any of them.  Each set has its own corner radius, as a
// fraction of the card's width: the small cards' corners have a radius of 10 of the card's 167 units, and the large
// ones' 6.86 inside a 0.25 margin, so their curve is centred 7.11 in from each edge.
enum class CardFaces(val title: String, val cornerFraction: Float, val files: IntArray) {
    SmallArial("Small, Arial", 10f / 167.0869141f, CardVectors.smallArial),
    SmallAbril("Small, Abril Fatface", 10f / 167.0869141f, CardVectors.smallAbril),
    LargeArial("Large, Arial", 7.11f / 167.0869141f, CardVectors.largeArial),
    LargeAbril("Large, Abril Fatface", 7.11f / 167.0869141f, CardVectors.largeAbril);

    companion object {
        // The faces the game shows on a table of either size
        fun standard(roomy: Boolean) = if (roomy) LargeArial else SmallArial
    }
}

object CardArt {

    // The last set of faces read, kept so a new size (a rotation, a fold) only needs drawing
    private var parsed: Pair<CardFaces, List<VectorArt>>? = null

    private suspend fun art(resources: Resources, cardFaces: CardFaces): List<VectorArt> = coroutineScope {
        synchronized(this@CardArt) { parsed?.takeIf { it.first == cardFaces }?.second }
            ?: cardFaces.files.map { file ->
                async(Dispatchers.Default) { VectorArt.read(resources.openRawResource(file).use { it.readBytes() }) }
            }.awaitAll().also { synchronized(this@CardArt) { parsed = cardFaces to it } }
    }

    // A set of faces drawn at the size they're shown, in Card number order (see Card), and the back
    class Faces(val widthPx: Int, val cardFaces: CardFaces, val faces: List<ImageBitmap>, val back: ImageBitmap)

    // Draws the faces a few at a time, since the face cards' art takes a moment each
    suspend fun decode(resources: Resources, widthPx: Int, cardFaces: CardFaces, customBack: File?): Faces =
        coroutineScope {
            val started = System.nanoTime()
            val heightPx = (widthPx * TableLayout.ASPECT).toInt()
            val art = art(resources, cardFaces)
            android.util.Log.i("CardArt", "Read ${cardFaces.name} in ${(System.nanoTime() - started) / 1_000_000} ms")
            val faces = Card.all.map { card ->
                async(Dispatchers.Default) { render(art[card.id], widthPx, heightPx) }
            }
            // Backs chosen before their corners were left to the drawing come with them cut at the small cards' radius, so
            // the picture is drawn 2% bigger than the card to reach past them into the large cards' tighter corners
            fun decode(source: ImageDecoder.Source) = ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
                val bigWidth = (widthPx * 1.02f).toInt()
                val bigHeight = (heightPx * 1.02f).toInt()
                decoder.setTargetSize(bigWidth, bigHeight)
                val left = (bigWidth - widthPx) / 2
                val top = (bigHeight - heightPx) / 2
                decoder.crop = android.graphics.Rect(left, top, left + widthPx, top + heightPx)
            }.asImageBitmap()
            val back = customBack?.takeIf { it.exists() }?.let { runCatching { decode(ImageDecoder.createSource(it)) }.getOrNull() }
                ?: decode(ImageDecoder.createSource(resources, R.drawable.card_back))
            Faces(widthPx, cardFaces, faces.awaitAll(), back).also {
                android.util.Log.i("CardArt", "Drew ${cardFaces.name} at $widthPx px in ${(System.nanoTime() - started) / 1_000_000} ms")
            }
        }

    private fun render(art: VectorArt, widthPx: Int, heightPx: Int): ImageBitmap {
        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        art.draw(Canvas(bitmap), widthPx, heightPx)
        return bitmap.asImageBitmap()
    }
}
