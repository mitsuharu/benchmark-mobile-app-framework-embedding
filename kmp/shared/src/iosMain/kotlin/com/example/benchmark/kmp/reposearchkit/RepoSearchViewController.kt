package com.example.benchmark.kmp.reposearchkit

import androidx.compose.ui.window.ComposeUIViewController
import platform.UIKit.UIViewController

/**
 * The search screen as a view controller, for the Swift host app. From Swift:
 *
 * ```swift
 * RepoSearchViewControllerKt.RepoSearchViewController(
 *   keyword: "expo", apiBaseUrl: "https://api.github.com", onClose: { ... })
 * ```
 */
fun RepoSearchViewController(
  keyword: String,
  apiBaseUrl: String,
  onClose: () -> Unit,
): UIViewController = ComposeUIViewController {
  RepoSearchScreen(keyword = keyword, onClose = onClose, apiBaseUrl = apiBaseUrl)
}
