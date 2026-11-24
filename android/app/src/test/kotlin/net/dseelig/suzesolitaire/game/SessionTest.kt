package net.dseelig.suzesolitaire.game

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import net.dseelig.suzesolitaire.DebugAccess
import org.junit.Test
import kotlin.random.Random

class SessionTest {

    private fun session(table: Table = Table.deal(Card.all.shuffled(Random(12))), score: Int = -45, unlimited: Boolean = false, auto: Boolean = false) =
        Session(Game(table, score, wins = 0, losses = 0), autoMoves = auto, unlimitedUndo = unlimited)

    @Test
    fun putUpEarnsFiveDollars() {
        val s = session(table(lower = deadLowerStacks(), deal = listOf(card(1, Suit.Clubs))))
        assertTrue(s.putUp(Spot.Deal))
        assertEquals(-40, s.game.score)
        assertEquals(listOf(card(1, Suit.Clubs)), s.table.upper[0])
    }

    @Test
    fun cardsGoUpSoTheColorsAlternate() {
        val aces = listOf(Suit.Clubs, Suit.Spades, Suit.Diamonds, Suit.Hearts).map { card(1, it) }
        val s = session(table(lower = deadLowerStacks(), deal = aces))
        repeat(4) { assertTrue(s.putUp(Spot.Deal)) }
        assertEquals(listOf(Suit.Hearts, Suit.Spades, Suit.Diamonds, Suit.Clubs), s.table.upper.map { it.first().suit })

        // A red dragged up second leaves no way to alternate, so the next red goes where it clashes least
        val upper = listOf(emptyList(), listOf(card(1, Suit.Hearts)), emptyList(), emptyList())
        val t = session(table(lower = deadLowerStacks(), upper = upper, deal = listOf(card(1, Suit.Diamonds))))
        assertTrue(t.putUp(Spot.Deal))
        assertEquals(listOf(card(1, Suit.Diamonds)), t.table.upper[3])
    }

    @Test
    fun puttingACardUpFinishesACertainWinOneCardAtATime() {
        val s = session(DebugAccess.ALMOST_WON, auto = true)
        val from = Spot.lowers.first { spot -> s.table.top(spot)?.let { s.table.upperFor(it, Pile.Lower) } != null }
        assertTrue(s.putUp(from))
        assertTrue(s.finishing)
        val left = s.table.lower.sumOf { it.size }
        assertTrue("Auto Moves waits for the cards to go up one by one", left > 0)
        val score = s.game.score
        repeat(left) {
            assertTrue(s.finishStep())
            assertFalse(s.game.won)
        }
        assertFalse(s.finishStep())
        assertTrue(s.game.won)
        assertFalse(s.finishing)
        assertEquals(score + Game.CARD_UP * left + Game.WIN_BONUS, s.game.score)
    }

    @Test
    fun aWinThatIsntCertainWaitsForThePlayer() {
        val s = session(table(lower = deadLowerStacks(), deal = listOf(card(1, Suit.Clubs)), deck = listOf(card(2, Suit.Clubs))))
        assertTrue(s.putUp(Spot.Deal))
        assertFalse(s.finishing)
        assertFalse(s.finishStep())
    }

    @Test
    fun illegalMoveLeavesBoardAlone() {
        val s = session(table(lower = deadLowerStacks(), deal = listOf(card(2, Suit.Clubs))))
        val before = s.game
        assertFalse(s.move(Spot.Deal, 0, Spot.lower(0)))
        assertEquals(before, s.game)
        assertFalse("nothing to undo", s.canUndo)
    }

    @Test
    fun withoutUnlimitedUndoOnlyTheLastTurnCanBeUndone() {
        val s = session()
        val start = s.game
        s.deal()
        val afterOne = s.game
        s.deal()
        assertTrue(s.undo())
        assertEquals(afterOne, s.game)
        assertFalse("only one undo", s.canUndo)
        assertNotEquals(start, s.game)
    }

    @Test
    fun undoTakesBackTheMoneyForACardPutUp() {
        val s = session(table(lower = deadLowerStacks(), deal = listOf(card(1, Suit.Clubs))), score = 10)
        s.putUp(Spot.Deal)
        s.undo()
        assertEquals(10, s.game.score)
        assertEquals(listOf(card(1, Suit.Clubs)), s.table.deal)
    }

    @Test
    fun theFreeUndoCantTakeBackAutoMoves() {
        val s = session(table(lower = deadLowerStacks(), deal = listOf(card(4, Suit.Hearts)), blind = listOf(card(1, Suit.Clubs))), auto = true)
        assertTrue(s.move(Spot.Deal, 0, Spot.lower(0)))
        assertTrue(s.canUndo)
        // Auto moves go one at a time, after the turn
        assertTrue(s.autoMoveStep())
        assertFalse(s.autoMoveStep())
        assertEquals("the ace went up by itself", 1, s.table.upper.sumOf { it.size })
        assertFalse(s.canUndo)
    }

    @Test
    fun autoMovesPutUpOneCardAtATimeAndThenWin() {
        val s = session(DebugAccess.ALMOST_WON, auto = true)
        val cardsUp = mutableListOf<Int>()
        while (s.autoMoveStep()) {
            cardsUp += s.table.upper.flatten().size
        }
        assertTrue(s.game.won)
        // Each step puts up exactly one card
        assertEquals((37..52).toList(), cardsUp)
    }

    @Test
    fun unlimitedUndoStepsBackEveryTurn() {
        val s = session(unlimited = true)
        assertFalse("nothing to undo yet", s.canUndo)
        val games = mutableListOf(s.game)
        repeat(4) {
            s.deal()
            games += s.game
        }
        for (game in games.dropLast(1).reversed()) {
            assertTrue(s.canUndo)
            s.undo()
            assertEquals(game, s.game)
        }
        assertFalse("back to the start", s.canUndo)
    }

    @Test
    fun unlimitedUndoTakesBackAutoMovesWithTheTurn() {
        val s = session(table(lower = deadLowerStacks(), deal = listOf(card(4, Suit.Hearts)), blind = listOf(card(1, Suit.Clubs))),
            score = 10, unlimited = true, auto = true)
        val before = s.game
        s.move(Spot.Deal, 0, Spot.lower(0))
        while (s.autoMoveStep()) {}
        assertTrue("auto moves don't use up the undo", s.canUndo)
        s.undo()
        assertEquals("the moves still count", before.copy(moves = 2), s.game)
        assertEquals("the ace's money is taken back too", 10, s.game.score)
    }

    @Test
    fun newGameCostsALossAndCanBeUndone() {
        val s = session(score = 100)
        val before = s.game
        s.newGame(Random(1))
        assertEquals(1, s.game.losses)
        assertEquals(55, s.game.score)
        assertTrue(s.canUndo)
        s.undo()
        assertEquals(before, s.game)
    }

    @Test
    fun aMoveOrDealAfterNewGameIsWhatUndoUndoes() {
        val s = session()
        s.newGame(Random(1))
        val newGame = s.game
        s.deal()
        s.undo()
        assertEquals(newGame, s.game)
        assertFalse(s.canUndo)
    }

    @Test
    fun unlimitedUndoBringsBackTheLastGameOnlyRightAfterNewGame() {
        val s = session(unlimited = true)
        s.deal()
        val beforeNewGame = s.game
        s.newGame(Random(1))
        s.undo()
        assertEquals(beforeNewGame, s.game)
        assertEquals("the loss New Game cost is taken back", 0, s.game.losses)
        assertTrue("and the turns before it", s.canUndo)

        // Once the new game is under way, undo stops at its start
        s.newGame(Random(2))
        val newGame = s.game
        s.deal()
        s.undo()
        assertEquals(newGame, s.game)
        assertFalse(s.canUndo)
        assertEquals(1, s.game.losses)
    }

    @Test
    fun winningPaysAndEndsUndo() {
        // Everything is up but the King of Spades
        val upper = Suit.entries.map { suit -> (1..13).map { card(it, suit) }.filter { it != card(13, Suit.Spades) } }
        val t = Table(emptyList(), emptyList(), listOf(card(13, Suit.Spades)), upper, List(4) { emptyList() }, starter = 1)
        val s = Session(Game(t, score = 0, wins = 2, losses = 0), unlimitedUndo = true)
        assertTrue(s.putUp(Spot.Deal))
        assertTrue(s.game.won)
        assertEquals(5 + 250, s.game.score)
        assertEquals(3, s.game.wins)
        assertFalse(s.canUndo)
        s.newGame(Random(1))
        assertEquals("a won game isn't a loss", 0, s.game.losses)
        assertFalse("a won game can't be brought back", s.canUndo)
    }

    @Test
    fun noMovesAfterAWin() {
        val upper = Suit.entries.map { suit -> (1..13).map { card(it, suit) } }
        val s = Session(Game(Table(emptyList(), emptyList(), emptyList(), upper, List(4) { emptyList() }, 1), 0, 1, 0, won = true))
        assertFalse(s.deal())
    }

    @Test
    fun resetStatsClearsWinsAndLossesAndUndo() {
        val s = session(unlimited = true)
        s.deal()
        s.newGame(Random(1))
        s.resetStats()
        assertEquals(0, s.game.losses)
        assertEquals(GameStats(), s.game.stats)
        assertFalse("undoing would bring the old counts back", s.canUndo)
    }

    // MARK: Stats

    @Test
    fun aLostGameCountsItsMovesAndMoney() {
        val s = session(table(lower = deadLowerStacks(), deal = listOf(card(1, Suit.Clubs), card(1, Suit.Hearts)), deck = listOf(card(2, Suit.Clubs))))
        assertTrue(s.putUp(Spot.Deal))
        assertTrue(s.putUp(Spot.Deal))
        s.deal()
        assertEquals("deals don't count", 2, s.game.moves)
        s.newGame(Random(1))
        val stats = s.game.stats
        assertEquals(1, stats.games)
        assertEquals(1, stats.timedGames)
        assertEquals(2, stats.moves)
        assertEquals("the first card up started the upper stacks", 1, stats.cardsUp)
        assertEquals(-40, stats.worstGame)
        assertEquals(0, stats.streak)
        assertEquals(0, s.game.moves)
    }

    @Test
    fun aWinCountsItsStreakMovesAndTime() {
        var now = 0L
        val upper = Suit.entries.map { suit -> (1..13).map { card(it, suit) }.filter { it != card(13, Suit.Spades) } }
        val t = Table(emptyList(), emptyList(), listOf(card(13, Suit.Spades)), upper, List(4) { emptyList() }, starter = 1)
        val s = Session(Game(t, score = 0, wins = 0, losses = 0, moves = 15), now = { now })
        s.startClock()
        now = 90_000
        assertTrue(s.putUp(Spot.Deal))
        now = 200_000
        val stats = s.game.stats
        assertEquals(1, stats.streak)
        assertEquals(1, stats.timedWins)
        assertEquals(16, stats.winMoves)
        assertEquals(16, stats.fewestWinMoves)
        assertEquals(90.0, stats.fastestWin!!, 0.0)
        assertEquals("all 52 cards up, less the starter", 5 * 51 - 45 + 250, stats.bestGame)
        assertEquals("the clock stops at the win", 90.0, s.current.seconds, 0.0)
        s.newGame(Random(1))
        assertEquals("a won game isn't counted twice", 1, s.game.stats.games)
    }

    @Test
    fun undoingANewGameTakesItsLossBackOutOfTheStats() {
        var now = 0L
        val s = Session(Game(table(lower = deadLowerStacks(), deal = listOf(card(1, Suit.Clubs))), -45, 0, 0), now = { now })
        s.startClock()
        s.putUp(Spot.Deal)
        now = 30_000
        s.newGame(Random(1))
        assertEquals(1, s.game.stats.games)
        now = 50_000
        s.undo()
        assertEquals(GameStats(), s.game.stats)
        assertEquals(1, s.game.moves)
        assertEquals("the new game's time is let go", 30.0, s.current.seconds, 0.0)
    }

    @Test
    fun undoingAMoveKeepsItsCountAndTime() {
        var now = 0L
        val s = Session(Game(table(lower = deadLowerStacks(), deal = listOf(card(1, Suit.Clubs))), -45, 0, 0), now = { now })
        s.startClock()
        s.putUp(Spot.Deal)
        now = 10_000
        s.undo()
        assertEquals(1, s.game.moves)
        assertEquals(10.0, s.current.seconds, 0.0)
    }

    @Test
    fun theGameClockOnlyRunsWhileTheAppIsOpen() {
        var now = 0L
        val s = Session(Game(Table.deal(Card.all.shuffled(Random(3))), -45, 0, 0), now = { now })
        now = 5_000
        assertEquals("not until the app opens", 0.0, s.current.seconds, 0.0)
        s.startClock()
        now = 8_000
        s.pauseClock()
        now = 60_000
        s.startClock()
        now = 61_000
        assertEquals(4.0, s.current.seconds, 0.0)
        s.newGame(Random(1))
        now = 63_000
        assertEquals(4.0, s.game.stats.seconds, 0.0)
        assertEquals("the new game starts its own clock", 2.0, s.current.seconds, 0.0)
    }

    @Test
    fun gamesFromTheDebugMenuArentTimed() {
        val s = session()
        s.replaceTable(DebugAccess.ALMOST_WON)
        assertEquals(null, s.game.moves)
        s.newGame(Random(1))
        assertEquals(1, s.game.stats.games)
        assertEquals(0, s.game.stats.timedGames)
    }
}
