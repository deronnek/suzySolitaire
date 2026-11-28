package net.dseelig.suzesolitaire.game

import kotlin.random.Random

// A game and the player's record: money, wins and losses, and the other stats.  Every new game costs $45, each card put
// up earns $5, and a win earns $250.  moves counts this game's card moves, or is null for a game begun before stats were
// kept, and seconds is how long it had been played with the app open when this was taken (see Session.current).
data class Game(
    val table: Table,
    val score: Int,
    val wins: Int,
    val losses: Int,
    val won: Boolean = false,
    val stats: GameStats = GameStats(),
    val moves: Int? = 0,
    val seconds: Double = 0.0,
) {
    companion object {
        const val GAME_COST = 45
        const val CARD_UP = 5
        const val WIN_BONUS = 250

        fun first(random: Random = Random.Default) =
            Game(Table.deal(Card.all.shuffled(random)), score = -GAME_COST, wins = 0, losses = 0)
    }
}

// The game being played, and how it got there, for undo.
//
// Every turn (a move or deal the player makes, plus the auto moves that follow it) records the game as it was before.
// Without Unlimited Undo, Undo takes back only the last turn, and not one with auto moves in it.  With it, Undo steps back
// a turn at a time to the start of the game.  Either way, right after New Game it brings back the game New Game replaced,
// but only until the first move or deal in the new one, and a won game can't be brought back.
//
// The game's clock runs while the app is open (see startClock) until the game is won.  Undoing a move doesn't take back
// its time, or the move from the game's count.
class Session(game: Game, var autoMoves: Boolean = false, var unlimitedUndo: Boolean = false,
              private val now: () -> Long = System::currentTimeMillis) {
    var game: Game = game
        private set
    private val history = ArrayDeque<Game>()
    // Whether the free undo can take back the last turn
    private var lastTurnUndoable = false
    // Since New Game, before the first turn of the new game
    private var justDealtNewGame = false
    // Whether the rest of the cards are to go up by themselves, one finishStep at a time: the player put one up and
    // every card left is on the lower stacks, in an order that lets them all go up
    var finishing = false
        private set
    // Whether the app is open, and when the clock last started on this game, or null while it's stopped
    private var clockRunning = false
    private var clockStart: Long? = null

    val table: Table get() = game.table

    val canUndo: Boolean
        get() = history.isNotEmpty() && (unlimitedUndo || lastTurnUndoable)

    // How many turns Undo could take back with Unlimited Undo
    val turnsRecorded: Int get() = history.size

    // The game with the time on its clock up to now, for saving
    val current: Game get() = game.copy(seconds = elapsed)

    private val elapsed: Double get() = game.seconds + (clockStart?.let { (now() - it) / 1000.0 } ?: 0.0)

    // MARK: Clock

    // The app opened
    fun startClock() {
        clockRunning = true
        if (clockStart == null) {
            restartClock()
        }
    }

    // The app went into the background
    fun pauseClock() {
        clockRunning = false
        stopClock()
    }

    private fun stopClock() {
        game = current
        clockStart = null
    }

    // Starts the clock afresh on the game now on the table, if the app is open and it isn't won
    private fun restartClock() {
        clockStart = if (clockRunning && !game.won) now() else null
    }

    // MARK: Turns

    // Moves the card at index in from, with any cards on top of it, to to.  Returns false, changing nothing, if the
    // rules don't allow it.
    fun move(from: Spot, index: Int, to: Spot): Boolean {
        if (game.won || !table.canMove(from, index, to)) {
            return false
        }
        recordTurn()
        apply(Move(from, index, to))
        finishing = to.pile == Pile.Upper && table.winIsCertain
        finishTurn()
        return true
    }

    // Puts up the next card of a game finishing itself, as part of the turn that started it.  Returns false once they're
    // all up, and the game is won.
    fun finishStep(): Boolean {
        if (!finishing) {
            return false
        }
        val move = table.finishingMove()
        if (move == null) {
            finishing = false
            finishTurn()
            return false
        }
        apply(move)
        return true
    }

    // Makes the next auto move, if Auto Moves is on and a card can go up, as part of the last turn.  Returns false once
    // there's none to make, checking then for a win.
    fun autoMoveStep(): Boolean {
        val move = if (autoMoves && !finishing && !game.won) table.autoMove() else null
        if (move == null) {
            finishTurn()
            return false
        }
        apply(move)
        // The free undo can't take back a turn with auto moves in it
        lastTurnUndoable = false
        return true
    }

    // Sends the top card of from to whichever upper stack will take it, as a double tap does
    fun putUp(from: Spot): Boolean {
        val stack = table.cards(from)
        val to = stack.lastOrNull()?.let { table.upperFor(it, from.pile) } ?: return false
        return move(from, stack.lastIndex, to)
    }

    // Deals three cards from the deck, or turns the deal back over when the deck is empty
    fun deal(): Boolean {
        if (game.won || table.deck.isEmpty() && table.deal.isEmpty()) {
            return false
        }
        recordTurn()
        game = game.copy(table = table.dealt())
        finishTurn()
        return true
    }

    // Deals a new game, one of winnable if it's given.  Giving up on one that isn't won counts as a loss.
    fun newGame(random: Random = Random.Default, winnable: WinnableDeals? = null) {
        stopClock()
        val previous = game
        game = Game(
            Table.deal(winnable?.shuffled(random) ?: Card.all.shuffled(random)),
            score = previous.score - Game.GAME_COST,
            wins = previous.wins,
            losses = previous.losses + if (previous.won) 0 else 1,
            stats = if (previous.won) previous.stats else previous.stats.recording(previous, won = false),
        )
        restartClock()
        // Undoing New Game brings back the game it replaced along with its turns, until the new game is under way (see
        // recordTurn).  A won game's turns were already let go.
        if (!previous.won) {
            history.addLast(previous)
        }
        lastTurnUndoable = !previous.won
        justDealtNewGame = !previous.won
    }

    // Swaps the game for one on the given table, without counting a loss or its moves and time, for the Debug menu.  As
    // after New Game, Undo brings back the game it replaced.
    fun replaceTable(table: Table) {
        stopClock()
        val previous = game
        game = previous.copy(table = table, won = false, moves = null)
        restartClock()
        if (!previous.won) {
            history.addLast(previous)
        }
        lastTurnUndoable = !previous.won
        justDealtNewGame = !previous.won
    }

    // Puts every card up on its suit's upper stack, from the starter rank round, and wins, for the Debug menu
    fun winNow(): Boolean {
        if (game.won) {
            return false
        }
        recordTurn()
        val started = table.upper.mapNotNull { it.firstOrNull()?.suit }
        val suits = started + Suit.entries.filter { it !in started }
        val upper = suits.map { suit ->
            Card.all.filter { it.suit == suit }.sortedBy { (it.rank - table.starter + 13) % 13 }
        }
        game = game.copy(table = table.copy(blind = emptyList(), deck = emptyList(), deal = emptyList(), upper = upper,
                                            lower = List(4) { emptyList() }), moves = null)
        finishTurn()
        return true
    }

    fun undo(): Boolean {
        if (!canUndo) {
            return false
        }
        val previous = history.removeLast()
        // Undoing New Game brings back the game it replaced, moves and time and all; within a game, they carry on
        if (justDealtNewGame) {
            game = previous
            restartClock()
        }
        else {
            game = previous.copy(moves = game.moves, seconds = game.seconds)
        }
        // The free undo is used up
        lastTurnUndoable = false
        justDealtNewGame = false
        return true
    }

    fun resetStats() {
        game = game.copy(wins = 0, losses = 0, stats = GameStats())
        // Undo would otherwise bring the old counts back
        history.clear()
        lastTurnUndoable = false
        justDealtNewGame = false
    }

    // Puts a saved game on the table, with nothing to undo
    fun restore(saved: Game) {
        game = saved
        restartClock()
        history.clear()
        lastTurnUndoable = false
        justDealtNewGame = false
    }

    private fun recordTurn() {
        // The first turn of a new game: the one before it can't be brought back any more
        if (justDealtNewGame) {
            history.clear()
            justDealtNewGame = false
        }
        history.addLast(game)
        lastTurnUndoable = true
    }

    private fun apply(move: Move) {
        val earned = if (move.to.pile == Pile.Upper) Game.CARD_UP else 0
        game = game.copy(table = table.move(move.from, move.index, move.to), score = game.score + earned, moves = game.moves?.plus(1))
    }

    private fun finishTurn() {
        if (table.isWon && !game.won) {
            stopClock()
            game = game.copy(won = true, score = game.score + Game.WIN_BONUS, wins = game.wins + 1,
                             stats = game.stats.recording(game, won = true))
            // A won game is over, so there's nothing to go back to
            history.clear()
            lastTurnUndoable = false
        }
    }
}
