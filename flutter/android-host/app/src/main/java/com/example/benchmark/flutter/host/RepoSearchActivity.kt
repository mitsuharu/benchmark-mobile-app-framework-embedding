package com.example.benchmark.flutter.host

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.android.FlutterFragment

/**
 * Hosts the Flutter screen in a [FlutterFragment] attached to the engine that
 * [HostApplication] started, with a row of keywords above it that the host
 * app can push into the open screen.
 */
class RepoSearchActivity : FragmentActivity() {
  /** Receives the results through the lambda form of the bridge. */
  private val bridge =
    RepoSearchBridge(
      onEvent = { event ->
        val text =
          when (event) {
            is RepoSearchEvent.Succeeded -> "${event.keyword}: ${event.repositories.size} 件受信"
            is RepoSearchEvent.Failed -> "${event.keyword}: 取得失敗"
          }
        Toast.makeText(this, text, Toast.LENGTH_SHORT).show()
      }
    )

  private val runtime = FlutterRepoSearch.shared

  private val flutterFragment: FlutterFragment?
    get() = supportFragmentManager.findFragmentByTag(TAG_FLUTTER) as FlutterFragment?

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    val keyword = intent.getStringExtra(EXTRA_KEYWORD) ?: DEFAULT_KEYWORD
    runtime.onClose = { finish() }

    val container = FrameLayout(this).apply { id = R.id.flutter_container }
    setContentView(withKeywordBar(container))

    if (savedInstanceState == null) {
      runtime.prepareScreen(keyword, AppConfig.apiBaseUrl)
      supportFragmentManager
        .beginTransaction()
        .add(
          R.id.flutter_container,
          FlutterFragment.withCachedEngine(FlutterRepoSearch.ENGINE_ID)
            .shouldAutomaticallyHandleOnBackPressed(true)
            .build<FlutterFragment>(),
          TAG_FLUTTER,
        )
        .commit()
    }

    bridge.start()
  }

  override fun onDestroy() {
    bridge.stop()
    runtime.onClose = null
    super.onDestroy()
  }

  // FlutterFragment relies on its activity to forward these.
  override fun onPostResume() {
    super.onPostResume()
    flutterFragment?.onPostResume()
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    flutterFragment?.onNewIntent(intent)
  }

  override fun onUserLeaveHint() {
    super.onUserLeaveHint()
    flutterFragment?.onUserLeaveHint()
  }

  override fun onTrimMemory(level: Int) {
    super.onTrimMemory(level)
    flutterFragment?.onTrimMemory(level)
  }

  /**
   * Puts a row of keywords above the Flutter view.
   *
   * The keyword is fixed once the screen exists, so changing it from here goes
   * over the channel instead.
   */
  private fun withKeywordBar(content: android.view.View): ViewGroup {
    val caption =
      TextView(this).apply {
        text = getString(R.string.send_to_embedded)
        setPadding(32, 24, 32, 0)
      }

    val bar =
      LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        PRESET_KEYWORDS.forEach { preset ->
          addView(
            Button(this@RepoSearchActivity).apply {
              text = preset
              setOnClickListener {
                BenchMarker.mark("commandSent")
                bridge.send(RepoSearchCommand.SetKeyword(preset))
              }
            }
          )
        }
      }

    return LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL
      // The activity is edge to edge, so the bar would sit under the status bar.
      fitsSystemWindows = true
      addView(
        caption,
        LinearLayout.LayoutParams(
          LinearLayout.LayoutParams.MATCH_PARENT,
          LinearLayout.LayoutParams.WRAP_CONTENT,
        ),
      )
      addView(
        bar,
        LinearLayout.LayoutParams(
          LinearLayout.LayoutParams.MATCH_PARENT,
          LinearLayout.LayoutParams.WRAP_CONTENT,
        ),
      )
      addView(content, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
    }
  }

  companion object {
    /** Keywords the host app can push into the screen while it is open. */
    private val PRESET_KEYWORDS = listOf("expo", "swift", "kotlin")

    private const val TAG_FLUTTER = "flutter"

    const val EXTRA_KEYWORD = "keyword"
    const val DEFAULT_KEYWORD = "expo"

    fun createIntent(context: Context, keyword: String): Intent =
      Intent(context, RepoSearchActivity::class.java).putExtra(EXTRA_KEYWORD, keyword)
  }
}
