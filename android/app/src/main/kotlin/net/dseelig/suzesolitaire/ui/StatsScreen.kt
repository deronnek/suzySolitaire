package net.dseelig.suzesolitaire.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import net.dseelig.suzesolitaire.GameViewModel
import net.dseelig.suzesolitaire.R
import net.dseelig.suzesolitaire.game.GameStats

object StatsPage {
    data class Section(val title: String, val rows: List<Pair<String, String>>, val footer: String? = null)

    private const val NONE = "—"

    private fun dollars(amount: Int) = "$$amount"

    // 3:05, or 1:02:05 past an hour
    fun duration(seconds: Double): String {
        val total = Math.round(seconds).toInt()
        val hours = total / 3600
        val minutes = total / 60 % 60
        val secs = total % 60
        return if (hours > 0) "%d:%02d:%02d".format(hours, minutes, secs) else "%d:%02d".format(minutes, secs)
    }

    private fun average(total: Double, count: Int, format: String = "%.0f") =
        if (count == 0) NONE else format.format(total / count)

    // The same sections and rows as the iOS app's Stats page
    fun sections(stats: GameStats, wins: Int, losses: Int, score: Int): List<Section> {
        val played = wins + losses
        return listOf(
            Section("Results", listOf(
                "Wins" to "$wins",
                "Losses" to "$losses",
                "Win Rate" to if (played == 0) NONE else "%.0f%%".format(100.0 * wins / played),
                "Current Streak" to "${stats.streak}",
                "Best Streak" to "${stats.bestStreak}",
            )),
            Section("Money", listOf(
                "Total" to dollars(score),
                "Best Game" to (stats.bestGame?.let(::dollars) ?: NONE),
                "Worst Game" to (stats.worstGame?.let(::dollars) ?: NONE),
                "Cards Up per Game" to average(stats.cardsUp.toDouble(), stats.games, "%.1f"),
            )),
            Section("Moves", listOf(
                "Average per Game" to average(stats.moves.toDouble(), stats.timedGames),
                "Average per Win" to average(stats.winMoves.toDouble(), stats.timedWins),
                "Fewest in a Win" to (stats.fewestWinMoves?.toString() ?: NONE),
            )),
            Section("Time", listOf(
                "Average per Game" to if (stats.timedGames == 0) NONE else duration(stats.seconds / stats.timedGames),
                "Fastest Win" to (stats.fastestWin?.let(::duration) ?: NONE),
            ), footer = "Wins and losses go back to your first game. Everything else counts games finished since Stats was " +
                "added. Time only counts while the app is open."),
        )
    }
}

// The Stats page: results, money, moves and time, each a group of rows, with a button to reset them
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatsScreen(vm: GameViewModel, onBack: () -> Unit) {
    val scroll = TopAppBarDefaults.pinnedScrollBehavior()
    val game = vm.game
    val sections = StatsPage.sections(game.stats, game.wins, game.losses, game.score)
    var confirmReset by remember { mutableStateOf(false) }
    Scaffold(
        modifier = Modifier.fillMaxSize().nestedScroll(scroll.nestedScrollConnection),
        topBar = {
            TopAppBar(
                title = { Text("Stats") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(painterResource(R.drawable.ic_back), contentDescription = "Back") }
                },
                scrollBehavior = scroll,
            )
        },
    ) { padding ->
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = padding.calculateTopPadding() + 8.dp,
                bottom = padding.calculateBottomPadding() + 24.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(sections) { section -> StatsSection(section) }
            item {
                Box(Modifier.fillMaxWidth().padding(top = 8.dp), contentAlignment = Alignment.Center) {
                    TextButton({ confirmReset = true }) { Text("Reset Stats…", color = MaterialTheme.colorScheme.error) }
                }
            }
        }
    }
    if (confirmReset) {
        AlertDialog(
            onDismissRequest = { confirmReset = false },
            title = { Text("Reset Stats?") },
            text = { Text("Your wins, losses and other stats will go back to zero. Your money and the current game won't change.") },
            confirmButton = { TextButton({ confirmReset = false; vm.resetStats() }) { Text("Reset") } },
            dismissButton = { TextButton({ confirmReset = false }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun StatsSection(section: StatsPage.Section) {
    Column {
        Text(section.title, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(start = 16.dp, top = 12.dp, bottom = 6.dp).semantics { heading() })
        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)) {
            section.rows.forEachIndexed { i, (title, value) ->
                if (i > 0) {
                    HorizontalDivider(Modifier.padding(start = 16.dp))
                }
                ListItem(
                    headlineContent = { Text(title) },
                    trailingContent = { Text(value, style = MaterialTheme.typography.bodyLarge) },
                    colors = ListItemDefaults.colors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                    modifier = Modifier.semantics(mergeDescendants = true) {},
                )
            }
        }
        section.footer?.let {
            Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 6.dp))
        }
    }
}
