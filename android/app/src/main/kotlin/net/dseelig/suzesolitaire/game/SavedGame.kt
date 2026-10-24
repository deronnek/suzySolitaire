package net.dseelig.suzesolitaire.game

import org.json.JSONArray
import org.json.JSONObject

// The saved game, in the same JSON as the iOS app's SavedGame.json: the record, the Auto Moves setting, and the table,
// with each stack listing its cards bottom to top by number (see Card).  A won game saves only the record, and the next
// launch deals a new game.
object SavedGame {

    data class Loaded(val game: Game?, val score: Int, val wins: Int, val losses: Int, val autoMoves: Boolean)

    fun encode(game: Game, autoMoves: Boolean): String {
        val json = JSONObject()
            .put("score", game.score)
            .put("wins", game.wins)
            .put("losses", game.losses)
            .put("autocomplete", autoMoves)
            .put("suitStackStarter", game.table.starter)
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
        Loaded(table?.let { Game(it, score, wins, losses) }, score, wins, losses, json.optBoolean("autocomplete"))
    }
    catch (_: Exception) {
        null
    }

    private fun ids(cards: List<Card>) = JSONArray(cards.map { it.id })

    private fun cards(array: JSONArray): List<Card> = (0 until array.length()).map { Card(array.getInt(it)) }

    private fun stacks(array: JSONArray): List<List<Card>> = (0 until array.length()).map { cards(array.getJSONArray(it)) }
}
