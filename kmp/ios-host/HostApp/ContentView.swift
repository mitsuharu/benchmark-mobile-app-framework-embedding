import RepoSearchKit
import SwiftUI

/// Receives search results through `RepoSearchListener`, a Kotlin interface
/// that Swift sees as an Objective-C protocol — hence `NSObject`.
final class SearchResultsStore: NSObject, ObservableObject, RepoSearchListener {
  @Published var keyword: String = "expo"
  @Published private(set) var lastKeyword: String?
  @Published private(set) var repositories: [SearchedRepository] = []
  @Published private(set) var errorMessage: String?

  /// The keyword handed to the search screen when it is created.
  var effectiveKeyword: String {
    let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "expo" : trimmed
  }

  private lazy var bridge = RepoSearchBridge(listener: self, onEvent: nil)

  func startListening() {
    bridge.start()
  }

  func stopListening() {
    bridge.stop()
  }

  func onRepoSearchEvent(event: RepoSearchEvent) {
    // Kotlin's sealed interface arrives as a class hierarchy.
    if let succeeded = event as? RepoSearchEventSucceeded {
      BenchMarker.mark("resultsReceived")
      lastKeyword = succeeded.keyword
      repositories = succeeded.repositories
      errorMessage = nil
    } else if let failed = event as? RepoSearchEventFailed {
      lastKeyword = failed.keyword
      repositories = []
      errorMessage = failed.message
    }
  }
}

extension SearchedRepository: Identifiable {}

/// Where the navigation stack can go.
enum Route: Hashable {
  case repoSearch(keyword: String)
}

/// The native part of the app. The keyword is typed here and passed into the
/// Compose Multiplatform screen, and the results come back through
/// `RepoSearchBridge`.
struct ContentView: View {
  @StateObject private var store = SearchResultsStore()
  @State private var path: [Route] = []

  var body: some View {
    NavigationStack(path: $path) {
      List {
        Section("検索ワード") {
          TextField("keyword", text: $store.keyword)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("keywordField")
        }

        Section("埋め込み画面") {
          // A button rather than a NavigationLink, so the tap itself can be
          // marked: the benchmark measures from here to the screen's first frame.
          Button {
            BenchMarker.mark("embedOpenTapped")
            path.append(.repoSearch(keyword: store.effectiveKeyword))
          } label: {
            Label("Compose Multiplatform の画面を開く", systemImage: "magnifyingglass")
          }
          .accessibilityIdentifier("openEmbedded")
        }

        Section("埋め込み画面から受け取った結果") {
          if let errorMessage = store.errorMessage {
            Text(errorMessage).foregroundStyle(.red)
          } else if let lastKeyword = store.lastKeyword {
            LabeledContent("keyword", value: lastKeyword)
            LabeledContent("件数", value: "\(store.repositories.count)")
            ForEach(store.repositories.prefix(3)) { repository in
              LabeledContent(repository.fullName, value: "★ \(repository.stars)")
            }
          } else {
            Text("まだ結果を受け取っていません").foregroundStyle(.secondary)
          }
        }
      }
      .navigationTitle("Host App")
      .navigationDestination(for: Route.self) { route in
        switch route {
        case .repoSearch(let keyword):
          RepoSearchScreen(keyword: keyword)
        }
      }
      .onAppear { BenchMarker.markLaunch() }
    }
    // Attached to the NavigationStack, not the List: pushing a screen makes the
    // List disappear, and the search screen reports its results while it is on top.
    .onAppear { store.startListening() }
    .onDisappear { store.stopListening() }
  }
}

/// Keywords the host app can push into the screen while it is open.
private let presetKeywords = ["expo", "swift", "kotlin"]

private struct RepoSearchScreen: View {
  let keyword: String

  @Environment(\.dismiss) private var dismiss
  private let bridge = RepoSearchBridge(listener: nil, onEvent: nil)

  var body: some View {
    RepoSearchComposeView(keyword: keyword) { dismiss() }
      .ignoresSafeArea(edges: .bottom)
      .navigationTitle("Repo Search (KMP)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        // The keyword is fixed once this screen exists, so changing it from
        // here goes over the channel instead.
        Menu("キーワード") {
          Section("ネイティブ → 埋め込み画面にメッセージ送信") {
            ForEach(presetKeywords, id: \.self) { preset in
              Button(preset) {
                BenchMarker.mark("commandSent")
                bridge.send(command: RepoSearchCommandSetKeyword(keyword: preset))
              }
            }
          }
        }
      }
  }
}

/// Hosts the Compose Multiplatform screen, which Kotlin vends as a view controller.
private struct RepoSearchComposeView: UIViewControllerRepresentable {
  let keyword: String
  let onClose: () -> Void

  func makeUIViewController(context: Context) -> UIViewController {
    RepoSearchViewControllerKt.RepoSearchViewController(
      keyword: keyword,
      apiBaseUrl: AppConfig.apiBaseURL.absoluteString,
      onClose: onClose
    )
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

#Preview {
  ContentView()
}
