package net.dseelig.suzesolitaire

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ImageDecoder
import android.graphics.Paint
import android.graphics.RectF
import android.net.Uri
import android.provider.Settings
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import net.dseelig.suzesolitaire.game.Card
import net.dseelig.suzesolitaire.game.Game
import net.dseelig.suzesolitaire.game.Pile
import net.dseelig.suzesolitaire.game.PlayState
import net.dseelig.suzesolitaire.game.SavedGame
import net.dseelig.suzesolitaire.game.Session
import net.dseelig.suzesolitaire.game.Spot
import net.dseelig.suzesolitaire.game.Table
import net.dseelig.suzesolitaire.store.PlayUpgradeStore
import net.dseelig.suzesolitaire.store.PurchaseOutcome
import net.dseelig.suzesolitaire.store.UpgradeStore
import net.dseelig.suzesolitaire.ui.CardFaces
import net.dseelig.suzesolitaire.ui.TableLayout
import java.io.File
import kotlin.random.Random

// A message for a dialog, such as how a purchase went
data class Notice(val title: String, val message: String)

// A card (and the cards on top of it) Hint points at, or the deck; changes each time so the same hint can wiggle again
data class HintTarget(val cards: List<Card>, val deck: Boolean, val serial: Int)

// The game, its settings and the Unlimited Undo purchase, kept across rotation and resizing.  The game is saved after
// every turn, so nothing is lost if Android stops the app in the background.
class GameViewModel(application: Application) : AndroidViewModel(application) {

    private val prefs = application.getSharedPreferences("settings", Context.MODE_PRIVATE)
    private val savedGameFile = File(application.filesDir, "SavedGame.json")
    val customBackFile = File(application.filesDir, "CardBack.png")

    val store: UpgradeStore = storeFactory(application, viewModelScope)

    private val session: Session

    var game by mutableStateOf(Game.first())
        private set
    var canUndo by mutableStateOf(false)
        private set
    var autoMoves by mutableStateOf(false)
        private set
    var showsNoMoves by mutableStateOf(prefs.getBoolean(SHOWS_NO_MOVES, false))
        private set
    var highlightsDrops by mutableStateOf(prefs.getBoolean(HIGHLIGHTS_DROPS, false))
        private set
    // Changes whenever the card back does, so the art is decoded again
    var cardBackVersion by mutableIntStateOf(0)
        private set
    // Reads cardBackVersion so whatever shows this updates when the back changes
    val hasCustomBack: Boolean get() = cardBackVersion >= 0 && customBackFile.exists()

    // What the "nothing to play" banner says, if it's showing
    var noMoves by mutableStateOf<PlayState?>(null)
        private set
    var hint by mutableStateOf<HintTarget?>(null)
        private set
    var notice by mutableStateOf<Notice?>(null)
    // Something for TalkBack to read out, such as "New game dealt"; the serial makes repeats count
    var announcement by mutableStateOf<Pair<String, Int>?>(null)
        private set
    // The card a TalkBack user has picked to move, and where it is (see TableScreen's stack actions)
    var selection by mutableStateOf<Pair<Spot, Int>?>(null)
        private set

    // What loadSavedGame found, for init
    private var autoMovesFromSave = false
    private var restoredRecord: Triple<Int, Int, Int>? = null

    private var dealtAt = System.currentTimeMillis()
    private var noMovesJob: Job? = null
    private var serial = 0

    init {
        val loaded = loadSavedGame()
        session = Session(loaded ?: Game.first(), autoMoves = autoMovesFromSave)
        if (loaded == null) {
            restoredRecord?.let { (score, wins, losses) ->
                // The saved game had been won (or couldn't be read), so deal a new one
                session.restore(Game(Table.deal(Card.all.shuffled()), score - Game.GAME_COST, wins, losses))
            }
        }
        viewModelScope.launch {
            store.state.collect {
                session.unlimitedUndo = it.owned
                publish(save = false)
            }
        }
        publish(save = false)
    }

    // MARK: Playing

    fun move(from: Spot, index: Int, to: Spot): Boolean {
        val moved = session.move(from, index, to)
        if (moved) {
            afterTurn()
        }
        return moved
    }

    fun canMove(from: Spot, index: Int, to: Spot) = !game.won && game.table.canMove(from, index, to)

    fun putUp(from: Spot): Boolean {
        val moved = session.putUp(from)
        if (moved) {
            afterTurn()
        }
        return moved
    }

    fun deal() {
        if (session.deal()) {
            dealtAt = System.currentTimeMillis()
            afterTurn()
        }
    }

    fun newGame() {
        val wasWon = game.won
        session.newGame(Random.Default)
        dealtAt = System.currentTimeMillis()
        publish()
        announce(if (wasWon) "New game dealt" else "New game dealt. Undo brings back the game you were playing.")
    }

    fun undo() {
        if (session.undo()) {
            publish()
            announce("Undone")
        }
    }

    private fun afterTurn() {
        publish()
        if (game.won) {
            announce("You won! $${Game.WIN_BONUS}")
        }
    }

    private fun publish(save: Boolean = true) {
        game = session.game
        canUndo = session.canUndo
        autoMoves = session.autoMoves
        selection = selection?.takeIf { (spot, index) -> index < game.table.cards(spot).size }
        updateNoMoves()
        if (save) {
            save()
        }
    }

    // MARK: Help

    fun showHint() {
        val table = game.table
        val move = table.findMove()
        serial += 1
        if (move != null) {
            hint = HintTarget(table.cards(move.from).drop(move.index), deck = false, serial = serial)
            announce("Move the ${table.cards(move.from)[move.index].name} to ${move.to.name.lowercase()}")
            return
        }
        if (table.playState() == PlayState.NeedsDeal) {
            hint = HintTarget(emptyList(), deck = true, serial = serial)
            announce(if (table.deck.isEmpty()) "Turn the deck over" else "Deal more cards")
        }
        else {
            updateNoMoves(forHint = true)
        }
    }

    // The banner waits a few seconds after a deal, so it doesn't flash up while the player is still looking at the cards
    private fun updateNoMoves(forHint: Boolean = false) {
        noMovesJob?.cancel()
        if (game.won || !(showsNoMoves || forHint)) {
            noMoves = null
            return
        }
        val state = game.table.playState().takeIf { it != PlayState.CanPlay }
        val wait = NO_MOVES_DELAY_MS - (System.currentTimeMillis() - dealtAt)
        if (state != null && !forHint && wait > 0) {
            noMoves = null
            noMovesJob = viewModelScope.launch {
                delay(wait)
                updateNoMoves()
            }
            return
        }
        if (state != noMoves && state != null) {
            announce(if (state == PlayState.NeedsDeal) "Nothing to play" else "No moves left")
        }
        noMoves = state
    }

    // MARK: Settings

    fun toggleAutoMoves() {
        session.autoMoves = !session.autoMoves
        publish()
    }

    fun toggleShowsNoMoves() {
        showsNoMoves = !showsNoMoves
        prefs.edit().putBoolean(SHOWS_NO_MOVES, showsNoMoves).apply()
        updateNoMoves()
    }

    fun toggleHighlightsDrops() {
        highlightsDrops = !highlightsDrops
        prefs.edit().putBoolean(HIGHLIGHTS_DROPS, highlightsDrops).apply()
    }

    fun resetStats() {
        session.resetStats()
        publish()
        announce("Wins and losses reset")
    }

    // Crops a chosen photo to card proportions, as the iOS app does, and keeps it as the card back; its corners are
    // rounded as it's drawn, to match the faces showing
    fun setCardBack(uri: Uri?) {
        viewModelScope.launch {
            withContext(Dispatchers.IO) {
                if (uri == null) {
                    customBackFile.delete()
                }
                else {
                    runCatching {
                        val source = ImageDecoder.createSource(getApplication<Application>().contentResolver, uri)
                        val photo = ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
                            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                        }
                        cardShaped(photo).compress(Bitmap.CompressFormat.PNG, 100, customBackFile.outputStream())
                    }.onFailure {
                        notice = Notice("Couldn't Use That Photo", "Try choosing a different one.")
                    }
                }
            }
            cardBackVersion += 1
        }
    }

    // MARK: Debug

    // This phone's code for unlocking the Debug menu (see DebugAccess)
    val deviceCode = DebugAccess.deviceCode(
        Settings.Secure.getString(application.contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown")
    // Builds run from Android Studio or Gradle, which always have the Debug menu
    val isDebuggable = application.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
    var debugUnlocked by mutableStateOf(isDebuggable || DebugAccess.isValid(prefs.getString(DebugAccess.UNLOCK_KEY, null) ?: "", deviceCode))
        private set
    // The card faces picked in the Debug menu, if any
    private var pickedCardFaces by mutableStateOf(
        prefs.getString(DebugAccess.CARD_FACES_KEY, null)?.let { name -> CardFaces.entries.firstOrNull { it.name == name } })

    // The card faces picked in the Debug menu while it's unlocked, or null for the game's own
    val debugCardFaces: CardFaces? get() = pickedCardFaces.takeIf { debugUnlocked }

    // The faces to show on a table of this size
    fun cardFaces(roomy: Boolean) = debugCardFaces ?: CardFaces.standard(roomy)

    // Takes an unlock made by scripts/debug-unlock.sh for this phone's code; false if it doesn't fit
    fun unlockDebug(unlock: String): Boolean {
        if (!DebugAccess.isValid(unlock, deviceCode)) {
            return false
        }
        prefs.edit().putString(DebugAccess.UNLOCK_KEY, unlock.trim()).apply()
        debugUnlocked = true
        announce("Debug menu unlocked")
        return true
    }

    fun lockDebug() {
        prefs.edit().remove(DebugAccess.UNLOCK_KEY).apply()
        debugUnlocked = isDebuggable
    }

    fun setDebugCardFaces(faces: CardFaces?) {
        pickedCardFaces = faces
        prefs.edit().apply { if (faces == null) remove(DebugAccess.CARD_FACES_KEY) else putString(DebugAccess.CARD_FACES_KEY, faces.name) }.apply()
    }

    // Swaps the game for one a card from winning, without counting a loss; Undo brings back the game it replaced
    fun dealAlmostWon() {
        session.replaceTable(DebugAccess.ALMOST_WON)
        dealtAt = System.currentTimeMillis()
        publish()
        announce("Almost won game dealt")
    }

    // Puts every card up and wins
    fun winNow() {
        if (session.winNow()) {
            afterTurn()
        }
    }

    // MARK: Unlimited Undo

    fun buyUnlimitedUndo(activity: Activity) {
        viewModelScope.launch {
            when (val outcome = store.buy(activity)) {
                PurchaseOutcome.Purchased -> notice = Notice("Unlimited Undo",
                    "Undo now takes back as many moves as you like, even auto moves and New Game.")
                PurchaseOutcome.Pending -> notice = Notice("Waiting for Payment",
                    "Unlimited Undo will turn on once Google Play confirms the payment.")
                PurchaseOutcome.Cancelled -> {}
                is PurchaseOutcome.Failed -> notice = Notice("Couldn't Buy Unlimited Undo", outcome.message)
            }
        }
    }

    fun refreshPurchases() {
        viewModelScope.launch { store.refresh() }
    }

    // MARK: TalkBack

    // Activating a stack selects its top card to move, moves the selected card there, or (the deck) deals
    fun activate(spot: Spot) {
        val table = game.table
        val current = selection
        when {
            spot.pile == Pile.Deck -> {
                selection = null
                deal()
            }
            current != null && current.first == spot -> {
                selection = null
                announce("Deselected")
            }
            current != null -> {
                val (from, index) = current
                val name = table.cards(from)[index].name
                selection = null
                if (move(from, index, spot)) {
                    announce("Moved $name to ${spot.name.lowercase()}" + if (game.won) ". You won!" else "")
                }
                else {
                    announce("$name can't go there")
                }
            }
            spot.pile != Pile.Upper && table.cards(spot).isNotEmpty() -> select(spot, table.cards(spot).lastIndex)
        }
    }

    fun select(spot: Spot, index: Int) {
        selection = spot to index
        announce("Selected ${game.table.cards(spot)[index].name}")
    }

    private fun announce(text: String) {
        serial += 1
        announcement = text to serial
    }

    // MARK: Saving

    private fun loadSavedGame(): Game? {
        val text = runCatching { savedGameFile.readText() }.getOrNull() ?: return null
        val loaded = SavedGame.decode(text) ?: return null
        autoMovesFromSave = loaded.autoMoves
        restoredRecord = Triple(loaded.score, loaded.wins, loaded.losses)
        return loaded.game
    }

    private fun save() {
        val text = SavedGame.encode(session.game, session.autoMoves)
        viewModelScope.launch(Dispatchers.IO) {
            runCatching {
                val temp = File(savedGameFile.parentFile, savedGameFile.name + ".tmp")
                temp.writeText(text)
                temp.renameTo(savedGameFile)
            }
        }
    }

    companion object {
        const val SHOWS_NO_MOVES = "ShowsNoMoves"
        const val HIGHLIGHTS_DROPS = "HighlightsDrops"
        const val NO_MOVES_DELAY_MS = 8_000L

        // Tests and screenshot builds swap in a FakeUpgradeStore
        var storeFactory: (Application, kotlinx.coroutines.CoroutineScope) -> UpgradeStore = { app, scope -> PlayUpgradeStore(app, scope) }

        fun cardShaped(photo: Bitmap): Bitmap {
            val width = 500
            val height = (width * TableLayout.ASPECT).toInt()
            val out = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(out)
            val scale = maxOf(width.toFloat() / photo.width, height.toFloat() / photo.height)
            val drawnWidth = photo.width * scale
            val drawnHeight = photo.height * scale
            val left = (width - drawnWidth) / 2
            val top = (height - drawnHeight) / 2
            canvas.drawBitmap(photo, null, RectF(left, top, left + drawnWidth, top + drawnHeight), Paint(Paint.FILTER_BITMAP_FLAG))
            return out
        }
    }
}
