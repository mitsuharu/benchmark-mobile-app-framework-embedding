import SwiftUI

/// State and behaviour of the search screen.
@MainActor
final class RepoSearchModel: ObservableObject {
  @Published private(set) var keyword: String
  @Published private(set) var repositories: [Repository] = []
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?

  private let client: GitHubClient
  private let channel: RepoSearchChannel
  private var commandListenerID: UUID?

  init(keyword: String, client: GitHubClient, channel: RepoSearchChannel = .shared) {
    self.keyword = keyword
    self.client = client
    self.channel = channel
    // The keyword passed in only arrives while the screen is being created,
    // so replacing it on an open screen comes over the channel.
    commandListenerID = channel.addCommandListener { [weak self] command in
      switch command {
      case .setKeyword(let next):
        self?.keyword = next
        self?.repositories = []
        self?.errorMessage = nil
      }
    }
  }

  deinit {
    if let commandListenerID {
      channel.removeCommandListener(commandListenerID)
    }
  }

  func search() async {
    isLoading = true
    errorMessage = nil
    let keyword = keyword
    do {
      let results = try await client.searchRepositories(keyword: keyword)
      repositories = results
      // Hand the results back to the host app.
      channel.post(.succeeded(keyword: keyword, repositories: results.map(SearchedRepository.init)))
    } catch {
      let message = error.localizedDescription
      repositories = []
      errorMessage = message
      channel.post(.failed(keyword: keyword, message: message))
    }
    isLoading = false
  }
}

/// The screen every implementation embeds: searches GitHub for the keyword the
/// host app handed over and lists the repositories.
public struct RepoSearchView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var model: RepoSearchModel

  public init(keyword: String, apiBaseURL: URL = GitHubClient.defaultBaseURL) {
    _model = StateObject(
      wrappedValue: RepoSearchModel(keyword: keyword, client: GitHubClient(baseURL: apiBaseURL))
    )
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 4) {
        Text("GitHub Repositories")
          .font(.system(size: 24, weight: .bold))
        Text("keyword: \(model.keyword)")
          .font(.system(size: 14))
          .foregroundStyle(Palette.subtitle)
      }
      .padding(.horizontal, 20)
      .padding(.top, 24)

      HStack(spacing: 8) {
        ActionButton(
          label: model.isLoading ? "検索中..." : "リポジトリを検索",
          isDisabled: model.isLoading
        ) {
          BenchMarker.mark("searchTapped")
          Task { await model.search() }
        }
        ActionButton(label: "ネイティブに戻る", variant: .secondary) {
          dismiss()
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)

      if let errorMessage = model.errorMessage {
        Text(errorMessage)
          .foregroundStyle(Palette.error)
          .padding(.horizontal, 20)
          .padding(.bottom, 8)
      }

      if model.isLoading && model.repositories.isEmpty {
        ProgressView()
          .controlSize(.large)
          .frame(maxWidth: .infinity)
          .padding(.top, 32)
        Spacer()
      } else if model.repositories.isEmpty {
        if model.errorMessage == nil {
          Text("ボタンを押すと検索結果が表示されます。")
            .foregroundStyle(Palette.placeholder)
            .frame(maxWidth: .infinity)
            .padding(.top, 32)
        }
        Spacer()
      } else {
        List(model.repositories) { repository in
          RepositoryRow(repository: repository)
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
        }
        .listStyle(.plain)
      }
    }
    .background(Color.white)
    .onAppear { BenchMarker.markAfterFrame("embedFirstFrame") }
    .onChange(of: model.repositories) { repositories in
      if !repositories.isEmpty {
        BenchMarker.markAfterFrame("searchRendered")
      }
    }
    .onChange(of: model.keyword) { _ in
      BenchMarker.markAfterFrame("keywordApplied")
    }
  }
}

private enum Palette {
  static let primary = Color(red: 0x11 / 255, green: 0x18 / 255, blue: 0x27 / 255)
  static let secondary = Color(red: 0xE5 / 255, green: 0xE7 / 255, blue: 0xEB / 255)
  static let subtitle = Color(red: 0x6B / 255, green: 0x72 / 255, blue: 0x80 / 255)
  static let description = Color(red: 0x4B / 255, green: 0x55 / 255, blue: 0x63 / 255)
  static let placeholder = Color(red: 0x9C / 255, green: 0xA3 / 255, blue: 0xAF / 255)
  static let error = Color(red: 0xB9 / 255, green: 0x1C / 255, blue: 0x1C / 255)
}

private struct ActionButton: View {
  enum Variant {
    case primary
    case secondary
  }

  let label: String
  var variant: Variant = .primary
  var isDisabled = false
  let action: () -> Void

  var body: some View {
    let isSecondary = variant == .secondary
    Button(action: action) {
      Text(label)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(isSecondary ? Palette.primary : .white)
        .frame(maxWidth: isSecondary ? nil : .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, isSecondary ? 16 : 0)
        .background(isSecondary ? Palette.secondary : Palette.primary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .opacity(isDisabled ? 0.5 : 1)
  }
}

private struct RepositoryRow: View {
  let repository: Repository

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(repository.fullName)
        .font(.system(size: 16, weight: .semibold))
      if let description = repository.description {
        Text(description)
          .font(.system(size: 13))
          .foregroundStyle(Palette.description)
          .lineLimit(2)
          .padding(.top, 4)
      }
      Text(meta)
        .font(.system(size: 12))
        .foregroundStyle(Palette.subtitle)
        .padding(.top, 6)
    }
  }

  private var meta: String {
    let stars = "★ \(repository.stars.formatted())"
    guard let language = repository.language else { return stars }
    return "\(stars) · \(language)"
  }
}
