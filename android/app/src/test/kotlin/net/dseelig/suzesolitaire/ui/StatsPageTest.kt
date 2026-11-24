package net.dseelig.suzesolitaire.ui

import net.dseelig.suzesolitaire.game.GameStats
import org.junit.Assert.assertEquals
import org.junit.Test

class StatsPageTest {

    @Test
    fun timesShowMinutesAndSecondsOrHours() {
        assertEquals("0:00", StatsPage.duration(0.0))
        assertEquals("3:20", StatsPage.duration(199.6))
        assertEquals("1:02:05", StatsPage.duration(3725.0))
    }

    @Test
    fun rowsWithNothingToShowYetShowADash() {
        val rows = StatsPage.sections(GameStats(), wins = 0, losses = 0, score = -45).flatMap { it.rows }.toMap()
        assertEquals("—", rows["Win Rate"])
        assertEquals("—", rows["Best Game"])
        assertEquals("$-45", rows["Total"])
    }

    @Test
    fun averagesAreOverTheGamesTheyCount() {
        val stats = GameStats(games = 4, cardsUp = 30, timedGames = 2, timedWins = 1, moves = 150, winMoves = 90, seconds = 500.0)
        val sections = StatsPage.sections(stats, wins = 3, losses = 1, score = 300)
        val moves = sections.first { it.title == "Moves" }.rows.toMap()
        assertEquals("75", moves["Average per Game"])
        assertEquals("90", moves["Average per Win"])
        assertEquals("4:10", sections.first { it.title == "Time" }.rows.toMap()["Average per Game"])
        assertEquals("75%", sections.first { it.title == "Results" }.rows.toMap()["Win Rate"])
        assertEquals("7.5", sections.first { it.title == "Money" }.rows.toMap()["Cards Up per Game"])
    }
}
