#!/usr/bin/env node
/**
 * Turns results/*.json into the Markdown tables of the root README.
 *
 *   node report.mjs            # print the tables
 *   node report.mjs --write    # replace the section between the markers in ../README.md
 */
import { readdir, readFile, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { parseArgs } from 'node:util'

import { FRAMEWORKS, PLATFORMS } from './lib/targets.mjs'

const { values: options } = parseArgs({
  options: {
    results: { type: 'string', default: 'results' },
    write: { type: 'boolean', default: false },
  },
})

const BENCH_ROOT = path.dirname(fileURLToPath(import.meta.url))
const README = path.join(BENCH_ROOT, '..', 'README.md')
const START = '<!-- bench:results:start -->'
const END = '<!-- bench:results:end -->'

const PLATFORM_NAMES = { ios: 'iOS', android: 'Android' }
const FRAMEWORK_NAMES = {
  native: 'native',
  kmp: 'KMP / CMP',
  flutter: 'Flutter',
  expo: 'Expo',
}

const TIMINGS = [
  ['coldStartMs', 'コールドスタート（プロセス開始 → ホスト画面）'],
  ['embedOpenColdMs', '埋め込み画面の表示（初回）'],
  ['embedOpenWarmMs', '埋め込み画面の表示（2 回目）'],
  ['searchRenderMs', '検索 → 結果の描画'],
  ['searchToHostMs', '検索 → ホストが結果を受信'],
  ['commandMs', 'ホスト → 埋め込み画面へのキーワード差し替え'],
]

const MEMORY = [
  ['hostIdle', 'ホスト画面の表示後'],
  ['embedOpened', '埋め込み画面の表示後'],
  ['afterSearch', '検索後'],
  ['backToHost', 'ホストに戻った後'],
]

const ms = (summary) => (summary ? `${Math.round(summary.median)} ms` : '—')
const mb = (kb) => (kb / 1024).toFixed(1)
const memory = (summary) => (summary ? `${mb(summary.median)} MB` : '—')

function table(header, rows) {
  const line = (cells) => `| ${cells.join(' | ')} |`
  return [
    line(header),
    line(header.map((_, index) => (index === 0 ? '---' : '---:'))),
    ...rows.map(line),
  ].join('\n')
}

async function loadResults() {
  const dir = path.resolve(BENCH_ROOT, options.results)
  const results = {}
  for (const file of await readdir(dir)) {
    if (!file.endsWith('.json')) {
      continue
    }
    const result = JSON.parse(await readFile(path.join(dir, file), 'utf8'))
    results[`${result.platform}/${result.framework}`] = result
  }
  return results
}

function platformSection(platform, results) {
  const frameworks = FRAMEWORKS.filter(
    (framework) => results[`${platform}/${framework}`],
  )
  if (frameworks.length === 0) {
    return null
  }
  const of = (framework) => results[`${platform}/${framework}`]
  const header = [
    '',
    ...frameworks.map((framework) => FRAMEWORK_NAMES[framework]),
  ]
  const sample = of(frameworks[0])
  const memoryKind = platform === 'ios' ? 'RSS' : 'PSS'

  return [
    `### ${PLATFORM_NAMES[platform]}`,
    '',
    `端末: ${sample.device.name}（${sample.iterations} 回の中央値、ウォームアップ ${sample.warmup} 回を除く）`,
    '',
    '#### 時間',
    '',
    table(
      header,
      TIMINGS.map(([key, label]) => [
        label,
        ...frameworks.map((framework) =>
          ms(of(framework).summary.timingsMs[key]),
        ),
      ]),
    ),
    '',
    `#### メモリ（${memoryKind}）`,
    '',
    table(
      header,
      MEMORY.map(([key, label]) => [
        label,
        ...frameworks.map((framework) =>
          memory(of(framework).summary.memoryKb[key]),
        ),
      ]),
    ),
    '',
    '#### アプリサイズ',
    '',
    table(header, [
      [
        platform === 'ios' ? '.app（シミュレータ向け）' : 'APK（R8 有効）',
        ...frameworks.map(
          (framework) => `${mb(of(framework).appSizeBytes / 1024)} MB`,
        ),
      ],
    ]),
  ].join('\n')
}

const results = await loadResults()
const report = PLATFORMS.map((platform) => platformSection(platform, results))
  .filter(Boolean)
  .join('\n\n')

if (!options.write) {
  console.log(report)
} else {
  const readme = await readFile(README, 'utf8')
  const start = readme.indexOf(START)
  const end = readme.indexOf(END)
  if (start === -1 || end === -1) {
    throw new Error(`README.md has no ${START} ... ${END} section`)
  }
  await writeFile(
    README,
    `${readme.slice(0, start + START.length)}\n\n${report}\n\n${readme.slice(end)}`,
  )
  console.log(`Updated ${path.relative(process.cwd(), README)}`)
}
