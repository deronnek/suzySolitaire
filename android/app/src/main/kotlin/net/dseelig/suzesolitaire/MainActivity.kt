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
import net.dseelig.suzesolitaire.ui.SuzeTheme
import net.dseelig.suzesolitaire.ui.TableScreen

class MainActivity : ComponentActivity() {
    private val game: GameViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        // The felt runs under the status and navigation bars, which show light icons on it
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT), navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT))
        super.onCreate(savedInstanceState)
        applyScreenshotOrientation(this)
        setContent {
            SuzeTheme {
                var showingRules by rememberSaveable { mutableStateOf(false) }
                // The system photo picker gives the app only the photo chosen, so no permission is needed
                val pickBack = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
                    uri?.let(game::setCardBack)
                }
                BackHandler(enabled = showingRules) { showingRules = false }
                AnimatedContent(showingRules, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "screen") { rules ->
                    if (rules) {
                        HowToPlayScreen(onBack = { showingRules = false })
                    }
                    else {
                        TableScreen(game,
                            onHowToPlay = { showingRules = true },
                            onChooseCardBack = { pickBack.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) })
                    }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Purchases made on another device, approved while away, or refunded
        game.refreshPurchases()
    }
}
