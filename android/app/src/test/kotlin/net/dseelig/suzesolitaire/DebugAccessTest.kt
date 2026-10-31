package net.dseelig.suzesolitaire

import net.dseelig.suzesolitaire.game.Card
import net.dseelig.suzesolitaire.game.Game
import net.dseelig.suzesolitaire.game.Session
import net.dseelig.suzesolitaire.game.Spot
import net.dseelig.suzesolitaire.game.Table
import net.dseelig.suzesolitaire.ui.CardFaces
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

class DebugAccessTest {

    @Test
    fun anUnlockFitsOnlyItsPhone() {
        // Made by scripts/debug-unlock.sh ABCD1234, as in the iOS app's test
        val unlock = "MEQCIFaSCtB2u1mIEYzSOSQ-t87dpgtZa-FoM33DYDB1wB1rAiAXA0SlPH9qv_h1D7RXwc6dvrgH80eidlBvz07LT5lkzw"
        assertTrue(DebugAccess.isValid(unlock, "ABCD1234"))
        assertTrue("pasted with spaces or a line break", DebugAccess.isValid(" $unlock\n", "ABCD1234"))
        assertFalse(DebugAccess.isValid(unlock, "ABCD1235"))
        assertFalse(DebugAccess.isValid("not an unlock", "ABCD1234"))
        assertFalse(DebugAccess.isValid("", "ABCD1234"))
    }

    @Test
    fun aPhonesCodeIsEightLettersAndDigits() {
        val code = DebugAccess.deviceCode("0123456789abcdef")
        assertTrue(code, Regex("[0-9A-HJKMNP-TV-Z]{8}").matches(code))
        assertEquals(code, DebugAccess.deviceCode("0123456789abcdef"))
        assertNotEquals(code, DebugAccess.deviceCode("0123456789abcdee"))
        assertEquals("ABCD-1234", DebugAccess.pretty("ABCD1234"))
    }

    @Test
    fun almostWonIsOneMoveFromWinning() {
        val table = DebugAccess.ALMOST_WON
        assertTrue(table.isValid)
        assertFalse(table.isWon)
        val session = Session(Game(Table.deal(Card.all.shuffled(Random(3))), -45, wins = 2, losses = 1), autoMoves = true)
        session.replaceTable(table)
        assertEquals("no loss counted", 1, session.game.losses)
        assertTrue("Undo brings back the game it replaced", session.canUndo)
        // Putting the 2 of clubs up on its ace wins, with Auto Moves putting up the rest
        assertTrue(session.putUp(Spot.lower(0)))
        assertTrue(session.game.won)
        assertEquals(3, session.game.wins)
    }

    @Test
    fun winNowWins() {
        val session = Session(Game(Table.deal(Card.all.shuffled(Random(7))), -45, wins = 0, losses = 0))
        assertTrue(session.winNow())
        assertTrue(session.game.won)
        assertEquals(1, session.game.wins)
        assertEquals(-45 + Game.WIN_BONUS, session.game.score)
        assertTrue(session.table.upper.all { it.size == 13 })
        assertFalse("only once", session.winNow())
    }

    @Test
    fun everyCardHasEveryFace() {
        for (faces in CardFaces.entries) {
            assertEquals(faces.name, 52, faces.files.size)
            assertEquals(faces.name, 52, faces.files.toSet().size)
        }
        assertEquals(CardFaces.SmallRoboto, CardFaces.standard(roomy = false))
        assertEquals(CardFaces.LargeRoboto, CardFaces.standard(roomy = true))
    }
}
