package net.dseelig.suzesolitaire.game

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

fun card(rank: Int, suit: Suit) = Card.of(rank, suit)

// A table with the given cards placed and every other card in the deck, starting the upper stacks at starter
fun table(
    lower: List<List<Card>> = List(4) { emptyList() },
    upper: List<List<Card>> = List(4) { emptyList() },
    blind: List<Card> = emptyList(),
    deal: List<Card> = emptyList(),
    deck: List<Card>? = null,
    starter: Int = 1,
): Table {
    val placed = (lower.flatten() + upper.flatten() + blind + deal + (deck ?: emptyList())).toSet()
    val rest = Card.all.filter { it !in placed }
    return Table(blind, deck ?: rest, deal, upper, lower, starter)
}

// Lower stacks nothing on the table can go on, from the iOS tests
fun deadLowerStacks() = listOf(listOf(card(5, Suit.Spades)), listOf(card(5, Suit.Hearts)), listOf(card(9, Suit.Clubs)), listOf(card(9, Suit.Diamonds)))

class TableTest {

    @Test
    fun newTableUsesEveryCardOnce() {
        val table = Table.deal(Card.all.shuffled(Random(3)))
        assertEquals(13, table.blind.size)
        assertEquals(34, table.deck.size)
        assertEquals(1, table.upper[0].size)
        assertTrue(table.upper.drop(1).all { it.isEmpty() })
        assertTrue(table.lower.all { it.size == 1 })
        assertEquals(table.upper[0][0].rank, table.starter)
        assertTrue(table.isValid)
    }

    @Test
    fun seededShuffleRepeats() {
        assertEquals(Table.deal(Card.all.shuffled(Random(12))), Table.deal(Card.all.shuffled(Random(12))))
    }

    @Test
    fun cardNamesAndNumbersMatchTheIosApp() {
        assertEquals("Ace of Clubs", Card(0).name)
        assertEquals("Queen of Hearts", card(12, Suit.Hearts).name)
        assertEquals(51, card(13, Suit.Spades).id)
        assertTrue(card(3, Suit.Diamonds).isRed)
    }

    @Test
    fun lowerStacksCountDownInAlternatingColors() {
        val t = table(lower = listOf(listOf(card(8, Suit.Spades)), emptyList(), emptyList(), emptyList()), deal = listOf(card(7, Suit.Hearts)))
        assertTrue(t.canMove(Spot.Deal, 0, Spot.lower(0)))
        val black = table(lower = listOf(listOf(card(8, Suit.Spades)), emptyList(), emptyList(), emptyList()), deal = listOf(card(7, Suit.Clubs)))
        assertFalse("same color", black.canMove(Spot.Deal, 0, Spot.lower(0)))
    }

    @Test
    fun kingGoesBelowAnAceAndAceAboveAKing() {
        val down = table(lower = listOf(listOf(card(1, Suit.Spades)), emptyList(), emptyList(), emptyList()), deal = listOf(card(13, Suit.Hearts)))
        assertTrue(down.canMove(Spot.Deal, 0, Spot.lower(0)))
        val up = table(upper = listOf(listOf(card(13, Suit.Hearts)), emptyList(), emptyList(), emptyList()), deal = listOf(card(1, Suit.Hearts)), starter = 13)
        assertTrue(up.canMove(Spot.Deal, 0, Spot.upper(0)))
    }

    @Test
    fun upperStacksStartWithTheStarterAndFollowSuit() {
        val t = table(deal = listOf(card(7, Suit.Clubs)), starter = 7)
        assertTrue(t.canMove(Spot.Deal, 0, Spot.upper(2)))
        val wrong = table(deal = listOf(card(8, Suit.Clubs)), starter = 7)
        assertFalse(wrong.canMove(Spot.Deal, 0, Spot.upper(2)))
        val offSuit = table(upper = listOf(listOf(card(7, Suit.Clubs)), emptyList(), emptyList(), emptyList()), deal = listOf(card(8, Suit.Spades)), starter = 7)
        assertFalse(offSuit.canMove(Spot.Deal, 0, Spot.upper(0)))
    }

    @Test
    fun emptyLowerStacksTakeTheBlindUntilItsGone() {
        val withBlind = table(blind = listOf(card(4, Suit.Hearts)), deal = listOf(card(6, Suit.Clubs)), starter = 7)
        assertTrue(withBlind.canMove(Spot.Blind, 0, Spot.lower(0)))
        assertFalse("only the blind fills a gap while it lasts", withBlind.canMove(Spot.Deal, 0, Spot.lower(0)))
        val noBlind = table(deal = listOf(card(6, Suit.Clubs)), starter = 7)
        assertTrue("one below the starter", noBlind.canMove(Spot.Deal, 0, Spot.lower(0)))
        val wrongRank = table(deal = listOf(card(5, Suit.Clubs)), starter = 7)
        assertFalse(wrongRank.canMove(Spot.Deal, 0, Spot.lower(0)))
    }

    @Test
    fun onlyTheBlindsAndDealsTopCardCanMove() {
        val t = table(lower = listOf(listOf(card(8, Suit.Spades)), emptyList(), emptyList(), emptyList()),
            blind = listOf(card(7, Suit.Hearts), card(2, Suit.Clubs)), deal = listOf(card(7, Suit.Diamonds), card(3, Suit.Clubs)))
        assertFalse(t.canMove(Spot.Blind, 0, Spot.lower(0)))
        assertFalse(t.canMove(Spot.Deal, 0, Spot.lower(0)))
    }

    @Test
    fun runsCantGoToUpperStacks() {
        val t = table(lower = listOf(listOf(card(2, Suit.Hearts), card(1, Suit.Spades)), emptyList(), emptyList(), emptyList()),
            upper = listOf(listOf(card(1, Suit.Hearts)), emptyList(), emptyList(), emptyList()))
        assertFalse(t.canMove(Spot.lower(0), 0, Spot.upper(0)))
    }

    @Test
    fun onlyRealRunsMoveBetweenLowerStacks() {
        val run = listOf(card(9, Suit.Hearts), card(8, Suit.Spades), card(7, Suit.Diamonds))
        val notRun = listOf(card(9, Suit.Hearts), card(4, Suit.Spades), card(7, Suit.Diamonds))
        val target = listOf(card(10, Suit.Clubs))
        assertTrue(table(lower = listOf(run, target, emptyList(), emptyList())).canMove(Spot.lower(0), 0, Spot.lower(1)))
        assertFalse(table(lower = listOf(notRun, target, emptyList(), emptyList())).canMove(Spot.lower(0), 0, Spot.lower(1)))
    }

    @Test
    fun movingARunKeepsItsCardsInOrder() {
        val run = listOf(card(9, Suit.Hearts), card(8, Suit.Spades), card(7, Suit.Diamonds))
        val t = table(lower = listOf(run, listOf(card(10, Suit.Clubs)), emptyList(), emptyList())).move(Spot.lower(0), 0, Spot.lower(1))
        assertEquals(listOf(card(10, Suit.Clubs)) + run, t.lower[1])
        assertTrue(t.lower[0].isEmpty())
    }

    @Test
    fun dealingTakesThreeAndTurnsTheDealBackOver() {
        val deck = listOf(card(1, Suit.Clubs), card(2, Suit.Clubs), card(3, Suit.Clubs), card(4, Suit.Clubs))
        var t = table(deck = deck, lower = listOf(Card.all.filter { it !in deck }, emptyList(), emptyList(), emptyList()))
        t = t.dealt()
        assertEquals("the deck's top card is dealt first", listOf(card(4, Suit.Clubs), card(3, Suit.Clubs), card(2, Suit.Clubs)), t.deal)
        t = t.dealt()
        assertEquals(card(1, Suit.Clubs), t.deal.last())
        t = t.dealt()
        assertEquals("turned over", deck, t.deck)
        assertTrue(t.deal.isEmpty())
    }

    @Test
    fun autoMovesPutUpLowerBlindAndDealCards() {
        val t = table(lower = deadLowerStacks(), blind = listOf(card(1, Suit.Clubs)))
        assertEquals(Move(Spot.Blind, 0, Spot.upper(0)), t.autoMove())
        assertNull(table(lower = deadLowerStacks()).autoMove())
    }

    // Lower stacks that take nothing showing, an empty deck, and a deal of cards that go nowhere.  Every card that could
    // be played (an Ace, a 4 or an 8) is buried in the blind, under a card that can't move.
    private fun stuckTable(deck: List<Card> = emptyList()): Table {
        val lower = deadLowerStacks()
        val playable = { c: Card -> c.rank == 1 || c.rank == 4 || c.rank == 8 }
        val rest = Card.all.filter { it !in lower.flatten() && it !in deck }
        val top = card(10, Suit.Hearts)
        val blind = rest.filter(playable) + top
        val deal = rest.filter { !playable(it) && it != top }
        return Table(blind, deck, deal, List(4) { emptyList() }, lower, starter = 1)
    }

    @Test
    fun stuckWhenNothingCanMove() {
        val t = stuckTable()
        assertTrue(t.isValid)
        assertEquals(PlayState.Stuck, t.playState())
    }

    @Test
    fun playableCardOnTheTable() {
        assertEquals(PlayState.CanPlay, table(lower = deadLowerStacks(), deal = listOf(card(4, Suit.Hearts))).playState())
    }

    @Test
    fun needsDealWhenTheDeckHasAPlayableCard() {
        // The 4 of Hearts, which goes on the 5 of Spades, waits in the deck
        val t = stuckTable(deck = listOf(card(4, Suit.Hearts)))
        assertTrue(t.isValid)
        assertNull(t.findMove())
        assertEquals(PlayState.NeedsDeal, t.playState())
    }

    @Test
    fun swappingARunBetweenMatchingCardsIsntAMove() {
        // The red 8 on one black 9 could go on the other black 9, which gets nowhere
        val lower = listOf(listOf(card(9, Suit.Clubs), card(8, Suit.Hearts)), listOf(card(9, Suit.Spades)), listOf(card(5, Suit.Spades)), listOf(card(5, Suit.Hearts)))
        val top = card(10, Suit.Hearts)
        val blind = Card.all.filter { it !in lower.flatten() && it != top } + top
        val t = Table(blind, emptyList(), emptyList(), List(4) { emptyList() }, lower, starter = 1)
        assertTrue(t.canMove(Spot.lower(0), 1, Spot.lower(1)))
        assertNull(t.findMove())
    }

    @Test
    fun theDeckIsWatchedAllTheWayThrough() {
        val deck = (1..7).map { card(it, Suit.Clubs) }
        val t = table(deck = deck, lower = listOf(Card.all.filter { it !in deck }, emptyList(), emptyList(), emptyList()))
        // Deals of three from the top (the end of the list), then the turn over, then around again
        assertEquals(listOf(card(5, Suit.Clubs), card(2, Suit.Clubs), card(1, Suit.Clubs)), t.cardsTheDeckWillDeal().take(3))
    }

    @Test
    fun wonWhenEveryUpperStackHasThirteen() {
        val upper = Suit.entries.map { s -> (1..13).map { card(it, s) } }
        assertTrue(Table(emptyList(), emptyList(), emptyList(), upper, List(4) { emptyList() }, 1).isWon)
    }
}
