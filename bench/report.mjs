#!/usr/bin/env node
/**
 * Turns results/<section>/*.json into the Markdown tables of the root README.
 *
 *   node report.mjs            # print the tables
 *   node report.mjs --write    # replace each section in ../README.md
 *
 * Each section has its own place between
 * `<!-- bench:results:<section>:start -->` and `<!-- bench:results:<section>:end -->`.
 * The debug and physical-device sections also compare every figure with the
 * release build on the simulator / emulator.
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
const markers = (section) => [
  `<!-- bench:results:${section}:start -->`,
  `<!-- bench:results:${section}:end -->`,
]

/**
 * The README sections, each read from results/<id>/ (see run.mjs). A
 * section with a base compares every figure with it; `baseFirst: false`
 * puts the section's own figure first (development happens in debug, so the
 * debug comparison reads debug → release).
 */
const SECTIONS = [
  { id: 'release' },
  {
    id: 'debug',
    base: 'release',
    baseFirst: false,
    compareTitle: 'リリースビルドにしたときの変化（デバッグ → リリース）',
  },
  {
    id: 'release-device',
    base: 'release',
    compareTitle:
      'シミュレータ / エミュレータとの比較（シミュレータ・エミュレータ → 実機）',
  },
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

/** Results by section, then by `<platform>/<framework>`. */
async function loadResults() {
  const results = {}
  for (const { id } of SECTIONS) {
    const dir = path.resolve(BENCH_ROOT, options.results, id)
    const files = await readdir(dir).catch(() => [])
    for (const file of files.filter((name) => name.endsWith('.json'))) {
      const result = JSON.parse(await readFile(path.join(dir, file), 'utf8'))
      results[id] ??= {}
      results[id][`${result.platform}/${result.framework}`] = result
    }
  }
  return results
}

function sizeLabel(platform, result) {
  if (platform === 'ios') {
    return result.physical ? '.app（実機向け）' : '.app（シミュレータ向け）'
  }
  return result.build === 'debug' ? 'APK' : 'APK（R8 有効）'
}

function platformSection(
  platform,
  results,
  base,
  { compareTitle, baseFirst = true } = {},
) {
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
      [
        sizeLabel(platform, sample),
        ...frameworks.map((framework) => appSize(of(framework))),
      ],
    ]),
  ]

  // How far each figure is from the base section's.
  const compared = base
    ? frameworks.filter((framework) => base[`${platform}/${framework}`])
    : []
  if (compared.length > 0) {
    const baseOf = (framework) => base[`${platform}/${framework}`]
    // `before` is always the base's figure and `after` this section's.
    const arrow = (before, after) =>
      baseFirst ? `${before} → ${after}` : `${after} → ${before}`
    sections.push(
      '',
      `#### ${compareTitle}`,
      '',
      table(
        ['', ...compared.map((framework) => FRAMEWORK_NAMES[framework])],
        [
          ...TIMINGS.map(([key, label]) => [
            label,
            ...compared.map((framework) =>
              arrow(
                ms(baseOf(framework).summary.timingsMs[key]),
                ms(of(framework).summary.timingsMs[key]),
              ),
            ),
          ]),
          [
            `メモリ（${memoryKind}、検索後）`,
            ...compared.map((framework) =>
              arrow(
                memory(baseOf(framework).summary.memoryKb.afterSearch),
                memory(of(framework).summary.memoryKb.afterSearch),
              ),
            ),
          ],
          [
            'アプリサイズ',
            ...compared.map((framework) =>
              arrow(appSize(baseOf(framework)), appSize(of(framework))),
            ),
          ],
        ],
      ),
    )
  }
  return sections.join('\n')
}

function renderSection({ id, base, ...compare }, results) {
  return PLATFORMS.map((platform) =>
    platformSection(
      platform,
      results[id],
      base ? results[base] : null,
      compare,
    ),
  )
    .filter(Boolean)
    .join('\n\n')
}

const results = await loadResults()
const sections = SECTIONS.filter(({ id }) => results[id])

if (!options.write) {
  console.log(
    sections
      .map(
        (section) => `## ${section.id}\n\n${renderSection(section, results)}`,
      )
      .join('\n\n'),
  )
} else {
  let readme = await readFile(README, 'utf8')
  for (const section of sections) {
    const [start, end] = markers(section.id)
    const from = readme.indexOf(start)
    const to = readme.indexOf(end)
    if (from === -1 || to === -1) {
      throw new Error(`README.md has no ${start} ... ${end} section`)
    }
    readme = `${readme.slice(0, from + start.length)}\n\n${renderSection(section, results)}\n\n${readme.slice(to)}`
  }
  await writeFile(README, readme)
  console.log(
    `Updated ${path.relative(process.cwd(), README)} (${sections.map(({ id }) => id).join(', ')})`,
  )
}
