package net.dseelig.suzesolitaire.game

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import kotlin.random.Random

class WinnableDealsTest {

    private val kinds = listOf("theory", "cunning")

    private fun text(kind: String) = generateSequence(File("").absoluteFile) { it.parentFile }
        .map { File(it, "app/src/main/res/raw/deals_$kind.txt") }.first { it.exists() }.readText()
    private fun lines(kind: String) = text(kind).lines().filter { it.isNotBlank() }

    // Each deal with the moves scripts/winnable-deals.py won it with: D deals, and card>U or card>L<i> moves a card up
    // or to a lower stack
    private fun solutions(kind: String) =
        javaClass.classLoader!!.getResource("solutions_$kind.txt")!!.readText().lines().filter { it.isNotBlank() }

    @Test
    fun everyDealIsAWholeDeck() {
        for (kind in kinds) {
            assertTrue(kind, lines(kind).size > 1000)
            for (line in lines(kind)) {
                assertEquals(line, 52, WinnableDeals.decode(line).toSet().size)
            }
        }
        // Those a player won without peeking can be won in theory too, so there are fewer of them
        assertTrue(lines("cunning").size < lines("theory").size)
    }

    @Test
    fun theFoundMovesWinUnderTheAppsRules() {
        for (kind in kinds) {
            playThrough(lines(kind), solutions(kind))
        }
    }

    private fun playThrough(lines: List<String>, solutions: List<String>) {
        assertEquals(100, solutions.size)
        solutions.forEachIndexed { i, solution ->
            val (deal, moves) = solution.split(" | ")
            assertEquals(lines[i], deal.split(" ").joinToString("") { WinnableDeals.LETTERS[it.toInt()].toString() })
            // As found, and turned round and swapped as New Game may deal it
            for ((shift, swap) in listOf(0 to 0, i % 13 to i % 8)) {
                val relabel = { id: String -> WinnableDeals.relabel(Card(id.toInt()), shift, swap) }
                var table = Table.deal(deal.split(" ").map(relabel))
                for (move in moves.split(" ")) {
                    if (move == "D") {
                        table = table.dealt()
                        continue
                    }
                    val card = relabel(move.substringBefore(">"))
                    val from = table.spotOf(card)
                    val index = table.cards(from).indexOf(card)
                    val dest = move.substringAfter(">")
                    val to = if (dest == "U") Spot.uppers.firstOrNull { table.canMove(from, index, it) } else Spot.lower(dest.drop(1).toInt())
                    assertTrue("deal $i, $move", to != null && table.canMove(from, index, to))
                    table = table.move(from, index, to!!)
                }
                assertTrue("deal $i", table.isWon)
            }
        }
    }

    @Test
    fun relabellingKeepsColorsAndRanksInStep() {
        // As the iOS app does (testRelabellingMatchesTheAndroidApp)
        assertEquals(Card.of(2, Suit.Diamonds), WinnableDeals.relabel(Card.of(1, Suit.Clubs), 1, 4))
        assertEquals(Card.of(1, Suit.Diamonds), WinnableDeals.relabel(Card.of(13, Suit.Hearts), 1, 2))
        for (swap in 0 until 8) {
            for (shift in 0 until 13) {
                val cards = Card.all.map { WinnableDeals.relabel(it, shift, swap) }
                assertEquals(52, cards.toSet().size)
                for ((a, b) in Card.all.zip(cards)) {
                    assertEquals((a.rank - 1 + shift) % 13 + 1, b.rank)
                    // Cards of a color stay together, and of a suit
                    assertEquals(a.isRed != (swap and 4 != 0), b.isRed)
                    assertTrue(Card.all.filter { it.suit == a.suit }.all { WinnableDeals.relabel(it, shift, swap).suit == b.suit })
                }
            }
        }
    }

    @Test
    fun newGameDealsOneOfThem() {
        val lines = lines("cunning")
        val deals = WinnableDeals.parse(text("cunning"))
        val session = Session(Game.first(Random(1)))
        session.newGame(Random(2), winnable = deals)
        val table = session.table
        val dealt = Table.deal(deals.shuffled(Random(2)))
        assertEquals(dealt, table)
        // Some turning and swapping of one of the lines
        val variants = lines.flatMap { line -> (0 until 13).flatMap { shift -> (0 until 8).map { Table.deal(WinnableDeals.variant(line, shift, it)) } } }
        assertTrue(table in variants)
    }
}
