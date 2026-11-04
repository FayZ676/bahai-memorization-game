package com.faizififita.verses

import android.graphics.Color as AndroidColor
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.faizififita.verses.feature.browse.BrowseScreen
import com.faizififita.verses.feature.browse.CategoryScreen
import com.faizififita.verses.feature.browse.ImportScreen
import com.faizififita.verses.feature.browse.PassageTextScreen
import com.faizififita.verses.feature.browse.PrayerPreviewScreen
import com.faizififita.verses.feature.contact.ContactPurpose
import com.faizififita.verses.feature.contact.ContactScreen
import com.faizififita.verses.feature.library.LibraryScreen
import com.faizififita.verses.feature.onboarding.LocalTour
import com.faizififita.verses.feature.onboarding.Tour
import com.faizififita.verses.feature.onboarding.TourOverlay
import com.faizififita.verses.feature.onboarding.TourStep
import com.faizififita.verses.feature.onboarding.finishTour
import com.faizififita.verses.feature.releasenotes.ReleaseNote
import com.faizififita.verses.feature.releasenotes.ReleaseNotes
import com.faizififita.verses.feature.releasenotes.ReleaseNotesOverlay
import com.faizififita.verses.feature.session.SessionScreen
import com.faizififita.verses.feature.settings.SettingsScreen
import com.faizififita.verses.feature.splash.SplashScreen
import com.faizififita.verses.logic.AppTheme
import com.faizififita.verses.logic.BrowseRoute
import com.faizififita.verses.store.AppStore
import com.faizififita.verses.support.ReminderScheduler
import com.faizififita.verses.theme.LocalDark
import com.faizififita.verses.theme.LocalFontScale
import com.faizififita.verses.theme.Motion
import com.faizififita.verses.theme.Theme
import kotlinx.coroutines.delay

sealed interface Route {
    val key: String

    data object Library : Route { override val key = "library" }
    data object Settings : Route { override val key = "settings" }
    data class Session(val passageID: String) : Route { override val key = "session/$passageID" }
    data class FullText(val passageID: String) : Route { override val key = "text/$passageID" }
    data class Import(val editingID: String?) : Route { override val key = "import/$editingID" }
    data class Browse(val focus: String?) : Route { override val key = "browse/$focus" }
    data class Category(val section: String, val name: String) : Route { override val key = "category/$section/$name" }
    data class Preview(val prayerID: Long, val highlight: IntRange?) : Route { override val key = "prayer/$prayerID/$highlight" }
    data class Contact(val purpose: ContactPurpose) : Route { override val key = "contact/$purpose" }
}

class Navigator {
    val stack = mutableStateListOf<Route>(Route.Library)
    var forward by mutableStateOf(true)
        private set

    val top: Route get() = stack.last()

    fun push(route: Route) {
        forward = true
        stack.add(route)
    }

    fun pop() {
        if (stack.size <= 1) return
        forward = false
        stack.removeAt(stack.lastIndex)
    }

    fun popToLibrary() {
        forward = false
        stack.removeRange(1, stack.size)
    }

    fun openInLibrary(passageID: String) {
        forward = true
        stack.removeRange(1, stack.size)
        stack.add(Route.Session(passageID))
    }

    fun push(route: BrowseRoute) = push(
        when (route) {
            BrowseRoute.Browse -> Route.Browse(null)
            is BrowseRoute.Collection -> Route.Browse(route.name)
            is BrowseRoute.Section -> Route.Browse(route.name)
            is BrowseRoute.Category -> Route.Category(route.section, route.name)
            is BrowseRoute.Prayer -> Route.Preview(route.id, null)
        }
    )
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        val store = (application as VersesApplication).store
        ReminderScheduler.sync(this, store.settings)
        setContent { VersesApp(this, store) }
    }
}

@Composable
private fun VersesApp(activity: ComponentActivity, store: AppStore) {
    val dark = when (store.settings.appTheme) {
        AppTheme.System -> isSystemInDarkTheme()
        AppTheme.Light -> false
        AppTheme.Dark -> true
    }
    LaunchedEffect(dark) {
        val style = if (dark) SystemBarStyle.dark(AndroidColor.TRANSPARENT)
        else SystemBarStyle.light(AndroidColor.TRANSPARENT, AndroidColor.TRANSPARENT)
        activity.enableEdgeToEdge(style, style)
    }
    CompositionLocalProvider(LocalDark provides dark, LocalFontScale provides store.settings.fontSize.scale) {
        Shell(store)
    }
}

@Composable
private fun Shell(store: AppStore) {
    val navigator = remember { Navigator() }
    val scope = rememberCoroutineScope()
    var splashFinished by remember { mutableStateOf(false) }
    var splashCleared by remember { mutableStateOf(false) }
    var tour by remember { mutableStateOf<Tour?>(null) }
    var releaseNote by remember { mutableStateOf<ReleaseNote?>(null) }
    val appAlpha by animateFloatAsState(if (splashFinished) 1f else 0f, tween(Motion.HANDOFF, easing = Motion.easeInOut), label = "handoff")

    LaunchedEffect(Unit) {
        releaseNote = ReleaseNotes.unseen(BuildConfig.VERSION_NAME, store.settings)
        store.markReleaseNotesSeen()
        if (!store.settings.hasSeenWelcomeTour) {
            store.updateSettings { it.copy(hasSeenWelcomeTour = true) }
            tour = Tour(scope)
        }
    }

    LaunchedEffect(splashFinished) {
        if (!splashFinished) return@LaunchedEffect
        delay(Motion.HANDOFF.toLong())
        splashCleared = true
    }

    LaunchedEffect(store.passages.size) {
        if (store.passages.isNotEmpty()) tour?.complete(TourStep.AddPrayer)
    }

    BackHandler(enabled = navigator.stack.size > 1) { navigator.pop() }

    Box(Modifier.fillMaxSize().background(Theme.bg)) {
        CompositionLocalProvider(LocalTour provides tour) {
            Box(Modifier.fillMaxSize().alpha(appAlpha)) {
                Screens(
                    store,
                    navigator,
                    tourActive = tour != null,
                    onRestartTour = { tour = Tour(scope) },
                    onShowReleaseNotes = { releaseNote = ReleaseNotes.latest },
                )
            }
            tour?.let { active ->
                TourOverlay(active, onSkip = { tour = null }, onFinish = { finishTour { tour = null } })
            }
        }
        releaseNote?.let { note -> ReleaseNotesOverlay(note) { releaseNote = null } }
        if (!splashCleared) {
            Box(Modifier.fillMaxSize().alpha(1f - appAlpha)) {
                SplashScreen { splashFinished = true }
            }
        }
    }
}

@Composable
private fun Screens(
    store: AppStore,
    navigator: Navigator,
    tourActive: Boolean,
    onRestartTour: () -> Unit,
    onShowReleaseNotes: () -> Unit,
) {
    val saveable = rememberSaveableStateHolder()
    AnimatedContent(
        targetState = navigator.top,
        contentKey = { it.key },
        transitionSpec = {
            if (navigator.forward) {
                (slideInHorizontally(Motion.push()) { it } + fadeIn(Motion.push())) togetherWith
                    (slideOutHorizontally(Motion.push()) { -it / 4 } + fadeOut(Motion.push()))
            } else {
                (slideInHorizontally(Motion.push()) { -it / 4 } + fadeIn(Motion.push())) togetherWith
                    (slideOutHorizontally(Motion.push()) { it } + fadeOut(Motion.push()))
            }
        },
        label = "navigation",
    ) { route ->
        saveable.SaveableStateProvider(route.key) {
            Route(route, store, navigator, tourActive, onRestartTour, onShowReleaseNotes)
        }
    }
}

@Composable
private fun Route(
    route: Route,
    store: AppStore,
    navigator: Navigator,
    tourActive: Boolean,
    onRestartTour: () -> Unit,
    onShowReleaseNotes: () -> Unit,
) {
    when (route) {
        Route.Library -> LibraryScreen(
            store,
            onSettings = { navigator.push(Route.Settings) },
            onBrowse = { navigator.push(Route.Browse(null)) },
            onOpen = { navigator.push(Route.Session(it.id)) },
        )
        Route.Settings -> SettingsScreen(
            store,
            tourActive = tourActive,
            onBack = navigator::pop,
            onRestartTour = {
                onRestartTour()
                navigator.pop()
            },
            onReleaseNotes = {
                onShowReleaseNotes()
                navigator.pop()
            },
            onReportIssue = { navigator.push(Route.Contact(ContactPurpose.ReportIssue)) },
            onFeedback = { navigator.push(Route.Contact(ContactPurpose.Feedback)) },
        )
        is Route.Session -> SessionScreen(
            store,
            route.passageID,
            onBack = navigator::pop,
            onFullText = { navigator.push(Route.FullText(route.passageID)) },
            onEdit = { navigator.push(Route.Import(route.passageID)) },
            onReportIssue = { navigator.push(Route.Contact(ContactPurpose.ReportIssue)) },
            onFeedback = { navigator.push(Route.Contact(ContactPurpose.Feedback)) },
        )
        is Route.FullText -> PassageTextScreen(store, route.passageID, onBack = navigator::pop)
        is Route.Import -> ImportScreen(store, route.editingID, onBack = navigator::pop, onCreated = navigator::popToLibrary)
        is Route.Browse -> BrowseScreen(
            route.focus,
            onBack = navigator::pop,
            onRoute = navigator::push,
            onPreview = { id, highlight -> navigator.push(Route.Preview(id, highlight)) },
            onPasteOwn = { navigator.push(Route.Import(null)) },
        )
        is Route.Category -> CategoryScreen(route.section, route.name, onBack = navigator::pop) {
            navigator.push(Route.Preview(it.id, null))
        }
        is Route.Preview -> PrayerPreviewScreen(
            store,
            route.prayerID,
            route.highlight,
            onBack = navigator::pop,
            onAdded = navigator::popToLibrary,
            onOpenExisting = { navigator.openInLibrary(it.id) },
        )
        is Route.Contact -> ContactScreen(route.purpose, onBack = navigator::pop)
    }
}
