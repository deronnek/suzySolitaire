package net.dseelig.suzesolitaire.game

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import kotlin.random.Random

class SavedGameTest {

    @Test
    fun saveAndRestoreRoundTrip() {
        var table = Table.deal(Card.all.shuffled(Random(5)))
        table = table.dealt().dealt()
        val game = Game(table, score = 120, wins = 3, losses = 2)
        val loaded = SavedGame.decode(SavedGame.encode(game, autoMoves = true))!!
        assertEquals(game, loaded.game)
        assertTrue(loaded.autoMoves)
    }

    @Test
    fun wonGameSavesStatsButNotBoard() {
        val game = Game(Table.deal(Card.all.shuffled(Random(5))), score = 300, wins = 4, losses = 1, won = true)
        val loaded = SavedGame.decode(SavedGame.encode(game, autoMoves = false))!!
        assertNull(loaded.game)
        assertEquals(300, loaded.score)
        assertEquals(4, loaded.wins)
    }

    @Test
    fun restoreRejectsInvalidBoard() {
        val game = Game(Table.deal(Card.all.shuffled(Random(5))), score = 0, wins = 0, losses = 0)
        val broken = SavedGame.encode(game, false).replace("\"deck\":[", "\"deck\":[0,")
        val loaded = SavedGame.decode(broken)
        assertNotNull("the record survives", loaded)
        assertNull("but the table is dealt again", loaded!!.game)
        assertNull("and text that isn't a saved game is ignored", SavedGame.decode("not json"))
    }

    @Test
    fun readsTheIosScreenshotGame() {
        // The game in progress the App Store screenshots show, saved by the iOS app's format
        val file = generateSequence(File("").absoluteFile) { it.parentFile }
            .map { File(it, "AppStore/Screenshots/game-in-progress.json") }.first { it.exists() }
        val loaded = SavedGame.decode(file.readText())!!
        val game = loaded.game!!
        assertEquals(125, game.score)
        assertEquals(12, game.wins)
        assertEquals(7, game.table.starter)
        assertEquals(listOf(card(7, Suit.Hearts), card(8, Suit.Hearts), card(9, Suit.Hearts)), game.table.upper[0])
    }
}
