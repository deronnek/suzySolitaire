package net.dseelig.suzesolitaire.ui

import net.dseelig.suzesolitaire.game.Card
import net.dseelig.suzesolitaire.game.Pile
import net.dseelig.suzesolitaire.game.Spot
import net.dseelig.suzesolitaire.game.Suit
import net.dseelig.suzesolitaire.game.Table
import kotlin.math.max
import kotlin.math.min

// Where a card is drawn, and how
data class Placed(
    val card: Card,
    val spot: Spot,
    val index: Int,
    val box: Box,
    // Drawing order: later stacks and higher cards on top
    val z: Float,
    val faceUp: Boolean,
    // A card under the top of the blind or deal shows a blank face, so its fanned edge doesn't give away what it is
    val covered: Boolean,
    // Overlapping shadows add up, so stacks whose cards sit close together only shadow the cards that outline them
    val shadowed: Boolean,
)

object Placement {

    // Every card's place on the table.  lifted is the card being dragged off the blind or deal, which shows the card under
    // it, as it will be once the move is made.
    fun place(table: Table, layout: TableLayout, lifted: Pair<Spot, Int>? = null): List<Placed> =
        Spot.all.flatMapIndexed { spotNumber, spot ->
            val cards = table.cards(spot)
            val closeTogether = spot.pile == Pile.Deck || layout.slice(spot, cards.size) < 12f
            cards.mapIndexed { i, card ->
                val top = i == cards.lastIndex
                val uncovered = lifted != null && lifted.first == spot && i == lifted.second - 1
                Placed(
                    card = card,
                    spot = spot,
                    index = i,
                    box = layout.cardBox(spot, i, cards.size),
                    z = spotNumber * 100f + i,
                    faceUp = spot.pile != Pile.Deck,
                    covered = (spot.pile == Pile.Blind || spot.pile == Pile.Deal) && !top && !uncovered,
                    shadowed = !closeTogether || top || i == 0,
                )
            }
        }

    // After a win: the four suits in rows across the table, each fanned to fit the width, as the iOS app's victory lap
    // lays them out
    fun victory(layout: TableLayout): List<Placed> {
        val w = layout.cardWidth
        val h = layout.cardHeight
        val left = max(16f, layout.insets.left + 8f)
        val right = layout.width - max(16f, layout.insets.right + 8f)
        val step = min(w * 0.735f, (right - left - w) / 12f)
        val rowWidth = w + 12 * step
        val rowGap = min(h + 8f, (layout.menu.top - layout.undo.bottom - h - 16f) / 3f)
        val top = layout.undo.bottom + 8f + max(0f, (layout.menu.top - layout.undo.bottom - 16f - 3 * rowGap - h) / 2f)
        return Suit.entries.flatMapIndexed { row, suit ->
            (1..13).map { rank ->
                val card = Card.of(rank, suit)
                Placed(card, Spot.upper(row), rank - 1, Box(left + (right - left - rowWidth) / 2 + (rank - 1) * step, top + row * rowGap, w, h),
                    z = row * 100f + rank, faceUp = true, covered = false, shadowed = true)
            }
        }
    }
}
