package net.dseelig.suzesolitaire

import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.click
import androidx.compose.ui.test.doubleClick
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipe
import androidx.compose.ui.geometry.Offset
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import net.dseelig.suzesolitaire.game.Card
import net.dseelig.suzesolitaire.game.Game
import net.dseelig.suzesolitaire.game.SavedGame
import net.dseelig.suzesolitaire.game.Suit
import net.dseelig.suzesolitaire.game.Table
import net.dseelig.suzesolitaire.store.FakeUpgradeStore
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class TableScreenTest {

    @get:Rule
    val compose = createEmptyComposeRule()

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private lateinit var store: FakeUpgradeStore
    private var scenario: ActivityScenario<MainActivity>? = null

    @Before
    fun setUp() {
        store = FakeUpgradeStore()
        GameViewModel.storeFactory = { _, _ -> store }
        File(context.filesDir, "SavedGame.json").delete()
        File(context.filesDir, "CardBack.png").delete()
        context.getSharedPreferences("settings", 0).edit().clear().commit()
    }

    @After
    fun tearDown() {
        scenario?.close()
    }

    private fun card(rank: Int, suit: Suit) = Card.of(rank, suit)

    // Starts the app on a table with the given cards, every other card in the blind (under a King that can't move)
    private fun launch(lower: List<List<Card>>, deal: List<Card>, deck: List<Card> = emptyList(), starter: Int = 1, autoMoves: Boolean = false) {
        val placed = (lower.flatten() + deal + deck).toSet()
        val blindTop = card(13, Suit.Clubs)
        val blind = Card.all.filter { it !in placed && it != blindTop } + blindTop
        val table = Table(blind, deck, deal, List(4) { emptyList() }, lower, starter)
        File(context.filesDir, "SavedGame.json").writeText(SavedGame.encode(Game(table, -45, 0, 0), autoMoves))
        start()
    }

    private fun start() {
        scenario = ActivityScenario.launch(MainActivity::class.java)
        // A freshly booted emulator can take a while to show the first frame
        compose.waitUntil(15_000) {
            runCatching { compose.onAllNodesWithContentDescription("New Game").fetchSemanticsNodes().isNotEmpty() }.getOrDefault(false)
        }
    }

    private fun stack(name: String) = compose.onNode(SemanticsMatcher.expectValue(SemanticsProperties.ContentDescription, listOf(name)))

    private fun stateOf(name: String) = stack(name).fetchSemanticsNode().config.getOrNull(SemanticsProperties.StateDescription).orEmpty()

    private fun centerOf(name: String) = stack(name).fetchSemanticsNode().boundsInRoot.center

    @Test
    fun tappingTheDeckDeals() {
        launch(lower = listOf(listOf(card(5, Suit.Spades)), emptyList(), emptyList(), emptyList()), deal = emptyList(),
            deck = listOf(card(2, Suit.Hearts), card(3, Suit.Hearts), card(4, Suit.Hearts), card(6, Suit.Hearts)))
        // The deck deals from its top: the 6, 4 and 3, leaving the 3 showing
        stack("Deck").performTouchInput { click() }
        compose.waitForIdle()
        assertTrue(stateOf("Deal"), stateOf("Deal").startsWith("3 of Hearts on top, 3 cards"))
    }

    @Test
    fun draggingACardMovesIt() {
        launch(lower = listOf(listOf(card(8, Suit.Spades)), emptyList(), emptyList(), emptyList()), deal = listOf(card(7, Suit.Hearts)))
        val from = centerOf("Deal")
        val to = centerOf("Lower stack 1")
        compose.onRoot().performTouchInput { swipe(from, Offset(to.x, to.y + 40f), durationMillis = 400) }
        compose.waitForIdle()
        assertEquals("8 of Spades, 7 of Hearts", stateOf("Lower stack 1"))
        compose.onNodeWithContentDescription("Undo").assertIsEnabled()
    }

    @Test
    fun anIllegalDropPutsTheCardBack() {
        launch(lower = listOf(listOf(card(8, Suit.Hearts)), emptyList(), emptyList(), emptyList()), deal = listOf(card(7, Suit.Hearts)))
        compose.onRoot().performTouchInput { swipe(centerOf("Deal"), centerOf("Lower stack 1"), durationMillis = 400) }
        compose.waitForIdle()
        assertEquals("8 of Hearts", stateOf("Lower stack 1"))
        assertTrue(stateOf("Deal").startsWith("7 of Hearts on top"))
    }

    @Test
    fun doubleTapPutsUpACard() {
        launch(lower = listOf(listOf(card(5, Suit.Spades)), emptyList(), emptyList(), emptyList()), deal = listOf(card(1, Suit.Clubs)))
        compose.onRoot().performTouchInput { doubleClick(centerOf("Deal")) }
        compose.waitForIdle()
        assertTrue(stateOf("Upper stack 1"), stateOf("Upper stack 1").startsWith("Ace of Clubs on top"))
        compose.onNodeWithContentDescription("$-40, Wins: 0, Losses: 0").assertExists()
    }

    @Test
    fun talkBackSelectsThenMoves() {
        launch(lower = listOf(listOf(card(8, Suit.Spades)), emptyList(), emptyList(), emptyList()), deal = listOf(card(7, Suit.Hearts)))
        stack("Deal").performSemanticsAction(SemanticsActions.OnClick)
        assertTrue(stateOf("Deal").startsWith("Selected 7 of Hearts"))
        stack("Lower stack 1").performSemanticsAction(SemanticsActions.OnClick)
        assertEquals("8 of Spades, 7 of Hearts", stateOf("Lower stack 1"))
    }

    @Test
    fun theFreeUndoTakesBackOnlyTheLastTurn() {
        start()
        stack("Deck").performSemanticsAction(SemanticsActions.OnClick)
        stack("Deck").performSemanticsAction(SemanticsActions.OnClick)
        compose.onNodeWithContentDescription("Undo").performClick()
        compose.onNodeWithContentDescription("Undo").assertIsNotEnabled()
    }

    @Test
    fun buyingUnlimitedUndoLetsUndoGoBackEveryTurn() {
        start()
        compose.onNodeWithContentDescription("More").performClick()
        compose.onNodeWithText("Unlimited Undo · $5.00").performClick()
        compose.onNodeWithText("Undo now takes back as many moves as you like, even auto moves and New Game.").assertExists()
        compose.onNodeWithText("OK").performClick()
        repeat(3) { stack("Deck").performSemanticsAction(SemanticsActions.OnClick) }
        repeat(3) {
            compose.onNodeWithContentDescription("Undo").assertIsEnabled().performClick()
        }
        compose.onNodeWithContentDescription("Undo").assertIsNotEnabled()

        compose.onNodeWithContentDescription("More").performClick()
        compose.onNodeWithText("Purchased. Thank you!").assertExists()
    }

    @Test
    fun aRefundTurnsUnlimitedUndoOff() {
        store = FakeUpgradeStore(owned = true)
        start()
        repeat(2) { stack("Deck").performSemanticsAction(SemanticsActions.OnClick) }
        store.refund()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Undo").performClick()
        compose.onNodeWithContentDescription("Undo").assertIsNotEnabled()
    }

    @Test
    fun menuTogglesShowTheirState() {
        start()
        val off = SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "Off")
        val on = SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "On")
        compose.onNodeWithContentDescription("More").performClick()
        compose.onNodeWithText("Auto Moves").assert(off)
        compose.onNodeWithText("Show When Stuck").assert(off)
        compose.onNodeWithText("Auto Moves").performClick()
        compose.onNodeWithContentDescription("More").performClick()
        compose.onNodeWithText("Auto Moves").assert(on)
    }

    @Test
    fun howToPlayOpensFromTheMenuAndGoesBack() {
        start()
        compose.onNodeWithContentDescription("More").performClick()
        compose.onNodeWithText("How to Play").performClick()
        compose.onNodeWithContentDescription("1. Cards must alternate colors in the lower four stacks and count down.").assertExists()
        compose.onNodeWithContentDescription("Back").performClick()
        compose.onNodeWithContentDescription("New Game").assertExists()
    }

    @Test
    fun theCardsMenuPicksTheArtwork() {
        start()
        compose.onNodeWithContentDescription("More").performClick()
        compose.onNodeWithText("Cards").performClick()
        compose.onNodeWithText("Back").assertExists()
        compose.onNodeWithText("Artwork").performClick()
        compose.onNode(SemanticsMatcher.expectValue(SemanticsProperties.Selected, true)).assert(hasText("Automatic"))
        compose.onNodeWithText("Classic, Abril Fatface").performClick()
        compose.waitForIdle()
        assertEquals("LargeAbril", context.getSharedPreferences("settings", 0).getString(GameViewModel.CARD_FACES_KEY, null))
        compose.onNode(SemanticsMatcher.expectValue(SemanticsProperties.Selected, true)).assert(hasText("Classic, Abril Fatface"))
    }

    @Test
    fun newGameCanBeUndone() {
        start()
        val before = stateOf("Blind")
        compose.onNodeWithContentDescription("New Game").performClick()
        compose.onNodeWithContentDescription("$-90, Wins: 0, Losses: 1").assertExists()
        compose.onNodeWithContentDescription("Undo").performClick()
        assertEquals(before, stateOf("Blind"))
        compose.onNodeWithContentDescription("$-45, Wins: 0, Losses: 0").assertExists()
    }

    @Test
    fun theGameIsSavedAfterEveryTurn() {
        start()
        stack("Deck").performSemanticsAction(SemanticsActions.OnClick)
        compose.waitForIdle()
        Thread.sleep(500)
        val saved = SavedGame.decode(File(context.filesDir, "SavedGame.json").readText())!!.game!!
        assertEquals(3, saved.table.deal.size)
    }

    private fun androidx.compose.ui.test.junit4.ComposeTestRule.onRoot() = onNode(SemanticsMatcher("root") { it.parent == null })
}
