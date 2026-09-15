# native

ベンチマークの**基準**です。検索画面を SwiftUI / Jetpack Compose だけで書き、同じアプリの中で表示します。
他の 3 方式との差が「埋め込みのコスト」になります。

```
native/
├── ios-host/
│   ├── project.yml          # XcodeGen
│   ├── HostApp/             # ホスト画面（検索ワード入力 + 受信結果）
│   └── RepoSearchKit/       # 検索画面（ローカル Swift Package）
└── android-host/
    ├── app/                 # ホスト画面（MainActivity）と検索画面の Activity
    └── reposearchkit/       # 検索画面（Android ライブラリモジュール）
```

検索画面を別パッケージ / 別モジュールに分けているのは、他の方式が埋め込み画面を
xcframework / AAR としてホストの外から持ち込むのと、構成を揃えるためです。
ホスト側のコードは他の方式とほぼ同じで、`RepoSearchBridge` という同じ形の API で結果を受け取ります。

## 他の方式との違い

| | native | kmp / flutter / expo |
| --- | --- | --- |
| ホスト ⇄ 画面の通信 | 同じプロセス内の Swift / Kotlin の値をそのまま渡す | メッセージチャンネル（シリアライズを伴う） |
| 画面のランタイム | なし（UIKit / Android View の上で直接動く） | Compose ランタイム / Flutter エンジン / React Native（Hermes） |
| HTTP | `URLSession` / `HttpURLConnection` | Ktor / `package:http` / `fetch` |

## ビルドと実行

### iOS

```bash
cd native/ios-host
xcodegen generate
open HostApp.xcodeproj
```

テスト（28 件）:

```bash
xcodebuild test -project HostApp.xcodeproj -scheme HostApp \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Android

```bash
cd native/android-host
./gradlew installDebug
./gradlew testDebugUnitTest   # 28 件
```

## 計測用ビルド

API の向き先はビルド時に差し替えます。何も指定しなければ本物の GitHub API を使います。

```bash
# iOS（シミュレータ向け Release）
xcodebuild build -project HostApp.xcodeproj -scheme HostApp -configuration Release \
  -sdk iphonesimulator BENCH_API_BASE_URL=http://127.0.0.1:8787

# Android（R8 有効の Release。デバッグ鍵で署名）
./gradlew assembleRelease -PbenchApiBaseUrl=http://10.0.2.2:8787
```
