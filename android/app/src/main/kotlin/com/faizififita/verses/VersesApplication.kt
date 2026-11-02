package com.faizififita.verses

import android.app.Application
import com.faizififita.verses.feature.session.ConformerRecitation
import com.faizififita.verses.logic.AchievementCatalog
import com.faizififita.verses.logic.PrayerLibrary
import com.faizififita.verses.store.AppStore
import com.faizififita.verses.support.Feedback

class VersesApplication : Application() {
    lateinit var store: AppStore
        private set

    override fun onCreate() {
        super.onCreate()
        PrayerLibrary.load(assets.open("library.json").bufferedReader().use { it.readText() })
        if (BuildConfig.DEBUG) {
            val problems = AchievementCatalog.problems
            check(problems.isEmpty()) { "Broken achievements:\n" + problems.joinToString("\n") }
        }
        Feedback.install(this)
        store = AppStore(this)
        ConformerRecitation.install(this)
    }
}
