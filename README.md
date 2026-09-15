# benchmark-mobile-app-framework-embedding

既存のネイティブアプリ（iOS / Android）に、別のフレームワークで作った画面を埋め込んだときの
起動時間・応答速度・メモリを比較するベンチマークです。

題材は [sample-expo-brownfield](https://github.com/mitsuharu/sample-expo-brownfield) と同じ
「GitHub のリポジトリを検索して一覧表示し、結果をネイティブ側へ返す」画面です。
これをネイティブ（基準）、Kotlin Multiplatform / Compose Multiplatform、Flutter、Expo の 4 方式で実装し、
同じホストアプリ・同じ操作・同じ計測手順で比べます。

## 構成

```
.
├── native/    # 基準。SwiftUI / Jetpack Compose だけで実装
├── kmp/       # Compose Multiplatform の画面を XCFramework / AAR で組み込む
├── flutter/   # Flutter add-to-app
├── expo/      # expo-brownfield（sample-expo-brownfield の複製）
└── bench/     # モックサーバ、agent-device による計測ランナー
```

各ディレクトリの `ios-host/`（SwiftUI）と `android-host/`（Compose）が「既存のネイティブアプリ」に相当します。
どのフレームワークでもホストの画面構成は同じで、違うのは埋め込む画面の作り方だけです。

機能の仕様、計測マーカー、コーディング規約は [AGENTS.md](AGENTS.md) にまとめています。

## 動作の様子

計測用ビルド（検索先はモックサーバ）を agent-device で操作した画面の録画です。
ホスト画面 → 埋め込み画面を開く → 「リポジトリを検索」→ ホストからキーワードを `swift` に差し替える → ネイティブに戻り、受け取った結果を表示する、の順です。

| | native | KMP / CMP | Flutter | Expo |
| --- | --- | --- | --- | --- |
| iOS | ![iOS native](docs/media/ios-native.gif) | ![iOS KMP](docs/media/ios-kmp.gif) | ![iOS Flutter](docs/media/ios-flutter.gif) | ![iOS Expo](docs/media/ios-expo.gif) |
| Android | ![Android native](docs/media/android-native.gif) | ![Android KMP](docs/media/android-kmp.gif) | ![Android Flutter](docs/media/android-flutter.gif) | ![Android Expo](docs/media/android-expo.gif) |

録画は `node bench/demo.mjs` で撮り直せます（[bench/README.md](bench/README.md)）。

## 計測の方針

- **ビルド**: リリース構成。Expo も EAS ではなくローカルでビルドする。
  例外は iOS の Flutter で、シミュレータではデバッグ（JIT）の Flutter しか動かないため、それを組み込んでいる（ホストはリリース構成）。
- **端末**: iOS シミュレータと Android エミュレータ。
- **操作**: [agent-device](https://github.com/callstack/agent-device) ですべて自動化する。
- **時間**: agent-device の操作時間を含めないよう、アプリ内で出力するマーカー（`BENCH|<name>|<epochMs>`）の差で測る。
- **メモリ**: agent-device の `perf memory sample`（iOS はプロセスの RSS、Android は PSS）。
- **通信**: GitHub API の代わりに [bench/mock-server](bench/README.md) を使い、通信のばらつきとレート制限を除く。

## 各実装の埋め込み方

| | iOS に持ち込む形 | Android に持ち込む形 | 画面のランタイム | ホスト ⇄ 画面 |
| --- | --- | --- | --- | --- |
| [native](native/README.md) | ローカル Swift Package | ライブラリモジュール | なし（SwiftUI / Compose） | Swift / Kotlin の値をそのまま |
| [kmp](kmp/README.md) | static XCFramework | AAR | Compose Multiplatform（iOS は Skia で自前描画、Android は Jetpack Compose そのもの） | Kotlin オブジェクト（iOS は Objective-C interop 越し） |
| [flutter](flutter/README.md) | xcframework（dynamic） | AAR | Flutter エンジン（起動時に 1 つ作って使い回す） | MethodChannel |
| [expo](expo/README.md) | Swift Package（xcframework 群） | AAR | React Native（Hermes、起動時に初期化） | expo-brownfield のメッセージ |

## 計測結果

<!-- bench:results:start -->

### iOS

端末: iPhone 17（5 回の中央値、ウォームアップ 1 回を除く）

#### 時間

|  | native | KMP / CMP | Flutter | Expo |
| --- | ---: | ---: | ---: | ---: |
| コールドスタート（プロセス開始 → ホスト画面） | 920 ms | 924 ms | 1210 ms | 1306 ms |
| 埋め込み画面の表示（初回） | 145 ms | 181 ms | 160 ms | 433 ms |
| 埋め込み画面の表示（2 回目） | 44 ms | 82 ms | 58 ms | 48 ms |
| 検索 → 結果の描画 | 72 ms | 50 ms | 109 ms | 33 ms |
| 検索 → ホストが結果を受信 | 22 ms | 18 ms | 49 ms | 26 ms |
| ホスト → 埋め込み画面へのキーワード差し替え | 21 ms | 69 ms | 39 ms | 13 ms |

#### メモリ（RSS）

|  | native | KMP / CMP | Flutter | Expo |
| --- | ---: | ---: | ---: | ---: |
| ホスト画面の表示後 | 272.2 MB | 277.3 MB | 440.0 MB | 283.2 MB |
| 埋め込み画面の表示後 | 314.5 MB | 341.0 MB | 461.9 MB | 337.8 MB |
| 検索後 | 335.1 MB | 365.9 MB | 480.5 MB | 368.5 MB |
| ホストに戻った後 | 344.3 MB | 389.2 MB | 494.7 MB | 379.7 MB |

#### アプリサイズ

|  | native | KMP / CMP | Flutter | Expo |
| --- | ---: | ---: | ---: | ---: |
| .app（シミュレータ向け） | 1.0 MB | 32.4 MB | 139.8 MB | 52.5 MB |

### Android

端末: bench api36（5 回の中央値、ウォームアップ 1 回を除く）

#### 時間

|  | native | KMP / CMP | Flutter | Expo |
| --- | ---: | ---: | ---: | ---: |
| コールドスタート（プロセス開始 → ホスト画面） | 128 ms | 102 ms | 163 ms | 138 ms |
| 埋め込み画面の表示（初回） | 189 ms | 157 ms | 1974 ms | 171 ms |
| 埋め込み画面の表示（2 回目） | 201 ms | 194 ms | 225 ms | 77 ms |
| 検索 → 結果の描画 | 66 ms | 64 ms | 35 ms | 73 ms |
| 検索 → ホストが結果を受信 | 7 ms | 11 ms | 6 ms | 38 ms |
| ホスト → 埋め込み画面へのキーワード差し替え | 23 ms | 28 ms | 24 ms | 17 ms |

#### メモリ（PSS）

|  | native | KMP / CMP | Flutter | Expo |
| --- | ---: | ---: | ---: | ---: |
| ホスト画面の表示後 | 21.1 MB | 21.5 MB | 55.7 MB | 32.6 MB |
| 埋め込み画面の表示後 | 25.8 MB | 26.4 MB | 64.7 MB | 52.2 MB |
| 検索後 | 28.5 MB | 29.4 MB | 69.8 MB | 68.9 MB |
| ホストに戻った後 | 28.9 MB | 29.7 MB | 69.8 MB | 68.2 MB |

#### アプリサイズ

|  | native | KMP / CMP | Flutter | Expo |
| --- | ---: | ---: | ---: | ---: |
| APK（R8 有効） | 1.2 MB | 1.5 MB | 44.4 MB | 56.6 MB |

<!-- bench:results:end -->

### 計測環境

| | |
| --- | --- |
| Mac | MacBook Air（M3, 2024 / Mac15,12）、メモリ 16 GB、macOS 26.6.2 |
| iOS | Xcode 26.6、iPhone 17 シミュレータ（iOS 26.5） |
| Android | Android Emulator 37.1.11、AVD Pixel 9（API 36, Google APIs, arm64-v8a） |
| ツール | agent-device 0.21.1、Node.js 24.13.0 |
| フレームワーク | Flutter 3.47.4、Kotlin 2.4.20 / Compose Multiplatform 1.12.0、Expo SDK 57（React Native 0.86.2） |

### 結果の読み方

共通の注意:

- シミュレータ / エミュレータ上の数値です。実機の絶対値ではなく、同じ環境でのフレームワーク間の差として読んでください。
- Flutter と Expo は、埋め込みのランタイム（Flutter エンジン / React Native）をアプリ起動時に初期化します（[AGENTS.md](AGENTS.md)）。
  そのぶんはコールドスタートとホスト画面のメモリに入り、埋め込み画面を開く時間からは外れます。
- メモリは iOS がプロセスの RSS、Android が PSS で、指標が違います。プラットフォームをまたいで比べないでください。
  iOS シミュレータの RSS はシミュレータのシステムフレームワークも含むので、native でも 270 MB ほどになります。
- Android の APK はどれも 4 ABI（arm64-v8a / armeabi-v7a / x86 / x86_64）を含むユニバーサル APK です。
  ストアで ABI ごとに配信した場合の大きさではありません。
- 計測中の検索はモックサーバが返す固定の 20 件です（Android は `adb reverse` 経由）。通信時間はほぼ含みません。

Android:

- **コールドスタート**は native / KMP / Expo が 100〜140 ms、Flutter が約 160 ms。起動時のエンジン初期化のぶん Flutter が遅くなっています。
- **Flutter の埋め込み画面の初回表示（約 2 秒）** が突出しています。エンジンは起動時に動かしていますが、
  初めて `FlutterFragment` を付けるときの描画面の用意はここに入ります。エミュレータの Flutter は Impeller を OpenGLES で動かしており、
  この環境ではそれが大きく出ている可能性があります（実機での確認はしていません）。2 回目は約 220 ms で他と同程度です。
- どのホストも埋め込み画面を表示ごとに新しい Activity で開きます。その中で Expo の 2 回目の表示（約 80 ms）が最も短く、
  React Native のランタイムと JS がすでに読み込まれていて、ルートビューを作るだけで済むためと考えられます。
- **検索 → ホストが結果を受信** は Expo が約 40 ms で、ほかの 3 つ（10 ms 前後）より長くなっています。
  20 件の結果を JS からネイティブへ渡すメッセージの変換のぶんです。
- **メモリ**は native と KMP がほぼ同じ（Android の KMP の画面は Jetpack Compose そのもの）です。
  Flutter は起動直後から約 35 MB、Expo は検索後に約 40 MB、native より多く使います。

iOS:

- **Flutter の iOS はデバッグ（JIT）の Flutter で計測しています。** Flutter 3.47 のリリース / プロファイル用の
  `App.xcframework` はシミュレータ向けに Dart のコードを含まず、シミュレータでは動かせないためです（[flutter/README.md](flutter/README.md)）。
  ホストアプリはリリース構成ですが、Flutter のコールドスタート・描画・メモリ・アプリサイズはリリースより不利に出ています。
  特にアプリサイズ（約 140 MB）とメモリ（native より約 170 MB 多い）は、リリースの値の目安になりません。
- **コールドスタート**は native と KMP が約 920 ms で同じです。Flutter（約 1.2 秒）と Expo（約 1.3 秒）は、
  起動時にランタイムを初期化するぶん 300〜400 ms ほど長くなっています。
  iOS の値はプロセスの開始（`p_starttime`）からなので、シミュレータがプロセスを起こす時間も含み、Android より大きく出ます。
- **Expo の埋め込み画面の初回表示（約 430 ms）** が最も長く、2 回目は約 50 ms です。
  初回は React Native のルートビューと JS のコンポーネントを初めて描くぶんが入ります。
- **KMP の 2 回目の表示（約 80 ms）とキーワード差し替え（約 70 ms）** は native の 2〜3 倍です。
  iOS の Compose Multiplatform は Skia で自前描画し、`ComposeUIViewController` を表示ごとに作ります。
- Flutter の 2 回目の表示は、ビューコントローラーを 1 つ使い回す構成です（アクセシビリティのための制約。[flutter/README.md](flutter/README.md)）。
  表示ごとに作り直す他の実装より少し有利です。
- **メモリ**は native・KMP・Expo がホスト画面で 270〜285 MB と近く、埋め込み画面を開いて検索すると
  KMP と Expo は native より 30〜35 MB 多くなります。

## 計測をやり直す

手順は [run-benchmark スキル](.claude/skills/run-benchmark/SKILL.md) にまとめています。概略は次のとおりです。

```bash
cd bench
npm ci
npm run mock-server -- --quiet &
./scripts/build.sh <native|kmp|flutter|expo> <ios|android>   # 計測用ビルド
node run.mjs --platform ios --framework all --iterations 5
node run.mjs --platform android --framework all --iterations 5
node report.mjs --write
```
