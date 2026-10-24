package net.dseelig.suzesolitaire.ui

import net.dseelig.suzesolitaire.game.Pile
import net.dseelig.suzesolitaire.game.Spot
import kotlin.math.max
import kotlin.math.min

// A rectangle in dp
data class Box(val left: Float, val top: Float, val width: Float, val height: Float) {
    val right get() = left + width
    val bottom get() = top + height
    val centerX get() = left + width / 2
    val centerY get() = top + height / 2

    fun intersects(other: Box) = left < other.right && other.left < right && top < other.bottom && other.top < bottom
    fun contains(x: Float, y: Float) = x in left..right && y in top..bottom
}

// The space the system bars and display cutout take from each edge, in dp
data class Insets(val left: Float = 0f, val top: Float = 0f, val right: Float = 0f, val bottom: Float = 0f)

// Where everything on the table goes for a window of a given size, in dp, following the iOS app's layout:
//
// - New Game in the top left corner, Undo in the top right, and the "more" button in the bottom right, all the same size,
//   with the score along the bottom beside it.
// - Portrait: the blind over the deck and deal on the left, the four upper stacks over the four lower ones on the right,
//   lined up with the outer edges of New Game and Undo.
// - Landscape: two long rows between New Game and Undo, starting level with them: the blind, deck and deal, then the upper
//   stacks; and the lower stacks below the upper ones.  On a tablet, as on the iPad, the cards stop above the row of the
//   score and menu button, and the banner goes in that row, beside the menu button.  A phone needs more room to read its
//   lower stacks than the iPhone layout gives them, so they run down to the bottom of the screen beside the menu button,
//   and the score and the banner go in the bottom left corner, under the blind, deck and deal.
// - A roomy window (600dp or more both ways: a tablet, or a foldable unfolded) gets bigger buttons and margins, the large
//   card art, cards a little closer together, and stacks fanned a fixed 30dp; anything smaller gets the phone layout.
class TableLayout(val width: Float, val height: Float, val insets: Insets = Insets()) {
    val roomy = min(width, height) >= 600f
    val landscape = width > height

    val buttonSize = if (roomy) 56f else 48f
    private val margin = if (roomy) 24f else 16f

    // Under the status bar, or the cutout, with a little more room in portrait
    private val buttonsTop = insets.top + if (landscape) (if (roomy) 12f else 8f) else (if (roomy) 20f else 12f)
    private val buttonsLeft = max(margin, insets.left)
    private val buttonsRight = width - max(margin, insets.right)
    // As far from the bottom as the top buttons are from the status bar, but clear of the navigation bar
    private val buttonsBelow = max(max(insets.bottom + 8f, buttonsTop - insets.top), margin)

    val newGame = Box(buttonsLeft, buttonsTop, buttonSize, buttonSize)
    val undo = Box(buttonsRight - buttonSize, buttonsTop, buttonSize, buttonSize)
    val menu = Box(buttonsRight - buttonSize, height - buttonsBelow - buttonSize, buttonSize, buttonSize)

    // How far down the cards may reach: in portrait, to just above the banner over the menu button and the score; in
    // landscape, the lower stacks to the bottom of the screen, and the blind, deck and deal to just above the banner
    val tableBottom: Float
    private val lowerBottom: Float

    val cardWidth: Float
    val cardHeight: Float
    private val positions: Map<Spot, Pair<Float, Float>>
    // How far each card in a lower stack sits below the one under it when there's room, and how far an upper stack's
    // top card sits below its first, so the starter peeks out
    private val baseSlice: Float

    // The score, wins and losses: along the bottom, level with the menu button, from the left margin to just before it
    // (in landscape, to just before the lower stacks)
    val score: Box

    init {
        val spots = mutableMapOf<Spot, Pair<Float, Float>>()
        val portraitBottom = menu.top - BANNER_SPACING - BANNER_HEIGHT - 8f
        if (landscape) {
            val top = undo.top
            val left = newGame.right + 16f
            val right = undo.left - 16f
            tableBottom = if (roomy) menu.top - 8f else portraitBottom
            lowerBottom = if (roomy) tableBottom else height - max(insets.bottom + 4f, 12f)
            // Two rows of cards, the upper stacks' starters peeking out, and room to fan the lower stacks
            var h = (lowerBottom - top) / (if (roomy) 2.8f else 3.4f)
            var w = h / ASPECT
            var gap = w / (if (roomy) 8f else 5f)
            val stacksGap = if (roomy) 0.4f else 0.6f
            val rowWidth = { 7 * w + 5 * gap + w * stacksGap }
            if (rowWidth() > right - left) {
                val scale = (right - left) / rowWidth()
                w *= scale; h *= scale; gap *= scale
            }
            val rowLeft = left + (right - left - rowWidth()) / 2
            // Enough of the upper stacks' first card shows to read it, and of each card in a lower stack
            val peek = if (roomy) ROOMY_SLICE else h * 0.3f
            val second = top + h + peek + h * (if (roomy) 0.1f else 0.08f)
            spots[Spot.Blind] = rowLeft to top
            spots[Spot.Deck] = rowLeft + w + gap to top
            spots[Spot.Deal] = rowLeft + 2 * (w + gap) to top
            val stacksLeft = rowLeft + 3 * w + 2 * gap + w * stacksGap
            for (i in 0 until 4) {
                spots[Spot.upper(i)] = stacksLeft + i * (w + gap) to top
                spots[Spot.lower(i)] = stacksLeft + i * (w + gap) to second
            }
            cardWidth = w; cardHeight = h
            baseSlice = peek
            // On a tablet the score leaves the rest of the row to the banner
            val scoreRight = if (roomy) min(buttonsLeft + 4f + ROOMY_SCORE_WIDTH, menu.left - 16f) else stacksLeft - 16f
            score = Box(buttonsLeft + 4f, menu.top, max(0f, scoreRight - buttonsLeft - 4f), buttonSize)
        }
        else {
            val left = newGame.left
            val right = undo.right
            val w = (right - left) / (if (roomy) 7.6f else 7f)
            val h = w * ASPECT
            val spacer = if (roomy) w * 0.2f else w / 15f
            val top = undo.bottom + 10f + h * 0.1f
            // The second row starts just below the blind with all 13 of its cards fanned out
            val second = top + h + 12 * FANNED_SLICE + h * 0.15f
            spots[Spot.Blind] = left to top
            spots[Spot.Deck] = left to second
            spots[Spot.Deal] = left + w * 1.4f to second
            for (i in 0 until 4) {
                val x = right - 4 * w - 3 * spacer + i * (w + spacer)
                spots[Spot.upper(i)] = x to top
                spots[Spot.lower(i)] = x to second
            }
            cardWidth = w; cardHeight = h
            baseSlice = if (roomy) ROOMY_SLICE else h / 2.5f
            tableBottom = portraitBottom
            lowerBottom = portraitBottom
            score = Box(buttonsLeft + 4f, menu.top, max(0f, menu.left - 16f - buttonsLeft - 4f), buttonSize)
        }
        positions = spots
    }

    // The top left of a spot: of its first card, or of its outline when it's empty
    fun origin(spot: Spot): Pair<Float, Float> = positions.getValue(spot)

    fun outline(spot: Spot): Box = origin(spot).let { (x, y) -> Box(x, y, cardWidth, cardHeight) }

    // How far apart the cards of a stack of count cards are fanned: the blind and deal a little, lower stacks enough to
    // read each card, squeezed closer when a long stack would run past the bottom of the table
    fun slice(spot: Spot, count: Int): Float {
        val base = when (spot.pile) {
            Pile.Blind, Pile.Deal -> FANNED_SLICE
            Pile.Lower, Pile.Upper -> baseSlice
            Pile.Deck -> 0f
        }
        if (spot.pile == Pile.Upper || spot.pile == Pile.Deck || count < 2) {
            return base
        }
        val room = (if (spot.pile == Pile.Lower) lowerBottom else tableBottom) - origin(spot).second - cardHeight
        return max(2f, min(base, room / (count - 1)))
    }

    // Where card index of a stack of count cards goes.  An upper stack shows its first card peeking out above its top.
    fun cardBox(spot: Spot, index: Int, count: Int): Box {
        val (x, y) = origin(spot)
        val offset = when (spot.pile) {
            Pile.Deck -> 0f
            Pile.Upper -> if (index > 0) slice(spot, count) else 0f
            else -> index * slice(spot, count)
        }
        return Box(x, y + offset, cardWidth, cardHeight)
    }

    // The whole area a stack covers, for finding where a card is dropped
    fun stackBox(spot: Spot, count: Int): Box {
        val first = cardBox(spot, 0, count)
        val last = cardBox(spot, max(0, count - 1), count)
        return Box(first.left, first.top, cardWidth, last.bottom - first.top)
    }

    // How wide the banner may be
    val bannerMaxWidth: Float get() = when {
        landscape && roomy -> max(0f, menu.left - BANNER_SPACING - score.right - BANNER_SPACING)
        landscape -> score.width
        else -> width - 32f
    }

    // Where the "nothing to play" banner goes: centered just above the menu button and the score in portrait; in a
    // tablet's landscape beside the menu button, level with it; or in a phone's landscape above the score, in the corner
    // the blind, deck and deal leave free
    fun banner(bannerWidth: Float): Box =
        if (landscape && roomy) {
            Box(menu.left - BANNER_SPACING - bannerWidth, menu.centerY - BANNER_HEIGHT / 2, bannerWidth, BANNER_HEIGHT)
        }
        else if (landscape) {
            Box(score.left, menu.top - BANNER_SPACING - BANNER_HEIGHT, bannerWidth, BANNER_HEIGHT)
        }
        else {
            Box((width - bannerWidth) / 2, menu.top - BANNER_SPACING - BANNER_HEIGHT, bannerWidth, BANNER_HEIGHT)
        }

    companion object {
        // Height / width of the card images
        const val ASPECT = 726f / 500f
        // Corner radius as a fraction of card width, matching the corners cut into the card images
        const val CORNER_FRACTION = 0.06f
        const val FANNED_SLICE = 5f
        const val BANNER_HEIGHT = 48f
        const val BANNER_SPACING = 8f
        // How far apart a roomy table fans its stacks, as the iPad does
        const val ROOMY_SLICE = 30f
        // Room for the score, wins and losses beside the banner in a tablet's landscape
        const val ROOMY_SCORE_WIDTH = 360f
    }
}
