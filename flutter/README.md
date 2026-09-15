# flutter

Flutter の add-to-app 版です。検索画面を Flutter モジュールとして書き、
iOS には xcframework、Android には AAR として既存のネイティブアプリへ組み込みます。

```
flutter/
├── .fvmrc           # Flutter のバージョン（FVM）
├── flutter_module/  # 検索画面（flutter create --template module）
│   ├── lib/
│   │   ├── main.dart                 # エンジンが起動時に実行するエントリポイント
│   │   └── src/
│   │       ├── github_client.dart    # API クライアント（package:http）
│   │       ├── host_channel.dart     # ホストとの MethodChannel
│   │       └── repo_search_screen.dart
│   └── test/
├── ios-host/        # SwiftUI ホスト（XcodeGen）。Flutter/Release/*.xcframework を埋め込む
└── android-host/    # Compose ホスト。local-repo/ の AAR を依存に持つ
```

## Flutter の環境（FVM）

Flutter のバージョンは [FVM](https://fvm.app/) で固定しています。

```bash
brew install fvm
cd flutter
fvm install          # .fvmrc のバージョン（3.47.4）を入れる
fvm flutter --version
```

`fvm use` がこのディレクトリに `.fvm/` を作り、IDE はそこを Flutter SDK として参照します（`.fvm/` は git 管理外）。
CI は FVM を使わず、`.fvmrc` に書かれたバージョンの Flutter を直接 clone します。

## 組み込み方

| | iOS | Android |
| --- | --- | --- |
| 成果物 | `flutter build ios-framework` の `App` / `Flutter` / `FlutterPluginRegistrant` の xcframework（dynamic） | `flutter build aar` の `flutter_debug` / `flutter_release`（Maven リポジトリ） |
| エンジン | `FlutterEngine` を `HostApp.init` で起動して使い回す | `FlutterEngine` を `Application.onCreate` で起動し、`FlutterEngineCache` に置いて使い回す |
| 画面 | `FlutterViewController(engine:)` | `FlutterFragment.withCachedEngine(...)` |
| 通信 | MethodChannel `repo_search` | 同じ |

エンジンをアプリ起動時に作って使い回すのは、Flutter の公式ドキュメントが推奨する構成です。
エンジン（と Dart の VM）の起動がコールドスタートに含まれる代わりに、画面を開くときは速くなります。

エンジンの中の Dart のアプリは画面を閉じても生き続けるので、画面を開くたびにホストが `start`
（キーワードと API の向き先）を送り、Dart 側は新しいキーで画面を作り直します。
React Native が画面ごとに新しいルートビューを `initialProps` 付きで作るのに相当します。

### チャンネルの内容

| 向き | メソッド | 引数 |
| --- | --- | --- |
| ホスト → Dart | `start` | `keyword`, `apiBaseUrl` |
| ホスト → Dart | `setKeyword` | `keyword` |
| Dart → ホスト | `searchSucceeded` | `keyword`, `repositories[id, fullName, stars, language]` |
| Dart → ホスト | `searchFailed` | `keyword`, `message` |
| Dart → ホスト | `close` | — |
| Dart → ホスト | `mark` | `name`, `epochMs`（計測マーカー。ホストがログに書く） |

Flutter はネイティブのコードを同梱しないので、型付きの `RepoSearchBridge` はホストアプリ側
（iOS: `FlutterRepoSearch.swift`、Android: `FlutterRepoSearch.kt`）にあります。

## ビルドと実行

### モジュール

```bash
cd flutter/flutter_module
fvm flutter test
fvm flutter analyze
```

### iOS

```bash
cd flutter/flutter_module
fvm flutter build ios-framework --no-profile --output=../ios-host/Flutter   # Flutter/Debug と Flutter/Release
cd ../ios-host
./scripts/generate.sh Debug     # シミュレータで動かす場合（Release は実機向け）
xcodebuild test -project HostApp.xcodeproj -scheme HostApp \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

`project.yml` は `Flutter/${FLUTTER_BUILD_MODE}/` の xcframework を参照するので、
`xcodegen generate` ではなく `scripts/generate.sh [Debug|Release]` で生成します。

> **iOS シミュレータでは Flutter の Release は動きません。**
> Release / Profile の `App.xcframework` は、デバイス用スライスにだけ AOT スナップショット
> （`_kDartSnapshotData` など、約 4MB）を持ち、シミュレータ用スライスは Dart のコードを含まない 84KB の空のフレームワークです。
> リンクもビルドも通りますが、画面は表示されません。シミュレータで動かすには Debug（JIT、`kernel_blob.bin` を同梱）を埋め込みます。
> そのため、このベンチマークの **Flutter の iOS の数値だけは Debug（JIT）** です（ホストアプリ自体は Release 構成）。

### Android

```bash
cd flutter/flutter_module
fvm flutter build aar --no-profile -o "$(cd .. && pwd)/android-host/local-repo"
cd ../android-host
./gradlew testDebugUnitTest
./gradlew installRelease
```

## 計測用ビルド

```bash
# iOS（シミュレータ向け Release）
xcodebuild build -project HostApp.xcodeproj -scheme HostApp -configuration Release \
  -sdk iphonesimulator BENCH_API_BASE_URL=http://127.0.0.1:8787

# Android（R8 有効の Release。デバッグ鍵で署名）
./gradlew assembleRelease -PbenchApiBaseUrl=http://10.0.2.2:8787
```
