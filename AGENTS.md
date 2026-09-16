# AGENTS.md

モバイルアプリのフレームワーク埋め込み（brownfield）を比較するベンチマークのリポジトリです。
同じ「GitHub リポジトリ検索」画面を 5 つの方式で iOS / Android のネイティブホストアプリへ組み込み、
起動時間・応答速度・メモリを同じ手順で測ります。

作業前に `README.md` と、変更するディレクトリの README を読んでください。

## ディレクトリ

| パス | 内容 |
| --- | --- |
| `native/` | 基準。SwiftUI / Jetpack Compose で書いた検索画面を同じアプリ内で表示する |
| `kmp/` | Kotlin Multiplatform + Compose Multiplatform の画面を XCFramework / AAR で組み込む |
| `kmp-native-ui/` | Kotlin Multiplatform でロジックだけを共有し、画面は SwiftUI / Jetpack Compose で書く |
| `flutter/` | Flutter の add-to-app。xcframework / AAR で組み込む |
| `expo/` | expo-brownfield。[sample-expo-brownfield](https://github.com/mitsuharu/sample-expo-brownfield) を複製したもの |
| `bench/` | モックサーバ、agent-device による計測ランナー、結果の集計 |

各フレームワークのディレクトリは `ios-host/`（SwiftUI）と `android-host/`（Compose）を持ちます。
ホストアプリは「既存のネイティブアプリ」に相当し、どのフレームワークでも同じ画面構成にします。

## 機能の仕様（全実装で揃える）

比較の前提になるので、ここを変えるときは全実装を同時に直します。

- **ホスト画面**: 検索ワードの入力欄、埋め込み画面を開くボタン、埋め込み画面から受け取った結果
  （キーワード・件数・上位 3 件）
- **埋め込み画面**: 受け取ったキーワードで GitHub Search API
  （`/search/repositories?q=<keyword>&sort=stars&order=desc&per_page=20`）を叩いて一覧表示する。
  「リポジトリを検索」「ネイティブに戻る」の 2 ボタン
- **ネイティブ → 埋め込み**: 画面生成時のキーワード（RN の `initialProps` 相当）と、
  表示中の画面へのキーワード差し替えコマンド `setKeyword`
- **埋め込み → ネイティブ**: `searchSucceeded`（`keyword`, `repositories[id, fullName, stars, language]`）と
  `searchFailed`（`keyword`, `message`）
- **API のベース URL** は差し替えられるようにする。既定は `https://api.github.com`、
  計測時は `bench/mock-server`（iOS / Android とも `http://127.0.0.1:8787`。Android は `adb reverse` でエミュレータ内に転送する）

### 画面の文言と識別子

計測ランナーは agent-device でこれらを探して操作するので、全実装で同じにします。

| 要素 | 文言 | 識別子（iOS: accessibilityIdentifier / Android: resource-id） |
| --- | --- | --- |
| 検索ワード入力欄 | placeholder `keyword` | `keywordField` |
| 埋め込み画面を開くボタン | 実装ごとに自由 | `openEmbedded` |
| 検索ボタン | `リポジトリを検索` | — |
| 戻るボタン | `ネイティブに戻る` | — |
| 受け取った件数 | `件数` / `20` | — |
| キーワード差し替え | iOS はツールバーの `キーワード` メニュー、Android は画面上部のボタン。候補は `expo` / `swift` / `kotlin` | — |

Android の Compose では `Modifier.testTag` を resource-id として公開するため、
ルートに `semantics { testTagsAsResourceId = true }` を付けます。

## 計測マーカー

時間の計測はアプリ内のマーカーで行います。agent-device の操作にかかる時間を含めないためです。
すべての実装が次の形式で 1 行ずつ出力します。

```text
BENCH|<name>|<epochMs>
```

- iOS: `Logger(subsystem: "bench", category: "marker")` に `privacy: .public` で出す
  （既定の `private` だとリリースビルドで `<private>` に伏せられる）
- Android: `Log.i("Bench", ...)`
- 埋め込み側（JS / Dart / Kotlin）の時刻は埋め込み側で取り、チャンネル経由でホストに渡してホストが出力する。
  どちらも壁時計のミリ秒なので同じプロセス内で比較できる

| name | 発行元 | タイミング |
| --- | --- | --- |
| `processStart` | ホスト | プロセスの開始時刻。iOS は `sysctl` の `p_starttime`、Android は `Process.getStartUptimeMillis()` を壁時計に換算。`hostFirstFrame` と同時に出力する |
| `hostFirstFrame` | ホスト | ホスト画面の最初のフレームの後 |
| `embedOpenTapped` | ホスト | 埋め込み画面を開くボタンのタップ時 |
| `embedFirstFrame` | 埋め込み | 埋め込み画面の最初のフレームの後 |
| `searchTapped` | 埋め込み | 「リポジトリを検索」のタップ時 |
| `searchRendered` | 埋め込み | 検索結果を描画したフレームの後 |
| `resultsReceived` | ホスト | ホストが `searchSucceeded` を受け取った時 |
| `commandSent` | ホスト | `setKeyword` を送った時 |
| `keywordApplied` | 埋め込み | 差し替えたキーワードを描画したフレームの後 |

「フレームの後」は各フレームワークで最も近い手段を使います
（Compose: `withFrameNanos`、Flutter: `addPostFrameCallback`、SwiftUI: `onAppear` の次のメインループ、
React Native: コミット後の `useEffect`）。

埋め込みのランタイム（React Native / Flutter エンジン）は、どちらのプラットフォームでも
**アプリ起動時に初期化**します（公式の推奨どおり）。そのぶんはコールドスタートに含まれます。

## コーディング規約

### 共通

- コードコメントとコミットメッセージは英語、UI の文言とドキュメントは日本語。
- インデントは 2 スペース（Swift / Kotlin / TypeScript / Dart / YAML）。
- コメントには「何を」より「なぜ」を書く。実際に踏んだ落とし穴は README かコメントに残す。
- 生成物はコミットしない（`.xcodeproj`、`expo prebuild` の出力、xcframework / AAR、`local-repo/`、ビルド出力）。
- 依存を追加するときはバージョンを固定する。

### Swift

- swift-format（Xcode 同梱）。ルートの [`.swift-format`](.swift-format) を使い、
  `./scripts/swift-format.sh`（`--fix` で自動修正）で検査する。
- Xcode プロジェクトは XcodeGen の `project.yml` から生成する。`.xcodeproj` はコミットしない。
- iOS 16.4 以上、SwiftUI。テストは XCTest。

### Kotlin

- Kotlin 公式スタイルに 2 スペースのインデント。UI は Jetpack Compose / Compose Multiplatform。
- JDK 17 でビルドする。
- ホストアプリのテストは JUnit + Robolectric。

### TypeScript / JavaScript

- Biome（シングルクォート、セミコロンなし）。`npm run lint` で検査する。

### Dart

- `dart format` と `flutter analyze`（`flutter_lints`）。Flutter のバージョンは FVM で固定する。

## バージョンの固定

| ファイル | 用途 |
| --- | --- |
| `.node-version` | Node.js。`actions/setup-node` の `node-version-file` も読む |
| `.xcode-version` | Xcode。CI ではランナー同梱の `xcodes` で選択する |
| `flutter/.fvmrc` | Flutter SDK（FVM） |
| `*/gradle/wrapper/gradle-wrapper.properties` | Gradle |

## CI

- フレームワークごとにワークフローを分け、`paths` で対象ディレクトリの変更時だけ走らせる。
- アクションはコミット SHA で固定し、行末にバージョンをコメントで書く。
- npm は [Aikido Safe Chain](.github/actions/setup-safe-chain) を通し、`.npmrc` の `min-release-age=3` で
  公開直後のバージョンを避ける。

## 自動操作

シミュレータ / エミュレータの操作は、すべて [agent-device](https://github.com/callstack/agent-device) で行います
（`bench/` の devDependency）。`simctl` / `adb` はビルド成果物の確認やログの読み取りなど、
UI 操作以外にとどめます。

## Git / Pull Request

- ブランチは `feature/<topic>`。`main` へ直接コミットしない。
- コミットは目的・機能単位。メッセージは英語の命令形で、何のための変更かが分かるように書く。
- PR には概要と確認方法を書く。画面に変化がある場合は `gh pr create --attach` でスクリーンショットを添付する。
- CI が通り、セルフレビューで問題がないことを確認してから `gh pr merge --merge` でマージする。
