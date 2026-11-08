package com.faizififita.verses.support

import android.app.Activity
import com.faizififita.verses.BuildConfig
import com.faizififita.verses.logic.AppSettings
import com.google.android.play.core.review.ReviewManagerFactory

object ReviewPrompt {
    private const val MINIMUM_MEMORIZED_PASSAGES = 2
    const val DELAY_AFTER_CELEBRATION = 3800L

    fun shouldAsk(memorizedPassageCount: Int, settings: AppSettings): Boolean =
        memorizedPassageCount >= MINIMUM_MEMORIZED_PASSAGES && settings.lastReviewRequestVersion != BuildConfig.VERSION_NAME

    fun request(activity: Activity) {
        val manager = ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener { request ->
            if (request.isSuccessful) manager.launchReviewFlow(activity, request.result)
        }
    }
}
