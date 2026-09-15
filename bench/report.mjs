#!/usr/bin/env node
/**
 * Turns results/<build>/*.json into the Markdown tables of the root README.
 *
 *   node report.mjs            # print the tables
 *   node report.mjs --write    # replace each build's section in ../README.md
 *
 * Each build has its own section between
 * `<!-- bench:results:<build>:start -->` and `<!-- bench:results:<build>:end -->`.
 * The debug section also compares every figure with the release build.
 */
import { readdir, readFile, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { parseArgs } from 'node:util'

import { BUILDS, FRAMEWORKS, PLATFORMS } from './lib/targets.mjs'

const { values: options } = parseArgs({
  options: {
    results: { type: 'string', default: 'results' },
    write: { type: 'boolean', default: false },
  },
})

const BENCH_ROOT = path.dirname(fileURLToPath(import.meta.url))
const README = path.join(BENCH_ROOT, '..', 'README.md')
const markers = (build) => [
  `<!-- bench:results:${build}:start -->`,
  `<!-- bench:results:${build}:end -->`,
]

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
const appSize = (result) => `${mb(result.appSizeBytes / 1024)} MB`

function table(header, rows) {
  const line = (cells) => `| ${cells.join(' | ')} |`
  return [
    line(header),
    line(header.map((_, index) => (index === 0 ? '---' : '---:'))),
    ...rows.map(line),
  ].join('\n')
}

/** Results by build, then by `<platform>/<framework>`. */
async function loadResults() {
  const results = {}
  for (const build of BUILDS) {
    const dir = path.resolve(BENCH_ROOT, options.results, build)
    const files = await readdir(dir).catch(() => [])
    for (const file of files.filter((name) => name.endsWith('.json'))) {
      const result = JSON.parse(await readFile(path.join(dir, file), 'utf8'))
      results[build] ??= {}
      results[build][`${result.platform}/${result.framework}`] = result
    }
  }
  return results
}

function platformSection(platform, results, release) {
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
  const sizeLabel =
    platform === 'ios'
      ? '.app（シミュレータ向け）'
      : sample.build === 'debug'
        ? 'APK'
        : 'APK（R8 有効）'

  const sections = [
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
      [sizeLabel, ...frameworks.map((framework) => appSize(of(framework)))],
    ]),
  ]

  // How far each debug figure is from the release build's.
  const compared = release
    ? frameworks.filter((framework) => release[`${platform}/${framework}`])
    : []
  if (compared.length > 0) {
    const releaseOf = (framework) => release[`${platform}/${framework}`]
    const arrow = (before, after) => `${before} → ${after}`
    sections.push(
      '',
      '#### リリースビルドとの比較（リリース → デバッグ）',
      '',
      table(
        ['', ...compared.map((framework) => FRAMEWORK_NAMES[framework])],
        [
          ...TIMINGS.map(([key, label]) => [
            label,
            ...compared.map((framework) =>
              arrow(
                ms(releaseOf(framework).summary.timingsMs[key]),
                ms(of(framework).summary.timingsMs[key]),
              ),
            ),
          ]),
          [
            `メモリ（${memoryKind}、検索後）`,
            ...compared.map((framework) =>
              arrow(
                memory(releaseOf(framework).summary.memoryKb.afterSearch),
                memory(of(framework).summary.memoryKb.afterSearch),
              ),
            ),
          ],
          [
            'アプリサイズ',
            ...compared.map((framework) =>
              arrow(appSize(releaseOf(framework)), appSize(of(framework))),
            ),
          ],
        ],
      ),
    )
  }
  return sections.join('\n')
}

function buildSection(build, results) {
  const release = build === 'release' ? null : results.release
  return PLATFORMS.map((platform) =>
    platformSection(platform, results[build], release),
  )
    .filter(Boolean)
    .join('\n\n')
}

const results = await loadResults()
const builds = BUILDS.filter((build) => results[build])

if (!options.write) {
  console.log(
    builds
      .map((build) => `## ${build}\n\n${buildSection(build, results)}`)
      .join('\n\n'),
  )
} else {
  let readme = await readFile(README, 'utf8')
  for (const build of builds) {
    const [start, end] = markers(build)
    const from = readme.indexOf(start)
    const to = readme.indexOf(end)
    if (from === -1 || to === -1) {
      throw new Error(`README.md has no ${start} ... ${end} section`)
    }
    readme = `${readme.slice(0, from + start.length)}\n\n${buildSection(build, results)}\n\n${readme.slice(to)}`
  }
  await writeFile(README, readme)
  console.log(
    `Updated ${path.relative(process.cwd(), README)} (${builds.join(', ')})`,
  )
}
