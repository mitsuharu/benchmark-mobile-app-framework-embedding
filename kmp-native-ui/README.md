# kmp-native-ui

Kotlin Multiplatform でロジックだけを共有し、**画面は各プラットフォームにネイティブで書く**版です。
[`kmp/`](../kmp)（Compose Multiplatform で画面ごと共有する）との差分が、そのまま
「UI も共有するか、ロジックだけ共有するか」の比較になります。

```
kmp-native-ui/
├── shared/          # ロジックのライブラリ（Gradle プロジェクト。artifact id: reposearchkit）
│   └── src/
│       ├── commonMain/   # 状態（RepoSearchModel）、API クライアント（Ktor）、チャンネル
│       └── commonTest/   # JVM と iOS シミュレータの両方で走るテスト
├── ios-host/        # SwiftUI ホスト（XcodeGen）。画面も SwiftUI で書く
└── android-host/    # Compose ホスト。画面も Jetpack Compose で書く
```

`shared/` に UI ツールキットは入りません（Compose も Skia も含まない）。
画面のマーカー（`embedFirstFrame` など）も、ネイティブの画面側から出します。

## 組み込み方

| | iOS | Android |
| --- | --- | --- |
| 成果物 | `RepoSearchKit.xcframework`（static） | `com.example.benchmark.kmpnativeui:reposearchkit:1.0.0`（`android-host/local-repo/` に publish） |
| 画面 | ホストアプリの `RepoSearchView`（SwiftUI） | ホストアプリの `RepoSearchScreen`（Jetpack Compose） |
| 共有ロジックの入口 | `RepoSearchModel(keyword:apiBaseUrl:)` | `RepoSearchModel(keyword, apiBaseUrl)` |
| 結果の受け取り | `RepoSearchBridge` / `RepoSearchListener` | 同じ `RepoSearchBridge` |
| HTTP | Ktor + Darwin エンジン（NSURLSession） | Ktor + OkHttp エンジン |

- `RepoSearchModel` の状態は Compose の状態でも Flow でもなく、**値（`RepoSearchState`）と
  コールバック（`onStateChange`）**です。SwiftUI と Compose が同じ形で購読でき、共有側が
  どちらの UI にも寄らないようにするためです。ホスト側で `ObservableObject` / `mutableStateOf` に変換します。
- iOS では Kotlin/Native が生成する Objective-C のインターフェース越しに Swift から触ります。
  Kotlin の `description` は Objective-C と衝突するため Swift からは `description_`、
  `Int32` は `Int` に変換するなど、**変換はホストの ViewModel に閉じ込め**、画面は素の Swift の型だけを見ます。
- Compose を含まないので、`kmp/` で必要だった `CADisableMinimumFrameDurationOnPhone` は不要です。

## ビルドと実行

### ライブラリ

```bash
cd kmp-native-ui/shared
./gradlew testAndroidHostTest iosSimulatorArm64Test   # commonTest を JVM と iOS シミュレータで
./gradlew assembleRepoSearchKitReleaseXCFramework     # build/XCFrameworks/release/RepoSearchKit.xcframework
./gradlew publishToHostApp                            # ../android-host/local-repo に AAR を publish
```

初回は Kotlin/Native のツールチェーン（LLVM など、1GB 前後）を `~/.konan` にダウンロードします。

### iOS

```bash
cd kmp-native-ui/ios-host
./scripts/generate.sh          # release の XCFramework を使う（debug: ./scripts/generate.sh debug）
xcodebuild test -project HostApp.xcodeproj -scheme HostApp \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Android

```bash
cd kmp-native-ui/android-host
./gradlew testDebugUnitTest
./gradlew installDebug
```

> ライブラリを作り直したら、同じバージョンのままでは Gradle が古い AAR の展開結果をキャッシュから使うことがあります。
> `version` を上げるか、`~/.gradle/caches` の該当部分を消してください。

## 計測用ビルド

```bash
# iOS（シミュレータ向け Release）
xcodebuild build -project HostApp.xcodeproj -scheme HostApp -configuration Release \
  -sdk iphonesimulator BENCH_API_BASE_URL=http://127.0.0.1:8787

# Android（R8 有効の Release。デバッグ鍵で署名）
./gradlew assembleRelease -PbenchApiBaseUrl=http://127.0.0.1:8787
```
