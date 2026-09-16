import Combine
import RepoSearchKit
import SwiftUI

/// One repository as the screen draws it.
///
/// The shared Kotlin types reach Swift through the Objective-C interop that
/// Kotlin/Native generates, which renames `description` (UIKit already has
/// one) and knows nothing about `Identifiable`. Mapping them here keeps the
/// interop in one place, so the screen below stays the same SwiftUI as the
/// native baseline's.
struct Repository: Identifiable, Equatable {
  let id: Int64
  let fullName: String
  let description: String?
  let stars: Int
  let language: String?
}

/// The shared model's state, republished for SwiftUI.
///
/// The Kotlin model calls back on the main thread, the same thread SwiftUI
/// reads these from.
final class RepoSearchViewModel: ObservableObject {
  @Published private(set) var keyword: String
  @Published private(set) var repositories: [Repository] = []
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?

  private let shared: RepoSearchKit.RepoSearchModel

  init(keyword: String, apiBaseURL: URL) {
    self.keyword = keyword
    shared = RepoSearchKit.RepoSearchModel(keyword: keyword, apiBaseUrl: apiBaseURL.absoluteString)
    shared.onStateChange = { [weak self] state in
      self?.apply(state)
    }
  }

  func search() {
    shared.search()
  }

  /// Stops following the host's commands. Called when the screen goes away.
  func dispose() {
    shared.onStateChange = nil
    shared.dispose()
  }

  private func apply(_ state: RepoSearchState) {
    keyword = state.keyword
    isLoading = state.isLoading
    errorMessage = state.errorMessage
    repositories = state.repositories.map { repository in
      Repository(
        id: repository.id,
        fullName: repository.fullName,
        description: repository.description_,
        stars: Int(repository.stars),
        language: repository.language
      )
    }
  }
}
