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

## 計測の方針

- **ビルド**: リリース構成。Expo も EAS ではなくローカルでビルドする。
- **端末**: iOS シミュレータと Android エミュレータ。
- **操作**: [agent-device](https://github.com/callstack/agent-device) ですべて自動化する。
- **時間**: agent-device の操作時間を含めないよう、アプリ内で出力するマーカー（`BENCH|<name>|<epochMs>`）の差で測る。
- **メモリ**: agent-device の `perf memory sample`（iOS はプロセスの RSS、Android は PSS）。
- **通信**: GitHub API の代わりに [bench/mock-server](bench/README.md) を使い、通信のばらつきとレート制限を除く。
