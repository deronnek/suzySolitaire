package net.dseelig.suzesolitaire

import android.annotation.SuppressLint
import android.app.Activity
import android.content.pm.ActivityInfo

// scripts/android-screenshots.sh launches debug builds with an orientation, as the iOS scripts do.  Only debug builds
// have this; release builds' copy does nothing, so they never lock the orientation (Play checks for any code that can).
@SuppressLint("SourceLockedOrientationActivity")
fun applyScreenshotOrientation(activity: Activity) {
    when (activity.intent.getStringExtra("screenshotOrientation")) {
        "landscape" -> activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        "portrait" -> activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
    }
}
