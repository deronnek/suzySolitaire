package net.dseelig.suzesolitaire.game

enum class Pile { Blind, Deck, Deal, Upper, Lower }

// A place cards can be: the blind, deck or deal, or one of the four upper or four lower stacks
data class Spot(val pile: Pile, val index: Int = 0) {
    val name: String
        get() = when (pile) {
            Pile.Blind -> "Blind"
            Pile.Deck -> "Deck"
            Pile.Deal -> "Deal"
            Pile.Upper -> "Upper stack ${index + 1}"
            Pile.Lower -> "Lower stack ${index + 1}"
        }

    companion object {
        val Blind = Spot(Pile.Blind)
        val Deck = Spot(Pile.Deck)
        val Deal = Spot(Pile.Deal)
        fun upper(i: Int) = Spot(Pile.Upper, i)
        fun lower(i: Int) = Spot(Pile.Lower, i)
        val uppers = (0 until 4).map(::upper)
        val lowers = (0 until 4).map(::lower)
        val all = listOf(Blind, Deck, Deal) + uppers + lowers
    }
}

// A card at a spot that can be moved somewhere useful, with the cards on top of it
data class Move(val from: Spot, val index: Int, val to: Spot)

enum class PlayState {
    // A card on the table can be played
    CanPlay,
    // Only a card from further into the deck can be played
    NeedsDeal,
    // Nothing can be played, even going through the whole deck
    Stuck,
}

// Where every card is.  Each list runs bottom to top, so the last card is the one showing on top.  starter is the rank
// of the card first dealt to the upper stacks, which every upper stack starts with.
data class Table(
    val blind: List<Card>,
    val deck: List<Card>,
    val deal: List<Card>,
    val upper: List<List<Card>>,
    val lower: List<List<Card>>,
    val starter: Int,
) {
    fun cards(spot: Spot): List<Card> = when (spot.pile) {
        Pile.Blind -> blind
        Pile.Deck -> deck
        Pile.Deal -> deal
        Pile.Upper -> upper[spot.index]
        Pile.Lower -> lower[spot.index]
    }

    fun top(spot: Spot): Card? = cards(spot).lastOrNull()

    fun spotOf(card: Card): Spot = Spot.all.first { card in cards(it) }

    fun with(spot: Spot, cards: List<Card>): Table = when (spot.pile) {
        Pile.Blind -> copy(blind = cards)
        Pile.Deck -> copy(deck = cards)
        Pile.Deal -> copy(deal = cards)
        Pile.Upper -> copy(upper = upper.toMutableList().also { it[spot.index] = cards })
        Pile.Lower -> copy(lower = lower.toMutableList().also { it[spot.index] = cards })
    }

    val isWon: Boolean get() = upper.all { it.size == 13 }

    // Every card exactly once, four of each kind of stack, and upper stacks that follow the rules
    val isValid: Boolean
        get() {
            val all = Spot.all.flatMap(::cards)
            return all.size == 52 && all.toSet().size == 52 && upper.size == 4 && lower.size == 4 && starter in 1..13 &&
                upper.all { stack -> stack.isEmpty() || stack.first().rank == starter && stack.zipWithNext().all { (a, b) -> b.suit == a.suit && b.rank == next(a.rank) } }
        }

    // MARK: Rules

    // Whether card, on top of a stack of kind from, may go on top of to
    fun accepts(card: Card, from: Pile, to: Spot): Boolean {
        if (from == Pile.Upper || from == Pile.Deck) {
            return false
        }
        val stack = cards(to)
        val onTop = stack.lastOrNull()
        return when (to.pile) {
            Pile.Upper ->
                if (onTop == null) card.rank == starter else card.suit == onTop.suit && card.rank == next(onTop.rank)
            Pile.Lower ->
                when {
                    // Until the blind is empty, only its cards fill an empty lower stack; after that, the card one below the
                    // starter
                    onTop == null -> from == Pile.Blind || blind.isEmpty() && card.rank == previous(starter)
                    else -> card.isRed != onTop.isRed && card.rank == previous(onTop.rank)
                }
            else -> false
        }
    }

    // Whether the cards in a lower stack from index up count down in alternating colors
    fun isRun(spot: Spot, index: Int): Boolean {
        val stack = cards(spot)
        if (index !in stack.indices) {
            return false
        }
        return stack.drop(index).zipWithNext().all { (below, above) -> above.isRed != below.isRed && above.rank == previous(below.rank) }
    }

    // Cards on top of the one picked up go with it.  Only the top card can leave the blind or deal, a single card at a
    // time goes to an upper stack, and runs only move between lower stacks.
    fun canMove(from: Spot, index: Int, to: Spot): Boolean {
        val stack = cards(from)
        if (index !in stack.indices || from == to) {
            return false
        }
        if (index != stack.lastIndex && (from.pile != Pile.Lower || to.pile != Pile.Lower || !isRun(from, index))) {
            return false
        }
        return accepts(stack[index], from.pile, to)
    }

    fun move(from: Spot, index: Int, to: Spot): Table {
        val moving = cards(from).drop(index)
        return with(from, cards(from).take(index)).let { it.with(to, it.cards(to) + moving) }
    }

    // Three more cards from the deck onto the deal, or the deal turned back over when the deck is empty
    fun dealt(): Table =
        if (deck.isEmpty()) {
            copy(deck = deal.reversed(), deal = emptyList())
        }
        else {
            val count = minOf(3, deck.size)
            copy(deck = deck.dropLast(count), deal = deal + deck.takeLast(count).reversed())
        }

    // The move Auto Moves makes next: for each upper stack in turn, a lower stack's, the blind's or the deal's top card
    fun autoMove(): Move? {
        for (to in Spot.uppers) {
            for (from in Spot.lowers + Spot.Blind + Spot.Deal) {
                val stack = cards(from)
                if (stack.isNotEmpty() && canMove(from, stack.lastIndex, to)) {
                    return Move(from, stack.lastIndex, to)
                }
            }
        }
        return null
    }

    // MARK: Looking for moves

    // A move of a visible card that gets somewhere.  Moving a run off a card it could equally sit on only swaps it between
    // two matching cards, so it doesn't count unless the card under it can then go up.
    fun findMove(): Move? {
        for (from in listOf(Spot.Blind, Spot.Deal)) {
            val top = top(from) ?: continue
            destinationFor(top, from.pile)?.let { return Move(from, cards(from).lastIndex, it) }
        }
        for (from in Spot.lowers) {
            val stack = cards(from)
            for (i in stack.indices) {
                if (!isRun(from, i)) {
                    continue
                }
                val below = stack.getOrNull(i - 1)
                val destinations = (if (i == stack.lastIndex) Spot.uppers else emptyList()) + Spot.lowers
                for (to in destinations) {
                    if (to == from || !canMove(from, i, to)) {
                        continue
                    }
                    if (to.pile == Pile.Upper) {
                        return Move(from, i, to)
                    }
                    if (below != null) {
                        // Uncovers a card that isn't part of the run, frees one to go up, or splits the run into an empty
                        // stack, leaving a new card to build on
                        val uncoversNewCard = !isRun(from, i - 1)
                        val belowCanGoUp = Spot.uppers.any { accepts(below, Pile.Lower, it) }
                        if (uncoversNewCard || belowCanGoUp || cards(to).isEmpty()) {
                            return Move(from, i, to)
                        }
                    }
                    else if (cards(to).isNotEmpty()) {
                        // Empties a lower stack
                        return Move(from, i, to)
                    }
                }
            }
        }
        return null
    }

    // An upper or lower stack that card, on top of a stack of kind from, could go to
    fun destinationFor(card: Card, from: Pile): Spot? = (Spot.uppers + Spot.lowers).firstOrNull { accepts(card, from, it) }

    // The cards that will be on top of the deal as the deck is dealt through, turning it over once, without playing any
    fun cardsTheDeckWillDeal(): List<Card> {
        var table = this
        val shown = mutableListOf<Card>()
        repeat(2 * (deck.size + deal.size) + 3) {
            table = table.dealt()
            table.deal.lastOrNull()?.let(shown::add)
            if (table.deck == deck && table.deal == deal) {
                return shown
            }
        }
        return shown
    }

    fun playState(): PlayState {
        if (findMove() != null) {
            return PlayState.CanPlay
        }
        val shown = deal.lastOrNull()
        return if (cardsTheDeckWillDeal().any { it != shown && destinationFor(it, Pile.Deal) != null }) PlayState.NeedsDeal else PlayState.Stuck
    }

    companion object {
        // The rank after rank, going up: a King is followed by an Ace
        fun next(rank: Int) = if (rank == 13) 1 else rank + 1
        fun previous(rank: Int) = if (rank == 1) 13 else rank - 1

        // Deals a shuffled deck as the iOS app does: 13 cards to the blind, one to the first upper stack (its rank starts
        // them all), 34 to the deck, and one to each lower stack
        fun deal(shuffled: List<Card>): Table {
            require(shuffled.size == 52 && shuffled.toSet().size == 52)
            val starter = shuffled[13]
            return Table(
                blind = shuffled.subList(0, 13).toList(),
                deck = shuffled.subList(14, 48).toList(),
                deal = emptyList(),
                upper = listOf(listOf(starter), emptyList(), emptyList(), emptyList()),
                lower = (0 until 4).map { listOf(shuffled[48 + it]) },
                starter = starter.rank,
            )
        }
    }
}
