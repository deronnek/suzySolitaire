package net.dseelig.suzesolitaire.game

import org.json.JSONArray
import org.json.JSONObject

// The saved game, in the same JSON as the iOS app's SavedGame.json: the record and stats, the Auto Moves setting, and the
// table, with each stack listing its cards bottom to top by number (see Card).  A won game saves only the record and
// stats, and the next launch deals a new game.  Games saved before stats were kept have none, nor moves or time.
object SavedGame {

    data class Loaded(val game: Game?, val score: Int, val wins: Int, val losses: Int, val autoMoves: Boolean,
                      val stats: GameStats = GameStats())

    fun encode(game: Game, autoMoves: Boolean): String {
        val json = JSONObject()
            .put("score", game.score)
            .put("wins", game.wins)
            .put("losses", game.losses)
            .put("autocomplete", autoMoves)
            .put("suitStackStarter", game.table.starter)
            .put("stats", encode(game.stats))
            .put("gameMoves", game.moves)
            .put("gameSeconds", game.seconds)
        if (!game.won) {
            val table = game.table
            json.put("board", JSONObject()
                .put("fub", ids(table.blind))
                .put("deck", ids(table.deck))
                .put("deal", ids(table.deal))
                .put("suitStacks", JSONArray(table.upper.map(::ids)))
                .put("cardStacks", JSONArray(table.lower.map(::ids))))
        }
        return json.toString()
    }

    // Returns null if the text isn't a saved game at all.  A saved game whose table is missing (it was won) or isn't a
    // valid deal comes back with a null game, so the caller deals a new one but keeps the record.
    fun decode(text: String): Loaded? = try {
        val json = JSONObject(text)
        val score = json.getInt("score")
        val wins = json.getInt("wins")
        val losses = json.getInt("losses")
        val board = json.optJSONObject("board")
        val table = board?.let {
            Table(
                blind = cards(it.getJSONArray("fub")),
                deck = cards(it.getJSONArray("deck")),
                deal = cards(it.getJSONArray("deal")),
                upper = stacks(it.getJSONArray("suitStacks")),
                lower = stacks(it.getJSONArray("cardStacks")),
                starter = json.getInt("suitStackStarter"),
            )
        }?.takeIf { it.isValid }
        val stats = json.optJSONObject("stats")?.let(::decodeStats) ?: GameStats()
        val moves = if (json.has("gameMoves")) json.getInt("gameMoves") else null
        val seconds = json.optDouble("gameSeconds", 0.0)
        Loaded(table?.let { Game(it, score, wins, losses, stats = stats, moves = moves, seconds = seconds) }, score, wins, losses,
               json.optBoolean("autocomplete"), stats)
    }
    catch (_: Exception) {
        null
    }

    // Every field the iOS app's GameStats needs, leaving out the ones with nothing in them yet as it does
    private fun encode(stats: GameStats) = JSONObject()
        .put("games", stats.games)
        .put("streak", stats.streak)
        .put("bestStreak", stats.bestStreak)
        .put("cardsUp", stats.cardsUp)
        .put("bestGame", stats.bestGame)
        .put("worstGame", stats.worstGame)
        .put("timedGames", stats.timedGames)
        .put("timedWins", stats.timedWins)
        .put("moves", stats.moves)
        .put("winMoves", stats.winMoves)
        .put("seconds", stats.seconds)
        .put("fewestWinMoves", stats.fewestWinMoves)
        .put("fastestWin", stats.fastestWin)

    private fun decodeStats(json: JSONObject) = GameStats(
        games = json.getInt("games"),
        streak = json.getInt("streak"),
        bestStreak = json.getInt("bestStreak"),
        cardsUp = json.getInt("cardsUp"),
        bestGame = json.optInt("bestGame").takeIf { json.has("bestGame") },
        worstGame = json.optInt("worstGame").takeIf { json.has("worstGame") },
        timedGames = json.getInt("timedGames"),
        timedWins = json.getInt("timedWins"),
        moves = json.getInt("moves"),
        winMoves = json.getInt("winMoves"),
        seconds = json.getDouble("seconds"),
        fewestWinMoves = json.optInt("fewestWinMoves").takeIf { json.has("fewestWinMoves") },
        fastestWin = json.optDouble("fastestWin").takeIf { json.has("fastestWin") },
    )

    private fun ids(cards: List<Card>) = JSONArray(cards.map { it.id })

    private fun cards(array: JSONArray): List<Card> = (0 until array.length()).map { Card(array.getInt(it)) }

    private fun stacks(array: JSONArray): List<List<Card>> = (0 until array.length()).map { cards(array.getJSONArray(it)) }
}
