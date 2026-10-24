package net.dseelig.suzesolitaire.ui

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import net.dseelig.suzesolitaire.R

object Rules {
    // The iOS app's rules.  Text between asterisks is emphasized.
    val rules = listOf(
        "Cards must alternate colors in the lower four stacks and count down.",
        "Cards must be of the same suit in the upper four stacks and count up.",
        "Tap the deck to get three cards at a time.",
        "There are 13 face-up cards above the deck (the \"blind\").",
        "A King is \"below\" an Ace, and a Two is \"above\" an Ace.",
        "Upper stacks must start with the card dealt.",
        "Empty lower stacks may only be filled with cards from the blind.",
        "If the blind is empty, gaps may be filled with a card that is one below the card dealt to the upper stack.",
        "$5 is awarded for each card placed in an upper stack.",
        "Winning the game gains you $250.",
        "Auto moves any available card to an upper stack.",
        "Auto moves *cannot* be undone, unless you have Unlimited Undo.",
    )

    fun styled(rule: String) = buildAnnotatedString {
        rule.split("*").forEachIndexed { i, piece ->
            if (i % 2 == 1) withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append(piece) } else append(piece)
        }
    }
}

// The rules as a numbered list that wraps and scrolls, in the system font at the size set in Settings
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HowToPlayScreen(onBack: () -> Unit) {
    val scroll = TopAppBarDefaults.pinnedScrollBehavior()
    Scaffold(
        modifier = Modifier.fillMaxSize().nestedScroll(scroll.nestedScrollConnection),
        topBar = {
            TopAppBar(
                title = { Text("How to Play") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(painterResource(R.drawable.ic_back), contentDescription = "Back") }
                },
                scrollBehavior = scroll,
            )
        },
    ) { padding ->
        LazyColumn(contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = padding.calculateTopPadding() + 8.dp,
            bottom = padding.calculateBottomPadding() + 24.dp)) {
            itemsIndexed(Rules.rules) { i, rule ->
                val text = Rules.styled(rule)
                Row(Modifier.padding(vertical = 8.dp).clearAndSetSemantics { contentDescription = "${i + 1}. ${text.text}" }) {
                    Text("${i + 1}.", style = MaterialTheme.typography.bodyLarge, modifier = Modifier.width(36.dp))
                    Text(text, style = MaterialTheme.typography.bodyLarge)
                }
            }
        }
    }
}
