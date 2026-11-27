package net.dseelig.suzesolitaire.ui

import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ImageDecoder
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import net.dseelig.suzesolitaire.R
import net.dseelig.suzesolitaire.game.Card
import java.io.File

// The sets of card faces, made from the same SVGs as the iOS app's (see scripts/import-cards.py, CardVectors and
// VectorArt): big corner ranks for the small cards of a phone-sized table, or the full design for a roomy table's big
// cards, each with its ranks in Roboto or Abril Fatface, and two of our own artwork laid out like the small ones, in
// watercolor and in a café racer's Bauhaus colors.  Roboto stands in for the iOS app's Arial, which Android doesn't
// have.  The game uses big ranks in Abril Fatface, the set most our own, unless the player picks others in the menu's
// Cards › Artwork.  Each set has its own corner radius, as a fraction of the card's width: the small cards' corners,
// and our own decks', have a radius of 10 of the card's 167 units, and the large ones' 6.86 inside a 0.25 margin, so
// their curve is centred 7.11 in from each edge.  Each has the color of its paper, for the blank faces covered cards
// show, and may bring a back of its own, shown unless the player picks a photo.
enum class CardFaces(val title: String, val cornerFraction: Float, val files: IntArray, val paper: Color = Color.White,
                     val back: Int? = null) {
    SmallRoboto("Big Ranks, Roboto", 10f / 167.0869141f, CardVectors.smallRoboto),
    SmallAbril("Big Ranks, Abril Fatface", 10f / 167.0869141f, CardVectors.smallAbril),
    LargeRoboto("Classic, Roboto", 7.11f / 167.0869141f, CardVectors.largeRoboto),
    LargeAbril("Classic, Abril Fatface", 7.11f / 167.0869141f, CardVectors.largeAbril),
    Watercolor("Watercolor", 10f / 167.0869141f, CardVectors.watercolor, Color(0xFFF5EEDD), CardVectors.watercolorBack),
    Racer("Café Racer", 10f / 167.0869141f, CardVectors.racer, Color(0xFFF2EDE2), CardVectors.racerBack);

    companion object {
        // The faces the game shows on a table of any size, unless the player picks others
        val standard = SmallAbril
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
            // A deck's own back is drawn to fit, since it has its corners already
            val back = customBack?.takeIf { it.exists() }?.let { runCatching { decode(ImageDecoder.createSource(it)) }.getOrNull() }
                ?: cardFaces.back?.let { file -> render(VectorArt.read(resources.openRawResource(file).use { it.readBytes() }), widthPx, heightPx) }
                ?: decode(ImageDecoder.createSource(resources, R.drawable.card_back))
            Faces(widthPx, cardFaces, faces.awaitAll(), back).also {
                android.util.Log.i("CardArt", "Drew ${cardFaces.name} at $widthPx px in ${(System.nanoTime() - started) / 1_000_000} ms")
            }
        }

    // A set's king of hearts, for the menu to show what the set looks like
    fun preview(resources: Resources, cardFaces: CardFaces, widthPx: Int): ImageBitmap {
        val king = cardFaces.files[KING_OF_HEARTS]
        return render(VectorArt.read(resources.openRawResource(king).use { it.readBytes() }), widthPx, (widthPx * TableLayout.ASPECT).toInt())
    }

    private const val KING_OF_HEARTS = 38

    private fun render(art: VectorArt, widthPx: Int, heightPx: Int): ImageBitmap {
        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        art.draw(Canvas(bitmap), widthPx, heightPx)
        return bitmap.asImageBitmap()
    }
}
