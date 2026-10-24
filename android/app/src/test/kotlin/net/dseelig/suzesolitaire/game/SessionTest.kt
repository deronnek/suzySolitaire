package net.dseelig.suzesolitaire.game

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
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
        assertEquals("the ace went up by itself", 1, s.table.upper.sumOf { it.size })
        assertFalse(s.canUndo)
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
        assertTrue("auto moves don't use up the undo", s.canUndo)
        s.undo()
        assertEquals(before, s.game)
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
        assertFalse("undoing would bring the old counts back", s.canUndo)
    }
}
