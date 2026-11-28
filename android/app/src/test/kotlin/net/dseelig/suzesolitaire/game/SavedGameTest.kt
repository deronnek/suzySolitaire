package net.dseelig.suzesolitaire.game

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.json.JSONObject
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
    fun theStatsAndTheGamesMovesAndTimeAreSaved() {
        val stats = GameStats(games = 4, streak = 2, bestStreak = 3, cardsUp = 70, bestGame = 460, worstGame = -45, timedGames = 3,
                              timedWins = 2, moves = 210, winMoves = 150, seconds = 900.5, fewestWinMoves = 70, fastestWin = 240.25)
        val game = Game(Table.deal(Card.all.shuffled(Random(5))), score = 120, wins = 3, losses = 1, stats = stats, moves = 12, seconds = 61.5)
        val loaded = SavedGame.decode(SavedGame.encode(game, autoMoves = false))!!
        assertEquals(game, loaded.game)
        assertEquals(stats, loaded.stats)

        // Nothing yet in the stats that can be empty, as the iOS app leaves those out
        val fresh = SavedGame.encode(Game.first(Random(2)), autoMoves = false)
        assertFalse(fresh.contains("bestGame"))
        assertEquals(GameStats(), SavedGame.decode(fresh)!!.stats)
    }

    @Test
    fun aGameSavedBeforeStatsHasNoMovesCounted() {
        val game = Game(Table.deal(Card.all.shuffled(Random(5))), score = 0, wins = 2, losses = 1)
        val old = JSONObject(SavedGame.encode(game, false)).apply {
            remove("stats")
            remove("gameMoves")
            remove("gameSeconds")
        }
        val loaded = SavedGame.decode(old.toString())!!
        assertEquals(GameStats(), loaded.game!!.stats)
        assertNull(loaded.game!!.moves)
        assertEquals(2, loaded.wins)
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
