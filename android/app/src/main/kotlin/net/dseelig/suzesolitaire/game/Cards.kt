package net.dseelig.suzesolitaire.game

enum class Suit {
    Clubs, Diamonds, Hearts, Spades;

    val isRed: Boolean get() = this == Diamonds || this == Hearts
}

// One of the 52 cards, numbered as the iOS app numbers them (Clubs, Diamonds, Hearts, then Spades, Ace to King), so a
// saved game means the same thing on both
@JvmInline
value class Card(val id: Int) {
    init {
        require(id in 0 until 52) { "No card $id" }
    }

    val suit: Suit get() = Suit.entries[id / 13]
    // Ace is 1, King is 13
    val rank: Int get() = id % 13 + 1
    val isRed: Boolean get() = suit.isRed

    // e.g. "Queen of Hearts"
    val name: String
        get() {
            val rankName = when (rank) {
                1 -> "Ace"
                11 -> "Jack"
                12 -> "Queen"
                13 -> "King"
                else -> rank.toString()
            }
            return "$rankName of ${suit.name}"
        }

    override fun toString() = name

    companion object {
        val all: List<Card> = (0 until 52).map(::Card)

        fun of(rank: Int, suit: Suit) = Card(suit.ordinal * 13 + rank - 1)
    }
}
