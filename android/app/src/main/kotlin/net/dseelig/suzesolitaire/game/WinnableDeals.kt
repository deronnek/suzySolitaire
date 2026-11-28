package net.dseelig.suzesolitaire.game

import kotlin.random.Random

// How New Game deals: any shuffle, or one of a list of deals that can be won
enum class Dealing(val title: String, val detail: String) {
    Random("Totally Random", "Any shuffle of the cards"),
    Theory("Winnable in Theory", "Could be won by someone who saw every card"),
    Cunning("Winnable with Cunning", "Won by a player who never peeked"),
}

// Deals that can be won, for Dealing other than Random: the ones scripts/winnable-deals.py won, knowing every card for
// Theory, or playing as a player could, without peeking at covered cards or taking moves back, for Cunning.  One per
// line as 52 letters, each a card id (A-Z then a-z) in the order Table.deal takes them.  Each is dealt with its ranks
// turned round by a random amount and its suits swapped about at random, keeping each card's color matched with the
// others.  Neither changes which moves can be made, as the upper stacks start from whatever rank is dealt and a King
// sits below an Ace, so each line gives 104 different-looking games that can all be won.
class WinnableDeals(private val lines: List<String>) {
    val count: Int get() = lines.size

    fun shuffled(random: Random): List<Card> = variant(lines.random(random), random.nextInt(13), random.nextInt(8))

    companion object {
        const val LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

        fun parse(text: String) = WinnableDeals(text.lines().filter { it.isNotBlank() })

        fun decode(line: String): List<Card> = line.map { Card(LETTERS.indexOf(it)) }

        // The deal on line with every rank shift higher (round from King to Ace) and its suits swapped as swap says: bit
        // 0 swaps Clubs and Spades, bit 1 Diamonds and Hearts, and bit 2 the black suits for the red
        fun variant(line: String, shift: Int, swap: Int): List<Card> = decode(line).map { relabel(it, shift, swap) }

        fun relabel(card: Card, shift: Int, swap: Int): Card {
            val bySuit = listOf(listOf(Suit.Clubs, Suit.Spades), listOf(Suit.Diamonds, Suit.Hearts))
            val color = if (card.isRed) 1 else 0
            val place = bySuit[color].indexOf(card.suit) xor (swap shr color and 1)
            val suit = bySuit[color xor (swap shr 2 and 1)][place]
            return Card.of((card.rank - 1 + shift) % 13 + 1, suit)
        }
    }
}
