package net.dseelig.suzesolitaire

import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import net.dseelig.suzesolitaire.ui.HowToPlayScreen
import net.dseelig.suzesolitaire.ui.StatsScreen
import net.dseelig.suzesolitaire.ui.SuzeTheme
import net.dseelig.suzesolitaire.ui.TableScreen

// The pages over the table
private enum class Page { Table, HowToPlay, Stats }

class MainActivity : ComponentActivity() {
    private val game: GameViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        // The felt runs under the status and navigation bars, which show light icons on it
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT), navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT))
        super.onCreate(savedInstanceState)
        applyScreenshotOrientation(this)
        setContent {
            SuzeTheme {
                var page by rememberSaveable { mutableStateOf(Page.Table) }
                // The system photo picker gives the app only the photo chosen, so no permission is needed
                val pickBack = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
                    uri?.let(game::setCardBack)
                }
                BackHandler(enabled = page != Page.Table) { page = Page.Table }
                AnimatedContent(page, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "screen") { showing ->
                    when (showing) {
                        Page.HowToPlay -> HowToPlayScreen(onBack = { page = Page.Table })
                        Page.Stats -> StatsScreen(game, onBack = { page = Page.Table })
                        Page.Table -> TableScreen(game,
                            onHowToPlay = { page = Page.HowToPlay },
                            onStats = { page = Page.Stats },
                            onChooseCardBack = { pickBack.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) })
                    }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        game.appOpened()
        // Purchases made on another device, approved while away, or refunded
        game.refreshPurchases()
    }

    override fun onPause() {
        super.onPause()
        game.appClosed()
    }
}
