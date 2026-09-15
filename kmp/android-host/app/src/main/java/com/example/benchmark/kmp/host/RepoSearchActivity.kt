package com.example.benchmark.kmp.host

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.example.benchmark.kmp.reposearchkit.RepoSearchBridge
import com.example.benchmark.kmp.reposearchkit.RepoSearchCommand
import com.example.benchmark.kmp.reposearchkit.RepoSearchEvent
import com.example.benchmark.kmp.reposearchkit.RepoSearchScreen

/**
 * Hosts the search screen, with a row of keywords above it that the host app
 * can push into the open screen.
 */
class RepoSearchActivity : ComponentActivity() {
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

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    val keyword = intent.getStringExtra(EXTRA_KEYWORD) ?: DEFAULT_KEYWORD

    setContent {
      MaterialTheme {
        Column(modifier = Modifier.fillMaxSize().safeDrawingPadding()) {
          // The keyword is fixed once the screen exists, so changing it from
          // here goes over the channel instead.
          Text(
            stringResource(R.string.send_to_embedded),
            modifier = Modifier.padding(start = 16.dp, top = 12.dp, end = 16.dp),
          )
          Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(horizontal = 16.dp),
          ) {
            PRESET_KEYWORDS.forEach { preset ->
              OutlinedButton(
                onClick = {
                  BenchMarker.mark("commandSent")
                  bridge.send(RepoSearchCommand.SetKeyword(preset))
                }
              ) {
                Text(preset)
              }
            }
          }
          RepoSearchScreen(
            keyword = keyword,
            apiBaseUrl = AppConfig.apiBaseUrl,
            onClose = { finish() },
            modifier = Modifier.weight(1f),
          )
        }
      }
    }

    bridge.start()
  }

  override fun onDestroy() {
    bridge.stop()
    super.onDestroy()
  }

  companion object {
    /** Keywords the host app can push into the screen while it is open. */
    private val PRESET_KEYWORDS = listOf("expo", "swift", "kotlin")

    const val EXTRA_KEYWORD = "keyword"
    const val DEFAULT_KEYWORD = "expo"

    fun createIntent(context: Context, keyword: String): Intent =
      Intent(context, RepoSearchActivity::class.java).putExtra(EXTRA_KEYWORD, keyword)
  }
}
