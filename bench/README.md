# bench

計測に使うツール一式です。

## モックサーバ

GitHub Search API の代わりに、記録済みの 20 件を返すサーバです。
計測中はすべての実装がここを検索します。

```bash
cd bench
npm install
npm run mock-server              # http://127.0.0.1:8787
npm run mock-server -- --delay-ms 200 --quiet
```

本物の API を使わない理由は 2 つあります。

- **レート制限**: 未認証の検索は 10 リクエスト/分までで、4 実装 × 2 プラットフォーム × 複数回の計測に足りない。
- **ばらつき**: 通信時間が結果の大半を占めてしまい、フレームワークの差（JSON の変換、描画、ブリッジ）が見えなくなる。

`GET /search/repositories` だけに応答し、クエリにかかわらず
[`fixtures/search-repositories.json`](mock-server/fixtures/search-repositories.json)
を返します（`q` が無いときは本物と同じく 422）。フィクスチャは実際の API の
`q=expo&sort=stars&order=desc&per_page=20` の応答から、アプリが使うフィールドだけを残したものです。

ループバック（`127.0.0.1`）でのみ待ち受けます。アプリからの接続先は次のとおりです。

| プラットフォーム | ベース URL |
| --- | --- |
| iOS シミュレータ | `http://127.0.0.1:8787`（ホストとネットワークを共有している） |
| Android エミュレータ | `http://10.0.2.2:8787`（エミュレータからホストのループバックへの固定アドレス） |

## 計測ランナー

[agent-device](https://github.com/callstack/agent-device) で iOS シミュレータ / Android エミュレータを操作し、
全実装を同じシナリオで計測します。手順の全体は [run-benchmark スキル](../.claude/skills/run-benchmark/SKILL.md) にまとめています。

```bash
npm ci
npm run mock-server -- --quiet &                # 計測中は常に起動しておく
./scripts/build.sh native ios                   # 計測用ビルド → artifacts/<framework>/<platform>/
node run.mjs --platform ios --framework native  # → results/ios-native.json
node report.mjs                                 # Markdown の表にする（--write でルート README を更新）
```

### 1 回分のシナリオ

`run.mjs` は次の流れを `--warmup`（既定 1）+ `--iterations`（既定 5）回繰り返します。

1. `agent-device open <app> --relaunch` でコールド起動する
2. ホスト画面が出たら、落ち着くのを待って（`--settle-ms`、既定 2 秒）メモリを取る
3. 埋め込み画面を開く → メモリ
4. 「リポジトリを検索」→ 結果が出たらメモリ
5. ホストからキーワード `swift` を送る
6. 「ネイティブに戻る」→ メモリ
7. もう一度開いて戻る（2 回目の表示）

### 指標

時間はアプリが出すマーカー（[AGENTS.md](../AGENTS.md)）の差で、agent-device の操作時間は含みません。

| 指標 | マーカー |
| --- | --- |
| コールドスタート | `processStart` → `hostFirstFrame` |
| 埋め込み画面の表示（初回 / 2 回目） | `embedOpenTapped` → `embedFirstFrame` |
| 検索 → 描画 | `searchTapped` → `searchRendered` |
| 検索 → ホストが受信 | `searchTapped` → `resultsReceived` |
| キーワード差し替え | `commandSent` → `keywordApplied` |

メモリは `agent-device perf memory sample` の値で、iOS はプロセスの常駐サイズ（`ps` の RSS）、
Android は `dumpsys meminfo` の PSS です。プラットフォーム間では比較できません。
`agent-device open` が返す `startup.durationMs`（open コマンドの往復時間）も参考値として JSON に残します。

### 注意

- iOS の Flutter だけは Debug（JIT）のフレームワークで計測します。Release（AOT）はシミュレータで動かないためです（[flutter/README.md](../flutter/README.md)）。
- Xcode の Build Location がカスタムの場合の注意は [スキル](../.claude/skills/run-benchmark/SKILL.md) を参照してください。
- 計測中は Mac で他のビルドなどを走らせないでください。数値が大きくぶれます。

## 開発

```bash
npm run lint       # Biome
npm test           # node:test
```
