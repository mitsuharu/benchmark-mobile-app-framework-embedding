---
name: run-benchmark
description: Build the benchmark builds of the embedding implementations (native, kmp, flutter, expo) and measure cold start, response time and memory on the iOS simulator / Android emulator with agent-device, then update the results in README.md. Use when asked to run, re-run or update the benchmark.
---

# run-benchmark

計測の手順です。詳細な背景は [bench/README.md](../../../bench/README.md) と [AGENTS.md](../../../AGENTS.md) を参照してください。

## 0. 前提

- Xcode（`.xcode-version`）、XcodeGen、Android SDK（`ANDROID_HOME`）、JDK 17、Node.js（`.node-version`）
- Flutter は FVM（`flutter/.fvmrc`）、Expo は CocoaPods も必要
- iOS シミュレータ（既定: iPhone 17）と Android エミュレータの AVD が 1 台ずつあること

```bash
cd bench
npm ci
```

## 1. 端末を起動する

```bash
npx agent-device boot --platform ios --device "iPhone 17"
npx agent-device boot --platform android --device <avd-name> --headless
```

## 2. モックサーバを起動する（計測中は常に）

```bash
npm run mock-server -- --quiet
```

バックグラウンドで起動し、計測が終わるまで止めないこと。

## 3. 計測用ビルドを作る

リリース構成で、検索先をモックサーバに向けたビルドを `bench/artifacts/` に作ります。

```bash
./scripts/build.sh native ios
./scripts/build.sh native android
# kmp / flutter / expo も同様
```

失敗したら、そのフレームワークの README の「ビルドと実行」に従って前段の成果物
（xcframework / AAR）を作り直してください。

## 4. 計測する

```bash
node run.mjs --platform ios --framework all --iterations 5
node run.mjs --platform android --framework all --iterations 5
```

- 結果は `bench/results/<platform>-<framework>.json` に書き出される。
- 端末が複数あるときは `--udid <UDID>`（iOS）/ `--serial emulator-5554`（Android）で指定する。
- 1 回の計測は「コールド起動 → 埋め込み画面を開く → 検索 → キーワード差し替え → 戻る → もう一度開く → 戻る」。
  最初の 1 回（`--warmup`）はインストール直後の影響があるので集計から外す。

### Xcode の Build Location がカスタムの場合

Xcode の Settings → Locations → Advanced が `Custom` だと、agent-device が iOS 用のランナーを
ビルドした後に `.xctestrun` を見つけられず `Failed to locate .xctestrun after build` で失敗します。
ランナーはカスタムの場所にビルドされているので、それを指定してください。

```bash
export AGENT_DEVICE_IOS_XCTESTRUN_FILE="$(ls <Custom の Products のパス>/AgentDeviceRunner_*iphonesimulator*.xctestrun | head -1)"
```

## 5. README を更新する

```bash
node report.mjs           # 表を確認
node report.mjs --write   # ルート README の計測結果を差し替える
```

計測環境（Mac の機種、Xcode / Android Emulator のバージョン、シミュレータ / AVD）を README に書き添えること。

## 注意

- 計測中は Mac で他の重い処理（ビルドなど）を走らせない。数値が大きくぶれる。
- 数値はシミュレータ / エミュレータのもので、実機の絶対値ではない。フレームワーク間の相対比較に使う。
