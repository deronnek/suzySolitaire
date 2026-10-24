package net.dseelig.suzesolitaire.ui

import net.dseelig.suzesolitaire.game.Spot
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TableLayoutTest {

    // Phones, foldables and tablets in both orientations, with their usual system bars and cutouts
    private val windows = listOf(
        "phone" to TableLayout(412f, 915f, Insets(top = 48f, bottom = 24f)),
        "phone landscape" to TableLayout(915f, 412f, Insets(left = 48f, top = 24f, bottom = 24f)),
        "small phone" to TableLayout(360f, 740f, Insets(top = 24f, bottom = 48f)),
        "small phone landscape" to TableLayout(740f, 360f, Insets(top = 24f, right = 48f)),
        "foldable cover" to TableLayout(344f, 882f, Insets(top = 40f, bottom = 24f)),
        "foldable unfolded" to TableLayout(841f, 701f, Insets(top = 32f, bottom = 24f)),
        "tablet" to TableLayout(800f, 1280f, Insets(top = 24f, bottom = 24f)),
        "tablet landscape" to TableLayout(1280f, 800f, Insets(top = 24f, bottom = 24f)),
    )

    @Test
    fun windowSizeChoosesLayout() {
        assertFalse(TableLayout(412f, 915f).roomy)
        assertFalse("a phone on its side", TableLayout(915f, 412f).roomy)
        assertTrue(TableLayout(800f, 1280f).roomy)
        assertTrue("an unfolded foldable", TableLayout(841f, 701f).roomy)
        assertEquals(48f, TableLayout(412f, 915f).buttonSize)
        assertEquals(56f, TableLayout(800f, 1280f).buttonSize)
    }

    @Test
    fun buttonsKeepToTheCorners() {
        for ((name, t) in windows) {
            assertTrue(name, t.newGame.left < t.width / 4 && t.newGame.top < t.height / 4)
            assertTrue(name, t.undo.right > t.width * 3 / 4 && t.undo.top == t.newGame.top)
            assertEquals("$name: the menu is under Undo", t.undo.right, t.menu.right)
            assertTrue(name, t.menu.top > t.height * 3 / 4)
            assertTrue("$name: clear of the status bar", t.newGame.top >= t.insets.top)
            assertTrue("$name: clear of the navigation bar", t.menu.bottom <= t.height - t.insets.bottom)
            assertTrue("$name: clear of a side cutout", t.newGame.left >= t.insets.left && t.undo.right <= t.width - t.insets.right)
            assertEquals(name, t.score.centerY, t.menu.centerY, 0.01f)
            assertTrue("$name: the score stops before the menu button", t.score.right < t.menu.left)
        }
    }

    @Test
    fun tableFitsOnScreenAndClearsTheButtons() {
        for ((name, t) in windows) {
            for (spot in Spot.all) {
                val outline = t.outline(spot)
                assertTrue("$name: $spot is on screen", outline.left >= 0 && outline.right <= t.width && outline.top >= 0)
                for (button in listOf(t.newGame, t.undo, t.menu)) {
                    assertFalse("$name: $spot overlaps a button", outline.intersects(button))
                }
                assertFalse("$name: $spot overlaps the score", outline.intersects(t.score))
            }
            // The cards fill most of the width, so they don't float in empty felt
            val left = Spot.all.minOf { t.outline(it).left }
            val right = Spot.all.maxOf { t.outline(it).right }
            assertTrue("$name uses the width", right - left > (if (t.landscape) 0.5f else 0.8f) * t.width)
        }
    }

    @Test
    fun stacksDontOverlapEachOther() {
        for ((name, t) in windows) {
            val outlines = Spot.all.map { it to t.outline(it) }
            for ((a, boxA) in outlines) {
                for ((b, boxB) in outlines) {
                    if (a != b) {
                        assertFalse("$name: $a and $b", boxA.intersects(boxB))
                    }
                }
            }
        }
    }

    @Test
    fun upperStacksClearLowerStacks() {
        for ((name, t) in windows) {
            for (i in 0 until 4) {
                val upper = t.stackBox(Spot.upper(i), 13)
                assertTrue("$name: upper stack ${i + 1}", upper.bottom <= t.outline(Spot.lower(i)).top)
            }
            assertTrue("$name: the blind fanned out", t.stackBox(Spot.Blind, 13).bottom <= t.outline(Spot.Deck).top || t.landscape)
        }
    }

    @Test
    fun longStacksSqueezeAboveTheBottom() {
        for ((name, t) in windows) {
            // A full run, King down to Ace
            val long = t.stackBox(Spot.lower(0), 13)
            // In landscape the lower stacks run down beside the menu button, to the bottom of the screen
            val bottom = if (t.landscape) t.height - t.insets.bottom else t.tableBottom
            assertTrue("$name: ${long.bottom} vs $bottom", long.bottom <= bottom + 0.5f)
            assertFalse("$name: a long stack runs into the menu button", long.intersects(t.menu))
            val blind = t.stackBox(Spot.Blind, 13)
            assertTrue("$name: the blind stays clear of the banner", blind.bottom <= t.banner(t.bannerMaxWidth).top)
            assertTrue(name, t.slice(Spot.lower(0), 2) >= t.slice(Spot.lower(0), 13))
        }
    }

    @Test
    fun bannersSitAboveOrBesideTheScore() {
        for ((name, t) in windows) {
            val banner = t.banner(minOf(300f, t.bannerMaxWidth))
            assertFalse("$name: banner over the menu button", banner.intersects(t.menu))
            assertFalse("$name: banner over the score", banner.intersects(t.score))
            assertTrue(name, banner.bottom <= t.menu.top)
            for (spot in Spot.all) {
                assertFalse("$name: banner over $spot", banner.intersects(t.outline(spot)))
            }
            if (!t.landscape) {
                assertTrue("$name: banner over the cards' room", banner.top >= t.tableBottom)
            }
        }
    }
}
