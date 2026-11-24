package net.dseelig.suzesolitaire.game

// Stats over every finished game: streaks, money, moves and time, shown on the Stats page alongside the wins and losses,
// as in the iOS app.  A game counts when it's won, or lost by dealing a new one.  Moves are card moves, including the
// cards Auto Moves puts up; deals and Undo don't count.  The clock only runs while the app is open.  They're kept with
// the game, so undoing a New Game takes its loss back out of them too.
data class GameStats(
    // Games won and lost since stats were first kept
    val games: Int = 0,
    val streak: Int = 0,
    val bestStreak: Int = 0,
    // Cards put up and the money won or lost, per game, counting the $45 a game costs and the $250 for winning
    val cardsUp: Int = 0,
    val bestGame: Int? = null,
    val worstGame: Int? = null,
    // Moves and time, over the games they were counted for: not the one being played when stats were added
    val timedGames: Int = 0,
    val timedWins: Int = 0,
    val moves: Int = 0,
    val winMoves: Int = 0,
    val seconds: Double = 0.0,
    val fewestWinMoves: Int? = null,
    val fastestWin: Double? = null,
) {
    // These stats with the game added, as won or lost
    fun recording(game: Game, won: Boolean): GameStats {
        val cards = game.table.cardsUp
        val money = money(cards, won)
        val streak = if (won) streak + 1 else 0
        val counted = copy(
            games = games + 1,
            streak = streak,
            bestStreak = maxOf(bestStreak, streak),
            cardsUp = cardsUp + cards,
            bestGame = maxOf(bestGame ?: money, money),
            worstGame = minOf(worstGame ?: money, money),
        )
        // A game that began before stats were kept
        val moves = game.moves ?: return counted
        val seconds = game.seconds
        val timed = counted.copy(timedGames = timedGames + 1, moves = this.moves + moves, seconds = this.seconds + seconds)
        return if (!won) timed else timed.copy(
            timedWins = timedWins + 1,
            winMoves = winMoves + moves,
            fewestWinMoves = minOf(fewestWinMoves ?: moves, moves),
            fastestWin = minOf(fastestWin ?: seconds, seconds),
        )
    }

    companion object {
        fun money(cardsUp: Int, won: Boolean) = Game.CARD_UP * cardsUp - Game.GAME_COST + if (won) Game.WIN_BONUS else 0
    }
}

// Cards put up this game, leaving out the one dealt to start the upper stacks
val Table.cardsUp: Int get() = maxOf(0, upper.sumOf { it.size } - 1)
