package net.dseelig.suzesolitaire.ui

import android.view.HapticFeedbackConstants
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import net.dseelig.suzesolitaire.GameViewModel
import net.dseelig.suzesolitaire.game.Card
import net.dseelig.suzesolitaire.game.Pile
import net.dseelig.suzesolitaire.game.Spot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

// How long cards take to slide to a new place, as on iOS
const val SLIDE_MS = 200

// The card being dragged, and the cards on top of it, from where they were picked up
private data class Drag(val from: Spot, val index: Int, val offset: Offset, val target: Spot?)

@Composable
fun TableScreen(vm: GameViewModel, onHowToPlay: () -> Unit, onChooseCardBack: () -> Unit) {
    val colors = LocalTableColors.current
    val density = LocalDensity.current
    val direction = LocalLayoutDirection.current
    val safe = WindowInsets.safeDrawing
    BoxWithConstraints(Modifier.fillMaxSize().background(colors.felt)) {
        val insets = with(density) {
            Insets(safe.getLeft(this, direction).toDp().value, safe.getTop(this).toDp().value,
                safe.getRight(this, direction).toDp().value, safe.getBottom(this).toDp().value)
        }
        val layout = remember(maxWidth, maxHeight, insets) { TableLayout(maxWidth.value, maxHeight.value, insets) }
        Table(vm, layout)
        Controls(vm, layout, onHowToPlay, onChooseCardBack)
        StackSemantics(vm, layout)
    }
}

@Composable
private fun Table(vm: GameViewModel, layout: TableLayout) {
    val colors = LocalTableColors.current
    val density = LocalDensity.current
    val view = LocalView.current
    val resources = LocalResources.current
    val scope = rememberCoroutineScope()
    var drag by remember { mutableStateOf<Drag?>(null) }
    val game = vm.game

    // The card art, decoded at the size it's drawn.  The last set stays up while a new size decodes.
    val widthPx = with(density) { layout.cardWidth.dp.roundToPx() }
    var faces by remember { mutableStateOf<CardArt.Faces?>(null) }
    LaunchedEffect(widthPx, layout.roomy, vm.cardBackVersion) {
        faces = withContext(Dispatchers.Default) {
            CardArt.decode(resources, max(widthPx, 1), layout.roomy, vm.customBackFile.takeIf { vm.hasCustomBack })
        }
    }

    val placed = if (game.won) Placement.victory(layout) else Placement.place(game.table, layout, drag?.let { it.from to it.index })
    val corner = RoundedCornerShape((layout.cardWidth * TableLayout.CORNER_FRACTION).dp)

    // Outlines of the stacks' spots, under the cards, so they show when the cards move off them
    if (!game.won) {
        for (spot in Spot.all) {
            val box = layout.outline(spot)
            Box(Modifier
                .offset(box.left.dp, box.top.dp)
                .size(box.width.dp, box.height.dp)
                .border(2.dp, colors.outline, corner))
        }
    }

    // Each card slides from where it was to where it goes.  Cards that were let go after a drag also carry the distance
    // they were dragged, shrinking to nothing as they slide, so they set off from where they were dropped.  When the
    // window changes size, they jump to their new places instead.
    val release = remember { mutableStateMapOf<Card, Animatable<Offset, *>>() }
    var laidOut by remember { mutableStateOf(layout) }
    val resized = laidOut != layout
    SideEffect { laidOut = layout }
    val wiggle = remember { Animatable(0f) }
    LaunchedEffect(vm.hint?.serial) {
        if (vm.hint != null) {
            wiggle.snapTo(0f)
            wiggle.animateTo(0f, keyframes {
                durationMillis = 600
                -4f at 85
                4f at 170
                -4f at 255
                4f at 340
                -2f at 425
            })
        }
    }
    val hinted = vm.hint?.cards.orEmpty().toSet()
    val draggedCards = drag?.let { d -> game.table.cards(d.from).drop(d.index).toSet() }.orEmpty()
    val selected = vm.selection?.let { (spot, index) -> game.table.cards(spot).drop(index).toSet() }.orEmpty()

    // Keyed by card, so each card keeps its slide as it moves between stacks
    for (p in placed) key(p.card.id) {
        val target = Offset(p.box.left, p.box.top)
        val anim = remember { Animatable(target, Offset.VectorConverter) }
        LaunchedEffect(p.card, target) {
            if (resized) {
                anim.snapTo(target)
            }
            else if (anim.targetValue != target) {
                anim.animateTo(target, tween(SLIDE_MS, easing = LinearOutSlowInEasing))
            }
        }
        val dragging = p.card in draggedCards
        val offset = if (dragging) drag!!.offset else release[p.card]?.value ?: Offset.Zero
        // Covered cards fade to blank as the cards dealt over them slide in
        val blank by animateFloatAsState(if (p.covered) 1f else 0f, tween(SLIDE_MS, easing = FastOutSlowInEasing), label = "blank")
        val faceArt = faces
        val image = when {
            faceArt == null -> null
            p.faceUp -> faceArt.faces[p.card.id]
            else -> faceArt.back
        }
        val shake = if (p.card in hinted || (vm.hint?.deck == true && p.spot.pile == Pile.Deck && p.index == game.table.deck.lastIndex)) wiggle.value else 0f
        Box(Modifier
            .offset { (anim.value + offset).let { IntOffset(it.x.dp.roundToPx(), it.y.dp.roundToPx()) } }
            .size(p.box.width.dp, p.box.height.dp)
            .zIndex(if (dragging) 10_000f + p.index else if (anim.isRunning) 5_000f + p.z else p.z)
            .graphicsLayer { rotationZ = shake }
            .then(if (p.shadowed || dragging) Modifier.dropShadow(corner, Shadow(radius = 3.dp, color = Color.Black.copy(alpha = 0.35f))) else Modifier)
            .clip(corner)
            .background(Color.White)
            .border(0.5.dp, Color.Black.copy(alpha = 0.8f), corner)
            .then(if (p.card in selected) Modifier.border(3.dp, colors.dropHighlight, corner) else Modifier)
            .clearAndSetSemantics {}) {
            if (image != null) {
                Image(image, contentDescription = null, contentScale = ContentScale.FillBounds, modifier = Modifier.fillMaxSize())
            }
            if (blank > 0f) {
                Box(Modifier.fillMaxSize().graphicsLayer { alpha = blank }.background(Color.White))
            }
        }
    }

    // Where the dragged card would land, when Highlight Drop Spot is on
    val target = drag?.target
    if (target != null && vm.highlightsDrops) {
        val cards = game.table.cards(target)
        val box = if (cards.isEmpty()) layout.outline(target) else layout.cardBox(target, cards.lastIndex, cards.size)
        Box(Modifier
            .offset((box.left - 2).dp, (box.top - 2).dp)
            .size((box.width + 4).dp, (box.height + 4).dp)
            .zIndex(9_999f)
            .border(2.5.dp, colors.dropHighlight, RoundedCornerShape((layout.cardWidth * TableLayout.CORNER_FRACTION + 2).dp)))
    }

    // Touches: drag a card or run to move it, double-tap a card to send it up, and tap the deck or anywhere off the
    // cards to deal.  A second finger is ignored while one is down.
    val currentPlaced by rememberUpdatedState(placed)
    val currentLayout by rememberUpdatedState(layout)
    val doubleTapMs = LocalViewConfiguration.current.doubleTapTimeoutMillis
    var lastTap by remember { mutableStateOf<Pair<Card, Long>?>(null) }
    Box(Modifier
        .fillMaxSize()
        .zIndex(-1f)
        .pointerInput(Unit) {
            awaitEachGesture {
                val down = awaitFirstDown(requireUnconsumed = false)
                if (vm.game.won) {
                    return@awaitEachGesture
                }
                val start = Offset(down.position.x.toDp().value, down.position.y.toDp().value)
                val hit = currentPlaced.filter { it.box.contains(start.x, start.y) }.maxByOrNull { it.z }
                val table = vm.game.table
                // Cards under the top of the blind and deal can't be played, and the deck only deals
                val canPick = hit != null && hit.spot.pile != Pile.Deck &&
                    !((hit.spot.pile == Pile.Blind || hit.spot.pile == Pile.Deal) && hit.index != table.cards(hit.spot).lastIndex) &&
                    !(hit.spot.pile == Pile.Upper)
                if (canPick) {
                    view.performHapticFeedback(HapticFeedbackConstants.GESTURE_START)
                }
                var dragged = false
                var cancelled = false
                while (true) {
                    val event = awaitPointerEvent()
                    val change = event.changes.firstOrNull { it.id == down.id }
                    if (change == null) {
                        cancelled = true
                        break
                    }
                    if (!change.pressed) {
                        break
                    }
                    val delta = change.position - down.position
                    if (!dragged && canPick && delta.getDistance() > viewConfiguration.touchSlop) {
                        dragged = true
                    }
                    if (dragged) {
                        change.consume()
                        val offset = Offset(delta.x.toDp().value, delta.y.toDp().value)
                        val target = dropTarget(vm, currentLayout, hit!!.spot, hit.index, offset)
                        if (target != drag?.target && target != null && vm.highlightsDrops) {
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                        }
                        drag = Drag(hit.spot, hit.index, offset, target)
                    }
                }
                if (dragged) {
                    val d = drag
                    drag = null
                    if (d != null) {
                        // The cards slide on from where they were let go: to their new place, or back where they were
                        for (card in vm.game.table.cards(d.from).drop(d.index)) {
                            val carried = Animatable(d.offset, Offset.VectorConverter)
                            release[card] = carried
                            scope.launch {
                                carried.animateTo(Offset.Zero, tween(SLIDE_MS, easing = LinearOutSlowInEasing))
                                if (release[card] === carried) {
                                    release.remove(card)
                                }
                            }
                        }
                        val moved = !cancelled && d.target != null && vm.move(d.from, d.index, d.target)
                        view.performHapticFeedback(if (moved) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.REJECT)
                    }
                    return@awaitEachGesture
                }
                if (cancelled) {
                    return@awaitEachGesture
                }
                // A tap
                when {
                    hit == null || hit.spot.pile == Pile.Deck -> {
                        lastTap = null
                        vm.deal()
                    }
                    canPick -> {
                        val now = down.uptimeMillis
                        val previous = lastTap
                        if (previous != null && previous.first == hit.card && now - previous.second < doubleTapMs &&
                            hit.index == vm.game.table.cards(hit.spot).lastIndex) {
                            lastTap = null
                            if (vm.putUp(hit.spot)) {
                                view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                            }
                        }
                        else {
                            lastTap = hit.card to now
                        }
                    }
                }
            }
        })
}

// The stack the dragged card would go to if dropped now: of the stacks that would take it, the one it overlaps most,
// counting a margin around each stack (a quarter of a card's width) so near misses still land.  The margin doesn't
// count when the card is squarely on another stack, so a card dropped on a stack that won't take it doesn't go next door.
private fun dropTarget(vm: GameViewModel, layout: TableLayout, from: Spot, index: Int, offset: Offset): Spot? {
    val table = vm.game.table
    val count = table.cards(from).size
    val start = layout.cardBox(from, index, count)
    val dragged = Box(start.left + offset.x, start.top + offset.y, start.width, start.height)
    val reach = dragged.width * 0.25f
    val stacks = (Spot.uppers + Spot.lowers).filter { it != from }
    val squarelyOn = stacks.firstOrNull { layout.stackBox(it, table.cards(it).size).contains(dragged.centerX, dragged.centerY) }
    var best: Spot? = null
    var bestArea = 0f
    for (target in stacks) {
        val margin = if (squarelyOn == null || squarelyOn == target) reach else 0f
        val area = layout.stackBox(target, table.cards(target).size).let { b ->
            val l = max(b.left - margin, dragged.left)
            val r = min(b.right + margin, dragged.right)
            val t = max(b.top - margin, dragged.top)
            val btm = min(b.bottom + margin, dragged.bottom)
            if (r > l && btm > t) (r - l) * (btm - t) else 0f
        }
        if (area > bestArea && vm.canMove(from, index, target)) {
            best = target
            bestArea = area
        }
    }
    return best
}
