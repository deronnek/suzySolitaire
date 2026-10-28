package net.dseelig.suzesolitaire.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.pm.PackageManager
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Snackbar
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.traversalIndex
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.activity.compose.LocalActivity
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import net.dseelig.suzesolitaire.DebugAccess
import net.dseelig.suzesolitaire.GameViewModel
import net.dseelig.suzesolitaire.R
import net.dseelig.suzesolitaire.game.Pile
import net.dseelig.suzesolitaire.game.PlayState
import net.dseelig.suzesolitaire.game.Spot
import kotlin.math.roundToInt

// New Game in the top left corner, Undo in the top right, the menu in the bottom right with the score beside it, and the
// "nothing to play" banner above them.  These are Material 3 filled tonal icon buttons, Android's counterpart to the iOS
// app's glass buttons.
@Composable
fun Controls(vm: GameViewModel, layout: TableLayout, onHowToPlay: () -> Unit, onChooseCardBack: () -> Unit) {
    val iconSize = if (layout.roomy) 28.dp else 24.dp
    CornerButton(layout.newGame, "New Game", R.drawable.ic_new_game, iconSize, order = 0f, onClick = vm::newGame)
    CornerButton(layout.undo, "Undo", R.drawable.ic_undo, iconSize, order = 1f, enabled = vm.canUndo, onClick = vm::undo)
    var showUnlock by remember { mutableStateOf(false) }
    Score(vm, layout, onLongPress = { showUnlock = true })
    if (showUnlock) {
        DebugUnlock(vm) { showUnlock = false }
    }
    Box(Modifier
        .offset(layout.menu.left.dp, layout.menu.top.dp)
        .zIndex(20_000f)
        .semantics { traversalIndex = 4f }) {
        var open by remember { mutableStateOf(false) }
        CornerButton(Box(0f, 0f, layout.buttonSize, layout.buttonSize), "More", R.drawable.ic_more, iconSize, order = 4f) { open = true }
        Menu(vm, open, onDismiss = { open = false }, onHowToPlay, onChooseCardBack)
    }
    NoMovesBanner(vm, layout)
    Dialogs(vm)
    Announcer(vm)
}

@Composable
private fun CornerButton(box: Box, label: String, icon: Int, iconSize: androidx.compose.ui.unit.Dp, order: Float, enabled: Boolean = true, onClick: () -> Unit) {
    FilledTonalIconButton(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier
            .offset(box.left.dp, box.top.dp)
            .size(box.width.dp)
            .zIndex(20_000f)
            .semantics { traversalIndex = order },
    ) {
        Icon(painterResource(icon), contentDescription = label, modifier = Modifier.size(iconSize))
    }
}

// The score, wins and losses on the felt beside the menu button: following the font size set in Settings, up to twice as
// big, and shrinking to fit when they'd run into the button.  A long press on it unlocks the Debug menu (see DebugAccess).
@Composable
private fun Score(vm: GameViewModel, layout: TableLayout, onLongPress: () -> Unit) {
    val colors = LocalTableColors.current
    val game = vm.game
    val scale = LocalDensity.current.fontScale
    val base = if (layout.roomy) 24f else 17f
    val size = base * minOf(scale, 2f) / scale
    val money = if (game.score < 0) "$-${-game.score}" else "$${game.score}"
    val text = buildAnnotatedString {
        withStyle(SpanStyle(color = if (game.score < 0) colors.negativeScore else colors.score)) { append(money) }
        withStyle(SpanStyle(color = colors.score)) { append("   Wins: ${game.wins}   Losses: ${game.losses}") }
    }
    Box(Modifier
        .offset(layout.score.left.dp, layout.score.top.dp)
        .size(layout.score.width.dp, layout.score.height.dp)
        .pointerInput(Unit) { detectTapGestures(onLongPress = { onLongPress() }) }
        .semantics { traversalIndex = 3f }
        .clearAndSetSemantics { contentDescription = "$money, Wins: ${game.wins}, Losses: ${game.losses}" },
        contentAlignment = Alignment.CenterStart) {
        BasicText(text, maxLines = 1, style = TextStyle(fontFamily = ScoreFont),
            autoSize = TextAutoSize.StepBased(minFontSize = (size * 0.5f).sp, maxFontSize = size.sp, stepSize = 0.5.sp))
    }
}

@Composable
private fun Menu(vm: GameViewModel, open: Boolean, onDismiss: () -> Unit, onHowToPlay: () -> Unit, onChooseCardBack: () -> Unit) {
    val activity = LocalActivity.current
    val upgrade by vm.store.state.collectAsStateWithLifecycle()
    var confirmReset by remember { mutableStateOf(false) }
    var showAbout by remember { mutableStateOf(false) }
    DropdownMenu(expanded = open, onDismissRequest = onDismiss) {
        MenuItem("Hint", onDismiss, vm::showHint)
        MenuItem("How to Play", onDismiss, onHowToPlay)
        HorizontalDivider()
        ToggleItem("Auto Moves", vm.autoMoves, vm::toggleAutoMoves)
        ToggleItem("Show When Stuck", vm.showsNoMoves, vm::toggleShowsNoMoves)
        ToggleItem("Highlight Drop Spot", vm.highlightsDrops, vm::toggleHighlightsDrops)
        HorizontalDivider()
        MenuItem("Choose Card Back…", onDismiss, onChooseCardBack)
        if (vm.hasCustomBack) {
            MenuItem("Use Default Card Back", onDismiss) { vm.setCardBack(null) }
        }
        MenuItem("Reset Wins & Losses…", onDismiss) { confirmReset = true }
        HorizontalDivider()
        when {
            upgrade.owned -> DropdownMenuItem(
                text = { Column { Text("Unlimited Undo"); Text("Purchased. Thank you!", style = MaterialTheme.typography.bodySmall) } },
                onClick = {}, enabled = false)
            upgrade.pending -> DropdownMenuItem(
                text = { Column { Text("Unlimited Undo"); Text("Waiting for payment", style = MaterialTheme.typography.bodySmall) } },
                onClick = {}, enabled = false)
            else -> DropdownMenuItem(
                text = {
                    Column {
                        Text("Unlimited Undo" + (upgrade.price?.let { " · $it" } ?: ""))
                        Text("Undo every move, even auto moves", style = MaterialTheme.typography.bodySmall)
                    }
                },
                onClick = {
                    onDismiss()
                    activity?.let(vm::buyUnlimitedUndo)
                })
        }
        MenuItem("About", onDismiss) { showAbout = true }
        if (vm.debugUnlocked) {
            DebugItems(vm, onDismiss)
        }
    }
    if (confirmReset) {
        AlertDialog(
            onDismissRequest = { confirmReset = false },
            title = { Text("Reset Wins & Losses?") },
            text = { Text("Your wins and losses will go back to zero. Your money and the current game won't change.") },
            confirmButton = { TextButton({ confirmReset = false; vm.resetStats() }) { Text("Reset") } },
            dismissButton = { TextButton({ confirmReset = false }) { Text("Cancel") } },
        )
    }
    if (showAbout) {
        val context = LocalContext.current
        val info = remember { context.packageManager.getPackageInfo(context.packageName, PackageManager.PackageInfoFlags.of(0)) }
        AlertDialog(
            onDismissRequest = { showAbout = false },
            title = { Text("Suze Solitaire") },
            text = { Text("Version ${info.versionName} (${info.longVersionCode})\n\nBy Kevin DeRonne and David Seelig") },
            confirmButton = { TextButton({ showAbout = false }) { Text("OK") } },
        )
    }
}

// The Debug section: a game one card from winning, winning on the spot, and which card faces to show
@Composable
private fun DebugItems(vm: GameViewModel, onDismiss: () -> Unit) {
    HorizontalDivider()
    SectionLabel("Debug")
    MenuItem("Almost Won", onDismiss, vm::dealAlmostWon)
    MenuItem("Win Now", onDismiss, vm::winNow)
    SectionLabel("Card Faces")
    val picked = vm.debugCardFaces
    RadioItem("Automatic", picked == null) { vm.setDebugCardFaces(null) }
    for (faces in CardFaces.entries) {
        RadioItem(faces.title, picked == faces) { vm.setDebugCardFaces(faces) }
    }
    if (!vm.isDebuggable) {
        HorizontalDivider()
        MenuItem("Lock Debug Menu", onDismiss, vm::lockDebug)
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(text, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(start = 12.dp, top = 8.dp, bottom = 4.dp))
}

@Composable
private fun RadioItem(text: String, selected: Boolean, onClick: () -> Unit) {
    DropdownMenuItem(
        text = { Text(text) },
        leadingIcon = { RadioButton(selected = selected, onClick = null) },
        onClick = onClick,
        modifier = Modifier.semantics { this.selected = selected },
    )
}

// Shows this phone's code, to be signed by scripts/debug-unlock.sh, and takes the unlock it prints
@Composable
private fun DebugUnlock(vm: GameViewModel, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val code = DebugAccess.pretty(vm.deviceCode)
    if (vm.debugUnlocked) {
        AlertDialog(
            onDismissRequest = onDismiss,
            title = { Text("Debug Menu") },
            text = { Text("The Debug menu is on for this phone ($code).") },
            confirmButton = { TextButton(onDismiss) { Text("OK") } },
        )
        return
    }
    var unlock by remember { mutableStateOf("") }
    var wrong by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Debug Menu") },
        text = {
            Column {
                Text("This phone's code is $code. Paste the unlock that scripts/debug-unlock.sh makes for it.")
                TextButton({
                    context.getSystemService(ClipboardManager::class.java).setPrimaryClip(ClipData.newPlainText("Code", vm.deviceCode))
                }) { Text("Copy Code") }
                // As typed, without the keyboard correcting it into words
                OutlinedTextField(unlock, { unlock = it; wrong = false }, label = { Text("Unlock") }, singleLine = true,
                    isError = wrong,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None, autoCorrectEnabled = false,
                                                      keyboardType = KeyboardType.Password),
                    supportingText = if (wrong) {{ Text("That unlock doesn't fit this phone's code") }} else null)
            }
        },
        confirmButton = { TextButton({ if (vm.unlockDebug(unlock)) onDismiss() else wrong = true }) { Text("Unlock") } },
        dismissButton = { TextButton(onDismiss) { Text("Cancel") } },
    )
}

@Composable
private fun MenuItem(text: String, onDismiss: () -> Unit, onClick: () -> Unit) {
    DropdownMenuItem(text = { Text(text) }, onClick = { onDismiss(); onClick() })
}

@Composable
private fun ToggleItem(text: String, on: Boolean, onToggle: () -> Unit) {
    DropdownMenuItem(
        text = { Text(text) },
        trailingIcon = { Switch(checked = on, onCheckedChange = null, modifier = Modifier.padding(start = 8.dp)) },
        onClick = onToggle,
        modifier = Modifier.semantics { stateDescription = if (on) "On" else "Off" },
    )
}

// After each turn, when nothing on the table can be played: "Nothing to play" with Deal (or Turn Over) when a card the
// deck would turn up can be, and "No moves left" with New Game when going through the whole deck wouldn't help either.
// Material's snackbar, placed where the iOS app puts its banner.
@Composable
private fun NoMovesBanner(vm: GameViewModel, layout: TableLayout) {
    val state = vm.noMoves ?: return
    val turnOver = vm.game.table.deck.isEmpty()
    val (message, action) = when (state) {
        PlayState.NeedsDeal -> "Nothing to play" to if (turnOver) "Turn Over" else "Deal"
        else -> "No moves left" to "New Game"
    }
    val density = LocalDensity.current
    Layout(
        modifier = Modifier.zIndex(20_000f).semantics { traversalIndex = 5f },
        content = {
            Snackbar(
                action = {
                    TextButton(onClick = { if (state == PlayState.NeedsDeal) vm.deal() else vm.newGame() }) { Text(action) }
                },
                modifier = Modifier.widthIn(max = 420.dp),
            ) { Text(message) }
        },
    ) { measurables, constraints ->
        val maxWidth = with(density) { layout.bannerMaxWidth.dp.roundToPx() }
        val placeable = measurables.first().measure(Constraints(maxWidth = maxWidth))
        val box = layout.banner(with(density) { placeable.width.toDp().value })
        layout(constraints.maxWidth, constraints.maxHeight) {
            val y = with(density) { (box.centerY.dp.toPx() - placeable.height / 2f).roundToInt() }
            placeable.place(with(density) { box.left.dp.roundToPx() }, y)
        }
    }
}

@Composable
private fun Dialogs(vm: GameViewModel) {
    val notice = vm.notice ?: return
    AlertDialog(
        onDismissRequest = { vm.notice = null },
        title = { Text(notice.title) },
        text = { Text(notice.message) },
        confirmButton = { TextButton({ vm.notice = null }) { Text("OK") } },
    )
}

// Reads out what just happened, such as "New game dealt", for TalkBack
@Composable
private fun Announcer(vm: GameViewModel) {
    val text = vm.announcement?.first ?: return
    Box(Modifier.size(1.dp).semantics {
        liveRegion = LiveRegionMode.Polite
        contentDescription = text
    })
}

// TalkBack can't drag cards, so each stack is one element: activate a stack to select its top card, then activate
// another stack to move it there.  Activating the deck deals.  Lower stacks also offer actions to select any card in a
// run (to move the run), and stacks with a playable top card offer an action to put it up.
@Composable
fun StackSemantics(vm: GameViewModel, layout: TableLayout) {
    val table = vm.game.table
    val selection = vm.selection
    for ((n, spot) in Spot.all.withIndex()) {
        val cards = table.cards(spot)
        val box = layout.stackBox(spot, cards.size)
        val selected = selection?.first == spot
        val value = when {
            cards.isEmpty() -> "Empty"
            spot.pile == Pile.Deck -> if (cards.size == 1) "1 card" else "${cards.size} cards"
            // Bottom to top, so runs can be read off
            spot.pile == Pile.Lower -> cards.joinToString(", ") { it.name }
            else -> "${cards.last().name} on top, " + if (cards.size == 1) "1 card" else "${cards.size} cards"
        }
        val hint = when {
            spot.pile == Pile.Deck -> if (cards.isEmpty()) "turn the deal over" else "deal three cards"
            selection != null -> if (selected) "deselect" else "move ${table.cards(selection.first)[selection.second].name} here"
            spot.pile != Pile.Upper && cards.isNotEmpty() -> "select ${cards.last().name}"
            else -> null
        }
        val actions = buildList {
            if (spot.pile == Pile.Lower) {
                for (i in cards.indices.reversed()) {
                    if (i != cards.lastIndex && table.isRun(spot, i)) {
                        add(CustomAccessibilityAction("Select ${cards[i].name}") { vm.select(spot, i); true })
                    }
                }
            }
            if (spot.pile != Pile.Upper && spot.pile != Pile.Deck && cards.isNotEmpty() &&
                Spot.uppers.any { vm.canMove(spot, cards.lastIndex, it) }) {
                add(CustomAccessibilityAction("Put up ${cards.last().name}") { vm.putUp(spot) })
            }
        }
        Box(Modifier
            .offset(box.left.dp, box.top.dp)
            .size(box.width.dp, box.height.dp)
            .zIndex(-2f)
            .semantics {
                contentDescription = spot.name
                stateDescription = (if (selected) "Selected ${table.cards(spot)[selection!!.second].name}. " else "") + value
                role = Role.Button
                this.selected = selected
                traversalIndex = 2f + n / 100f
                onClick(label = hint) { vm.activate(spot); true }
                if (actions.isNotEmpty()) {
                    customActions = actions
                }
            })
    }
}
