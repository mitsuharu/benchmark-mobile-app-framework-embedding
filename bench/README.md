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

## 開発

```bash
npm run lint       # Biome
npm test           # node:test
```
