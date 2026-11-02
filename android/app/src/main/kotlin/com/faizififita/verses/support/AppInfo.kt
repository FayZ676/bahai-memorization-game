package com.faizififita.verses.support

import android.os.Build
import com.faizififita.verses.BuildConfig

object AppInfo {
    const val NAME = "Verses"
    const val PRIVACY_POLICY = "https://fayz676.github.io/bahai-memorization-game/privacy.html"

    val releaseSummary: String get() = "$NAME ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"

    val diagnostics: String get() = "$releaseSummary · ${Build.MANUFACTURER} ${Build.MODEL} · Android ${Build.VERSION.RELEASE}"
}
