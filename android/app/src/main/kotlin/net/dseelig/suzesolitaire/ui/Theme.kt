package net.dseelig.suzesolitaire.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import net.dseelig.suzesolitaire.R

// The table's own colors, the same as the iOS app's: felt green (dimmer in dark mode), white outlines on the empty spots
// (softer in dark mode), and the score in white, or pink when it's below zero
@Immutable
data class TableColors(
    val felt: Color,
    val outline: Color,
    val score: Color,
    val negativeScore: Color,
    val dropHighlight: Color,
)

val LocalTableColors = staticCompositionLocalOf { lightTable }

private val lightTable = TableColors(
    felt = Color(0xFF2E6F31),
    outline = Color.White,
    score = Color.White.copy(alpha = 0.88f),
    negativeScore = Color(0xEBFF9E99),
    dropHighlight = Color(0xD9FFD60A),
)

private val darkTable = lightTable.copy(
    felt = Color(0xFF173819),
    outline = Color.White.copy(alpha = 0.6f),
)

// Futura on iOS; Jost, an open-source font drawn after it, here
val ScoreFont = FontFamily(Font(R.font.jost_medium, FontWeight.Medium))

// Material 3 controls tinted to the felt rather than the wallpaper (dynamic color), so the buttons look the same on every
// phone and always suit the table
@Composable
fun SuzeTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val scheme = if (dark) {
        darkColorScheme(
            primary = Color(0xFF9AD69B),
            onPrimary = Color(0xFF00390F),
            primaryContainer = Color(0xFF1E5122),
            onPrimaryContainer = Color(0xFFB5F2B5),
            secondaryContainer = Color(0xFF3A4B39),
            onSecondaryContainer = Color(0xFFD5E8D0),
            surface = Color(0xFF121411),
            surfaceContainer = Color(0xFF1E201D),
            inverseSurface = Color(0xFFE2E3DD),
            inverseOnSurface = Color(0xFF2F312D),
        )
    }
    else {
        lightColorScheme(
            primary = Color(0xFF2E6F31),
            onPrimary = Color.White,
            primaryContainer = Color(0xFFB5F2B5),
            onPrimaryContainer = Color(0xFF002106),
            secondaryContainer = Color(0xFFCCE8C8),
            onSecondaryContainer = Color(0xFF0F1F10),
            surface = Color(0xFFF7FBF2),
            surfaceContainer = Color(0xFFECEFE7),
            inverseSurface = Color(0xFF2F312D),
            inverseOnSurface = Color(0xFFF0F1EB),
        )
    }
    androidx.compose.runtime.CompositionLocalProvider(LocalTableColors provides if (dark) darkTable else lightTable) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}
