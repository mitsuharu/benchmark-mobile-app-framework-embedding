import RepoSearchKit
import SwiftUI

/// Receives search results through `RepoSearchBridgeDelegate`.
final class SearchResultsStore: ObservableObject, RepoSearchBridgeDelegate {
  @Published var keyword: String = "expo"
  @Published private(set) var lastKeyword: String?
  @Published private(set) var repositories: [SearchedRepository] = []
  @Published private(set) var errorMessage: String?

  /// The keyword handed to the search screen when it is created.
  var effectiveKeyword: String {
    let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "expo" : trimmed
  }

  private lazy var bridge = RepoSearchBridge(delegate: self)

  func startListening() {
    bridge.start()
  }

  func stopListening() {
    bridge.stop()
  }

  func repoSearchBridge(_ bridge: RepoSearchBridge, didReceive event: RepoSearchEvent) {
    switch event {
    case .succeeded(let keyword, let repositories):
      BenchMarker.mark("resultsReceived")
      self.lastKeyword = keyword
      self.repositories = repositories
      self.errorMessage = nil
    case .failed(let keyword, let message):
      self.lastKeyword = keyword
      self.repositories = []
      self.errorMessage = message
    }
  }
}

/// Where the navigation stack can go.
enum Route: Hashable {
  case repoSearch(keyword: String)
}

/// The native part of the app. The keyword is typed here and passed into the
/// search screen, and the results come back through `RepoSearchBridge`.
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
            Label("SwiftUI の画面を開く", systemImage: "magnifyingglass")
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

  private let bridge = RepoSearchBridge()

  var body: some View {
    RepoSearchView(keyword: keyword, apiBaseURL: AppConfig.apiBaseURL)
      .navigationTitle("Repo Search (Native)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        // The keyword is fixed once this screen exists, so changing it from
        // here goes over the channel instead.
        Menu("キーワード") {
          Section("ネイティブ → 埋め込み画面にメッセージ送信") {
            ForEach(presetKeywords, id: \.self) { preset in
              Button(preset) {
                BenchMarker.mark("commandSent")
                bridge.send(.setKeyword(preset))
              }
            }
          }
        }
      }
  }
}

#Preview {
  ContentView()
}
