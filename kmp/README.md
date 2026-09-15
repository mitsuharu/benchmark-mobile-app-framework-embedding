# kmp

Kotlin Multiplatform + Compose Multiplatform 版です。検索画面を Kotlin / Compose の 1 つのソースで書き、
iOS には XCFramework、Android には AAR として、既存のネイティブアプリへ組み込みます。

```
kmp/
├── shared/          # 検索画面のライブラリ（Gradle プロジェクト。artifact id: reposearchkit）
│   └── src/
│       ├── commonMain/   # 画面（Compose）、API クライアント（Ktor）、チャンネル、状態
│       ├── androidMain/  # マーカーの出力先（logcat）
│       ├── iosMain/      # マーカーの出力先（unified logging）、UIViewController の入口
│       └── commonTest/   # JVM と iOS シミュレータの両方で走るテスト
├── ios-host/        # SwiftUI ホスト（XcodeGen）。RepoSearchKit.xcframework をリンク
└── android-host/    # Compose ホスト。local-repo/ の AAR を依存に持つ
```

## 組み込み方

| | iOS | Android |
| --- | --- | --- |
| 成果物 | `RepoSearchKit.xcframework`（static） | `com.example.benchmark.kmp:reposearchkit:1.0.0`（`android-host/local-repo/` に publish） |
| 画面の入口 | `RepoSearchViewControllerKt.RepoSearchViewController(keyword:apiBaseUrl:onClose:)` が返す `UIViewController`（`ComposeUIViewController`） | `@Composable RepoSearchScreen(keyword, onClose, apiBaseUrl)` |
| 結果の受け取り | `RepoSearchBridge` / `RepoSearchListener`（Kotlin の interface が Objective-C のプロトコルとして見える） | 同じ `RepoSearchBridge` |
| HTTP | Ktor + Darwin エンジン（NSURLSession） | Ktor + OkHttp エンジン |

- Android では Compose Multiplatform は Jetpack Compose そのものなので、ホストと同じ Compose ランタイムの上で画面が動きます。
  埋め込みのコストが最も小さくなる構成です。
- iOS では Compose のランタイムと Skia（Skiko）が XCFramework に入り、Compose が自前で描画します。
  XCFramework は static にしているため、ホストに静的リンクされ、起動時の dyld の読み込みは増えません。
- ホスト ⇄ 画面は同じプロセスの Kotlin オブジェクトとして渡るので、React Native / Flutter のようなシリアライズはありません。
  iOS では Kotlin/Native が生成する Objective-C のインターフェース越しに Swift から触ります。
- Compose Multiplatform は Info.plist に `CADisableMinimumFrameDurationOnPhone` が無いと起動時に止まるので、
  iOS ホストの `project.yml` で指定しています。

## ビルドと実行

### ライブラリ

```bash
cd kmp/shared
./gradlew testAndroidHostTest iosSimulatorArm64Test   # commonTest を JVM と iOS シミュレータで
./gradlew assembleRepoSearchKitReleaseXCFramework     # build/XCFrameworks/release/RepoSearchKit.xcframework
./gradlew publishToHostApp                            # ../android-host/local-repo に AAR を publish
```

初回は Kotlin/Native のツールチェーン（LLVM など、1GB 前後）を `~/.konan` にダウンロードします。

### iOS

```bash
cd kmp/ios-host
./scripts/generate.sh          # release の XCFramework を使う（debug: ./scripts/generate.sh debug）
xcodebuild test -project HostApp.xcodeproj -scheme HostApp \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Android

```bash
cd kmp/android-host
./gradlew testDebugUnitTest
./gradlew installDebug
```

> ライブラリを作り直したら、同じバージョンのままでは Gradle が古い AAR の展開結果をキャッシュから使うことがあります
> （sample-expo-brownfield の README 6-4 と同じ問題）。`version` を上げるか、`~/.gradle/caches` の該当部分を消してください。

## 計測用ビルド

```bash
# iOS（シミュレータ向け Release）
xcodebuild build -project HostApp.xcodeproj -scheme HostApp -configuration Release \
  -sdk iphonesimulator BENCH_API_BASE_URL=http://127.0.0.1:8787

# Android（R8 有効の Release。デバッグ鍵で署名）
./gradlew assembleRelease -PbenchApiBaseUrl=http://10.0.2.2:8787
```
