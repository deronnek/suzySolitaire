package net.dseelig.suzesolitaire

import android.annotation.SuppressLint
import android.content.pm.ActivityInfo
import android.content.pm.ApplicationInfo
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

    // Locking the orientation is only for the screenshot script, in debug builds
    @SuppressLint("SourceLockedOrientationActivity")
    override fun onCreate(savedInstanceState: Bundle?) {
        // The felt runs under the status and navigation bars, which show light icons on it
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT), navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT))
        super.onCreate(savedInstanceState)
        // scripts/android-screenshots.sh launches debug builds with an orientation, as the iOS scripts do
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            when (intent.getStringExtra("screenshotOrientation")) {
                "landscape" -> requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                "portrait" -> requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            }
        }
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
