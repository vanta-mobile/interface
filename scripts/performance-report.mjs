import { appendFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const scenarioIds = [
  'home_load', 'markets_load', 'markets_scroll', 'details_load',
  ...['buy', 'sell'].flatMap((side) => ['market', 'limit'].flatMap((type) => [
    ...['open_ready', 'open_settled', 'quote', 'preview', 'submit'].map((stage) => `${type}_${side}_${stage}`),
    ...(type === 'limit' ? [`${type}_${side}_cancel`] : []),
  ])),
];

export function percentile(values, p) {
  if (!values.length) throw new Error('Empty sample distribution');
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.max(0, Math.ceil(sorted.length * p) - 1)];
}

function distribution(values, label) {
  if (!Array.isArray(values) || !values.length || values.some((v) => !Number.isFinite(v) || v < 0)) {
    throw new Error(`Invalid samples: ${label}`);
  }
  return { count: values.length, p50: percentile(values, .5), p95: percentile(values, .95), max: Math.max(...values) };
}

function compatibility(raw) {
  return {
    report_version: 3,
    schema_version: raw.schema_version,
    suite_version: raw.suite_version,
    environment: raw.environment,
    platform: raw.platform,
    mode: raw.mode,
    fixture: raw.fixture,
    logical_size: raw.logical_size,
    refresh_rate_hz: raw.refresh_rate_hz,
    samples: raw.samples,
    warmups: raw.warmups,
    diagnostic_tracing: raw.diagnostic_tracing,
  };
}

function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stable(value[key])]));
  }
  return value;
}

function worstScenario(scenarios, predicate, metric = 'duration_ms') {
  return scenarios.filter(predicate).reduce((worst, scenario) =>
    !worst || scenario[metric].p95 > worst[metric].p95 ? scenario : worst, null);
}

function performanceHighlights(scenarios, frames, frameBudget, rasterActionable) {
  const pageLoad = worstScenario(scenarios, (s) => ['home_load', 'markets_load', 'details_load'].includes(s.id));
  const interactive = worstScenario(scenarios, (s) => s.id.endsWith('_open_ready'));
  const quote = worstScenario(scenarios, (s) => s.id.endsWith('_quote'));
  const command = worstScenario(scenarios, (s) => /_(preview|submit|cancel)$/.test(s.id));
  const build = worstScenario(scenarios, () => true, 'build_ms');
  const raster = worstScenario(scenarios, () => true, 'raster_ms');
  const frameCount = frames.length;
  const uiSlowFrameCount = frames.filter((frame) => frame.build_ms > frameBudget).length;
  const rasterSlowFrameCount = frames.filter((frame) => frame.raster_ms > frameBudget).length;
  const slowFrameCount = frames.filter((frame) =>
    frame.build_ms > frameBudget || (rasterActionable && frame.raster_ms > frameBudget)).length;
  const result = (scenario) => ({ id: scenario.id, label: scenario.label, p95_ms: scenario.duration_ms.p95 });
  return {
    page_load: result(pageLoad),
    interaction_ready: result(interactive),
    quote: result(quote),
    command: result(command),
    frames: {
      budget_ms: frameBudget,
      count: frameCount,
      slow_count: slowFrameCount,
      slow_percent: slowFrameCount / frameCount * 100,
      slow_basis: rasterActionable ? 'ui_or_raster' : 'ui',
      raster_actionable: rasterActionable,
      ui_slow_count: uiSlowFrameCount,
      raster_slow_count: rasterSlowFrameCount,
      worst_build: { id: build.id, label: build.label, p95_ms: build.build_ms.p95 },
      worst_raster: { id: raster.id, label: raster.label, p95_ms: raster.raster_ms.p95 },
    },
  };
}

export function summarize(raw) {
  if (raw.schema_version !== 1 || raw.suite_version !== 2 || raw.mode !== 'profile' || !['android', 'ios'].includes(raw.platform)) {
    throw new Error('Expected suite version 2 native profile performance data');
  }
  if (!raw.environment?.device_model || !raw.environment?.flutter_version || !raw.environment?.runner ||
      typeof raw.environment.physical_device !== 'boolean' ||
      !raw.commit || !raw.generated_at || !Number.isInteger(raw.samples) || raw.samples < 5 ||
      !Number.isInteger(raw.warmups) || raw.warmups < 1 ||
      !raw.machine?.host?.cpu_model || !Number.isInteger(raw.machine.host.logical_cores) ||
      raw.machine.host.logical_cores < 1 || !Number.isFinite(raw.machine.host.memory_bytes) ||
      !Number.isFinite(raw.refresh_rate_hz) || raw.refresh_rate_hz <= 0 ||
      !Number.isFinite(raw.logical_size?.width) || raw.logical_size.width <= 0 ||
      !Number.isFinite(raw.logical_size?.height) || raw.logical_size.height <= 0) {
    throw new Error('Incomplete measurement environment');
  }
  if (!Array.isArray(raw.scenarios) || raw.scenarios.length !== scenarioIds.length ||
      new Set(raw.scenarios.map((s) => s.id)).size !== scenarioIds.length ||
      scenarioIds.some((id) => !raw.scenarios.some((s) => s.id === id))) {
    throw new Error('Missing or duplicate performance scenarios');
  }
  const budget = 1000 / raw.refresh_rate_hz;
  const rasterActionable = raw.environment.physical_device !== false;
  const uniqueFrames = new Map();
  const scenarios = raw.scenarios.map((s) => {
    const duration = distribution(s.duration_ms, s.id);
    if (duration.count !== raw.samples || !Array.isArray(s.frames) || !s.frames.length) {
      throw new Error(`Incomplete measured actions/frames: ${s.id}`);
    }
    for (const frame of s.frames) {
      if (!Number.isSafeInteger(frame.build_start_us) || frame.build_start_us < 0) {
        throw new Error(`Invalid frame timestamp: ${s.id}`);
      }
      uniqueFrames.set(frame.build_start_us, frame);
    }
    const build = distribution(s.frames.map((f) => f.build_ms), `${s.id} build`);
    const raster = distribution(s.frames.map((f) => f.raster_ms), `${s.id} raster`);
    const total = distribution(s.frames.map((f) => f.total_ms), `${s.id} total`);
    const uiSlow = s.frames.filter((f) => f.build_ms > budget).length;
    const rasterSlow = s.frames.filter((f) => f.raster_ms > budget).length;
    const slow = s.frames.filter((f) =>
      f.build_ms > budget || (rasterActionable && f.raster_ms > budget)).length;
    return { id: s.id, label: s.label, duration_ms: duration, build_ms: build, raster_ms: raster,
      total_ms: total, frame_count: s.frames.length, slow_frame_count: slow,
      ui_slow_frame_count: uiSlow, raster_slow_frame_count: rasterSlow,
      slow_frames_percent: slow / s.frames.length * 100 };
  });
  return { schema_version: 1, commit: raw.commit, generated_at: raw.generated_at,
    compatibility: compatibility(raw), machine: raw.machine, frame_budget_ms: budget,
    highlights: performanceHighlights(scenarios, [...uniqueFrames.values()], budget, rasterActionable), scenarios };
}

export function compare(current, baseline) {
  if (!baseline) return { comparable: false, reason: 'first run or no main baseline is available', rows: [] };
  if (JSON.stringify(stable(current.compatibility)) !== JSON.stringify(stable(baseline.compatibility))) {
    return { comparable: false, reason: 'device, Flutter, sampling configuration, or scenario version differs from the baseline', rows: [] };
  }
  const rows = [];
  for (const scenario of current.scenarios) {
    const old = baseline.scenarios.find((s) => s.id === scenario.id);
    if (!old) return { comparable: false, reason: 'baseline scenarios are incomplete', rows: [] };
    const metrics = [['duration_ms', 'Action P95', 20], ['build_ms', 'UI frame P95', 3]];
    if (current.highlights.frames.raster_actionable) metrics.push(['raster_ms', 'Raster frame P95', 3]);
    for (const [metric, label, floor] of metrics) {
      const value = scenario[metric].p95;
      const before = old[metric].p95;
      const delta = value - before;
      const threshold = Math.max(before * .2, floor);
      rows.push({ id: scenario.id, label: scenario.label, metric, metric_label: label, before, value,
        delta, percent: before > 0 ? delta / before * 100 : null, threshold,
        regression: delta > threshold });
    }
    const slowDelta = scenario.slow_frames_percent - old.slow_frames_percent;
    rows.push({ id: scenario.id, label: scenario.label, metric: 'slow_frames_percent', metric_label: 'Slow-frame rate',
      before: old.slow_frames_percent, value: scenario.slow_frames_percent,
      delta: slowDelta, threshold: 5,
      regression: slowDelta > 5 });
  }
  return { comparable: true, baseline_commit: baseline.commit, rows };
}

const esc = (value) => String(value).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (v) => Number(v).toFixed(2);
const gib = (bytes) => `${(Number(bytes) / 1024 ** 3).toFixed(1)} GiB`;
const shortRevision = (value) => String(value).slice(0, 12);
const markdownText = (v) => String(v).replace(/[|\r\n]/g, ' ');

export function markdown(report, comparison) {
  const env = report.compatibility.environment;
  const machine = report.machine;
  const highlights = report.highlights;
  const rasterActionable = highlights.frames.raster_actionable;
  const slowLabel = rasterActionable ? 'slow frames' : 'UI slow frames';
  const warnings = comparison.rows.filter((r) => r.regression);
  const lines = ['## Native Flutter Performance Report', '',
    `Platform: ${markdownText(report.compatibility.platform)} · ${markdownText(env.device_model)} · profile · Flutter ${markdownText(env.flutter_version)}`,
    `${report.compatibility.samples} samples per scenario after ${report.compatibility.warmups} warmups; ${fmt(report.compatibility.refresh_rate_hz)} Hz refresh rate.`,
    '', `Controlled repository data without network requests, wallet signatures, or on-chain confirmation; page load does not represent a cold app start. ${rasterActionable ? 'A slow frame exceeds the device frame budget in either UI or raster time.' : 'On emulators, slow frames are based only on UI time exceeding the device frame budget.'}`, '',
    ...(env.physical_device === false ? ['This report uses emulator data. Software-GPU raster times are diagnostic only and do not affect slow-frame counts, regression warnings, or gates. Re-test on a fixed physical device for device performance.', ''] : []),
    ...(report.compatibility.diagnostic_tracing ? ['Diagnostic tracing is enabled. Values include tracing overhead and are not suitable for the normal performance baseline.', ''] : []),
    comparison.comparable ? `Baseline: \`${markdownText(comparison.baseline_commit)}\`; ${warnings.length} regression warning(s).` : `Not compared: ${comparison.reason}.`, '',
    '### Summary', '',
    '| Dimension | P95 / status | Scenario |', '|---|---:|---|',
    `| Page load | ${fmt(highlights.page_load.p95_ms)} ms | ${markdownText(highlights.page_load.label)} |`,
    `| Panel interactive | ${fmt(highlights.interaction_ready.p95_ms)} ms | ${markdownText(highlights.interaction_ready.label)} |`,
    `| Quote update | ${fmt(highlights.quote.p95_ms)} ms | ${markdownText(highlights.quote.label)} |`,
    `| Confirm / submit / cancel | ${fmt(highlights.command.p95_ms)} ms | ${markdownText(highlights.command.label)} |`,
    `| Frame health | ${fmt(highlights.frames.slow_percent)}% ${slowLabel} (${highlights.frames.slow_count}/${highlights.frames.count}) | UI ${fmt(highlights.frames.worst_build.p95_ms)} ms / raster ${fmt(highlights.frames.worst_raster.p95_ms)} ms${rasterActionable ? '' : ' (diagnostic)'} |`,
    '', '### Test Environment', '',
    '| Item | Value |', '|---|---|',
    `| Runner | ${markdownText(env.runner)} |`,
    `| Host | ${markdownText(machine.host.os)} · ${markdownText(machine.host.arch)} |`,
    `| Host CPU | ${markdownText(machine.host.cpu_model)} · ${machine.host.logical_cores} logical cores |`,
    `| Host memory | ${gib(machine.host.memory_bytes)} |`,
    `| Mobile device | ${markdownText(machine.device.manufacturer)} ${markdownText(machine.device.model)} · ${markdownText(env.os_version)} |`,
    `| Device CPU / memory | ${markdownText(machine.device.cpu_abi ?? 'unknown')} · ${machine.device.cpu_cores ?? 'unknown'} cores · ${machine.device.memory_bytes ? gib(machine.device.memory_bytes) : 'unknown'} |`,
    `| Display | ${machine.device.display_width_px && machine.device.display_height_px ? `${machine.device.display_width_px}×${machine.device.display_height_px}px` : 'unknown'} · ${fmt(report.compatibility.logical_size.width)}×${fmt(report.compatibility.logical_size.height)}dp · ${machine.device.density_dpi ?? 'unknown'} dpi · ${fmt(report.compatibility.refresh_rate_hz)} Hz |`,
    `| Flutter | ${markdownText(env.flutter_version)} · ${markdownText(shortRevision(env.flutter_revision))} |`, '',
    '### All Operations', '',
    `| Scenario | Action P50 / P95 (ms) | UI P95 (ms) | Raster P95 (ms) | ${slowLabel} | Action P95 change |`,
    '|---|---:|---:|---:|---:|---:|'];
  for (const s of report.scenarios) {
    const delta = comparison.rows.find((r) => r.id === s.id && r.metric === 'duration_ms');
    const change = delta ? `${delta.regression ? '🔴' : '🟢'} ${delta.percent === null ? '—' : `${delta.percent >= 0 ? '+' : ''}${fmt(delta.percent)}%`}` : '—';
    lines.push(`| ${markdownText(s.label)} | ${fmt(s.duration_ms.p50)} / ${fmt(s.duration_ms.p95)} | ${fmt(s.build_ms.p95)} | ${fmt(s.raster_ms.p95)} | ${fmt(s.slow_frames_percent)}% (${s.slow_frame_count}/${s.frame_count}) | ${change} |`);
  }
  if (warnings.length) {
    lines.push('', '### Regression Warnings', '', ...warnings.map((r) => `- ${markdownText(r.label)} / ${r.metric_label}: ${fmt(r.before)} → ${fmt(r.value)} ${r.metric === 'slow_frames_percent' ? '%' : 'ms'}`));
  }
  lines.push('', 'Download the `native-performance` artifact and open `report.html` for interactive comparisons, distributions, and trends. `raw.json` contains per-action timings and frame data.',
    '', `Warning thresholds: duration increase above max(20%, 20ms), UI${rasterActionable ? '/raster' : ''} P95 increase above max(20%, 3ms), or ${slowLabel} increase above 5 percentage points. Warnings are informational by default; strict gating can be enabled on a fixed device.`);
  return `${lines.join('\n')}\n`;
}

export function markdownChanges(report, comparison) {
  const lines = ['## Native Flutter performance changes', ''];
  if (!comparison.comparable) {
    lines.push(`No compatible main baseline is available: ${comparison.reason}.`);
    return `${lines.join('\n')}\n`;
  }
  const changes = comparison.rows
    .filter((row) => Math.abs(row.delta) > row.threshold)
    .sort((a, b) => Math.abs(b.delta) - Math.abs(a.delta));
  lines.push(`Compared with main \`${markdownText(comparison.baseline_commit)}\`; ${changes.length} significant change(s).`, '');
  if (!changes.length) {
    lines.push('No significant performance changes were detected.');
    return `${lines.join('\n')}\n`;
  }
  lines.push('| Scenario | Metric | Previous | Current | Change |', '|---|---|---:|---:|---:|');
  for (const row of changes) {
    const unit = row.metric === 'slow_frames_percent' ? '%' : 'ms';
    const sign = row.delta >= 0 ? '+' : '';
    lines.push(`| ${markdownText(row.label)} | ${row.metric_label} | ${fmt(row.before)}${unit} | ${fmt(row.value)}${unit} | ${sign}${fmt(row.delta)}${unit} |`);
  }
  return `${lines.join('\n')}\n`;
}

export function html(report, comparison, raw, history) {
  // Embedded data is inert JSON, with HTML-significant characters escaped.
  const data = JSON.stringify({ report, comparison, raw, history }).replace(/</g, '\\u003c').replace(/>/g, '\\u003e').replace(/&/g, '\\u0026');
  const env = report.compatibility.environment;
  const machine = report.machine;
  const highlights = report.highlights;
  const rasterActionable = highlights.frames.raster_actionable;
  const slowLabel = rasterActionable ? 'slow frames' : 'UI slow frames';
  const comparisonText = comparison.comparable
    ? `Compared with main ${comparison.baseline_commit.slice(0, 12)}; ${comparison.rows.filter((r) => r.regression).length} regression warning(s).`
    : `Not compared: ${comparison.reason}.`;
  const overview = [
    ['Page load P95', highlights.page_load.p95_ms, highlights.page_load.label],
    ['Panel interactive P95', highlights.interaction_ready.p95_ms, highlights.interaction_ready.label],
    ['Quote update P95', highlights.quote.p95_ms, highlights.quote.label],
    ['Command P95', highlights.command.p95_ms, highlights.command.label],
  ].map(([label, value, detail]) => `<div class="metric"><span>${esc(label)}</span><strong>${fmt(value)} ms</strong><small>${esc(detail)}</small></div>`).join('');
  const display = machine.device.display_width_px && machine.device.display_height_px
    ? `${machine.device.display_width_px}×${machine.device.display_height_px}px`
    : 'unknown';
  const machineRows = [
    ['Runner', env.runner],
    ['Host', `${machine.host.os} · ${machine.host.arch}`],
    ['Host CPU', `${machine.host.cpu_model} · ${machine.host.logical_cores} logical cores`],
    ['Host memory', gib(machine.host.memory_bytes)],
    ['Mobile device', `${machine.device.manufacturer} ${machine.device.model} · ${env.os_version}`],
    ['Device CPU / memory', `${machine.device.cpu_abi ?? 'unknown'} · ${machine.device.cpu_cores ?? 'unknown'} cores · ${machine.device.memory_bytes ? gib(machine.device.memory_bytes) : 'unknown'}`],
    ['Display', `${display} · ${fmt(report.compatibility.logical_size.width)}×${fmt(report.compatibility.logical_size.height)}dp · ${machine.device.density_dpi ?? 'unknown'} dpi · ${fmt(report.compatibility.refresh_rate_hz)} Hz`],
    ['Flutter', `${env.flutter_version} · ${shortRevision(env.flutter_revision)}`],
  ].map(([label, value]) => `<div><dt>${esc(label)}</dt><dd>${esc(value)}</dd></div>`).join('');
  return `<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Vanta Native Performance Report</title>
<style>
body{font:15px system-ui;margin:0;background:#f3f5f8;color:#182538}main{max-width:1180px;margin:auto;padding:28px}h1{font-size:26px}h2{font-size:18px}section{background:white;padding:22px;border-radius:8px;margin:18px 0}select{padding:8px;max-width:100%;margin:4px 12px 4px 0}table{border-collapse:collapse;width:100%;font-size:13px}th,td{text-align:left;padding:10px;border-bottom:1px solid #e7ebf0}tr.warn{background:#fff0ee}.scroll{overflow:auto}svg{width:100%;height:auto}p{line-height:1.65;color:#536176}.legend{color:#2563eb}.baseline{color:#8895a7}#tip{min-height:24px}svg circle:hover{r:6;cursor:pointer}.overview{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));border:1px solid #e7ebf0;border-radius:6px}.metric{display:grid;gap:5px;padding:16px;border-right:1px solid #e7ebf0}.metric:last-child{border:0}.metric span,.metric small,dt{color:#69778a}.metric strong{font-size:20px}.metric small{font-size:12px}.frame-health{margin:16px 0 0}.specs{display:grid;grid-template-columns:1fr 1fr;margin:0}.specs div{display:grid;grid-template-columns:120px 1fr;padding:9px 0;border-bottom:1px solid #e7ebf0}.specs div:nth-child(odd){margin-right:24px}.specs dt,.specs dd{margin:0}.specs dd{overflow-wrap:anywhere}@media(max-width:760px){main{padding:16px}.overview,.specs{grid-template-columns:1fr}.metric{border-right:0;border-bottom:1px solid #e7ebf0}.specs div:nth-child(odd){margin-right:0}}
</style>
<main><h1>Vanta · Native Flutter Performance Report</h1><p id="meta"></p><p>Controlled repository data without real network requests, wallet signatures, or on-chain confirmation. Page load measures navigation until data is ready and does not represent a cold app start. ${rasterActionable ? 'A slow frame exceeds the device refresh budget in either UI or raster time.' : 'On emulators, slow frames are based only on UI time exceeding the device refresh budget.'}</p>${report.compatibility.environment.physical_device === false ? '<p>This report uses emulator data. Software-GPU raster times are diagnostic only and do not affect slow-frame counts, regression warnings, or gates. Re-test on a fixed physical device for device performance.</p>' : ''}
${report.compatibility.diagnostic_tracing ? '<p><strong>Diagnostic tracing is enabled:</strong> this report includes tracing overhead and is not suitable for the normal performance baseline.</p>' : ''}
<section><h2>Summary</h2><p>${esc(comparisonText)}</p><div class="overview">${overview}</div><p class="frame-health">Frame health: ${fmt(highlights.frames.slow_percent)}% ${slowLabel} (${highlights.frames.slow_count}/${highlights.frames.count}); worst UI P95 ${fmt(highlights.frames.worst_build.p95_ms)} ms, worst raster P95 ${fmt(highlights.frames.worst_raster.p95_ms)} ms${rasterActionable ? '' : ' (diagnostic)'}, frame budget ${fmt(highlights.frames.budget_ms)} ms.</p></section>
<section><h2>Test Environment</h2><dl class="specs">${machineRows}</dl></section>
<section><h2>All Key Operations</h2><p id="comparison"></p><div class="scroll"><table id="summary"></table></div></section>
<section><h2>Scenario Analysis</h2><label>Scenario <select id="scenario"></select></label><label>Metric <select id="metric"><option value="duration_ms">Action duration</option><option value="build_ms">UI frame duration</option><option value="raster_ms">Raster frame duration</option></select></label>
<p class="legend">Blue: current run <span class="baseline">Gray: main baseline</span></p><h2>P95 Comparison (ms)</h2><div id="bars"></div><h2>Current Sample Distribution</h2><div id="distribution"></div><h2>Historical Trend (P95, ms)</h2><p>The latest 30 compatible main reports for the same device and test configuration, plus the current run. Point to a data point to see its commit and value.</p><div id="trend"></div><p id="tip" aria-live="polite"></p></section>
<p>Commit: ${esc(report.commit)} · ${esc(report.generated_at)}. Raw data: <a href="raw.json">raw.json</a>; summary: <a href="report.json">report.json</a>; history: <a href="history.json">history.json</a>.</p></main>
<script id="data" type="application/json">${data}</script>
<script>
const {report,comparison,raw,history}=JSON.parse(document.getElementById('data').textContent);
const $=id=>document.getElementById(id);const fmt=v=>Number(v).toFixed(2);const escape=v=>String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
$('meta').textContent=report.compatibility.platform+' · '+report.compatibility.environment.device_model+' · '+report.compatibility.environment.os_version+' · profile · Flutter '+report.compatibility.environment.flutter_version+' · '+report.compatibility.samples+' samples / '+report.compatibility.warmups+' warmups · '+fmt(report.compatibility.refresh_rate_hz)+' Hz';
$('comparison').textContent=comparison.comparable?'Compared with main '+comparison.baseline_commit.slice(0,12)+'; '+comparison.rows.filter(r=>r.regression).length+' regression warning(s).':'Not compared: '+comparison.reason;
$('summary').innerHTML='<tr><th>Scenario</th><th>Action P50 / P95 ms</th><th>UI P95 ms</th><th>Raster P95 ms</th><th>${slowLabel}</th><th>Frames</th></tr>'+report.scenarios.map(s=>'<tr class="'+(comparison.rows.some(r=>r.id===s.id&&r.regression)?'warn':'')+'"><td>'+escape(s.label)+'</td><td>'+fmt(s.duration_ms.p50)+' / '+fmt(s.duration_ms.p95)+'</td><td>'+fmt(s.build_ms.p95)+'</td><td>'+fmt(s.raster_ms.p95)+'</td><td>'+fmt(s.slow_frames_percent)+'%</td><td>'+s.frame_count+'</td></tr>').join('');
report.scenarios.forEach(s=>{const o=document.createElement('option');o.value=s.id;o.textContent=s.label;$('scenario').append(o)});
function svg(body,h=200){return '<svg viewBox="0 0 1000 '+h+'" role="img">'+body+'</svg>'}
function update(){const id=$('scenario').value,metric=$('metric').value,s=report.scenarios.find(s=>s.id===id),r=raw.scenarios.find(s=>s.id===id);const base=comparison.rows.find(r=>r.id===id&&r.metric===metric);const max=Math.max(s[metric].p95,base?.before??0,1);$('bars').innerHTML=svg([[s[metric].p95,'Current','#2563eb'],...(base?[[base.before,'main','#8895a7']]:[])].map(([v,l,c],i)=>'<text x="0" y="'+(32+i*62)+'">'+l+'</text><rect x="80" y="'+(12+i*62)+'" width="'+(v/max*800)+'" height="30" fill="'+c+'"/><text x="'+(90+v/max*800)+'" y="'+(32+i*62)+'">'+fmt(v)+'</text>').join(''),145);
const values=metric==='duration_ms'?r.duration_ms:r.frames.map(f=>f[metric]);const upper=Math.max(...values,metric==='duration_ms'?0:report.frame_budget_ms,1);const bins=Array(20).fill(0);values.forEach(v=>bins[Math.min(19,Math.floor(v/upper*20))]++);const high=Math.max(...bins,1);let drawing=bins.map((n,i)=>'<rect x="'+(50+i*46)+'" y="'+(170-n/high*140)+'" width="40" height="'+(n/high*140)+'" fill="#2563eb"><title>'+fmt(i/20*upper)+'–'+fmt((i+1)/20*upper)+' ms: '+n+' samples</title></rect>').join('');drawing+='<text x="50" y="195">0 ms</text><text x="870" y="195">'+fmt(upper)+' ms</text><text x="50" y="20">Samples '+values.length+'; highest bin '+high+'</text>';if(metric!=='duration_ms'){const x=50+report.frame_budget_ms/upper*920;drawing+='<line x1="'+x+'" x2="'+x+'" y1="25" y2="175" stroke="#dc2626" stroke-dasharray="4"/><text x="'+Math.min(x,760)+'" y="20">Frame budget '+fmt(report.frame_budget_ms)+' ms</text>'}$('distribution').innerHTML=svg(drawing,210);
const points=history.map(h=>({commit:h.commit,date:h.generated_at,value:h.scenarios.find(s=>s.id===id)?.[metric]?.p95})).filter(p=>Number.isFinite(p.value));const top=Math.max(...points.map(p=>p.value),1);const coords=points.map((p,i)=>({x:60+i/Math.max(points.length-1,1)*880,y:170-p.value/top*140,...p}));$('trend').innerHTML=svg('<text x="0" y="25">'+fmt(top)+'</text><text x="0" y="175">0</text><path d="'+coords.map((p,i)=>(i?'L':'M')+p.x+','+p.y).join(' ')+'" fill="none" stroke="#2563eb" stroke-width="2"/>'+coords.map(p=>'<circle cx="'+p.x+'" cy="'+p.y+'" r="4" fill="#2563eb"><title>'+escape(p.commit.slice(0,12)+' · '+p.date+' · '+fmt(p.value)+' ms')+'</title></circle>').join('')+'<text x="60" y="200">'+(points[0]?.commit.slice(0,8)??'')+'</text><text x="860" y="200">'+(points.at(-1)?.commit.slice(0,8)??'')+'</text>',215);$('tip').textContent=points.length<2?'At least two compatible reports are required to show a trend.':'';}
$('scenario').onchange=update;$('metric').onchange=update;update();
</script></html>`;
}

async function optionalJson(path) {
  try { return JSON.parse(await readFile(path, 'utf8')); }
  catch (error) { if (error.code === 'ENOENT') return null; throw error; }
}

export async function generate({ input = 'build/performance/raw.json', output = 'build/performance', baselineDir = 'build/performance-baseline', gate = false } = {}) {
  const raw = JSON.parse(await readFile(input, 'utf8'));
  const report = summarize(raw);
  const baseline = await optionalJson(`${baselineDir}/report.json`);
  const comparison = compare(report, baseline);
  const previous = await optionalJson(`${baselineDir}/history.json`) ?? [];
  const signature = JSON.stringify(stable(report.compatibility));
  const history = previous.filter((h) => h.commit !== report.commit && JSON.stringify(stable(h.compatibility)) === signature).slice(-29);
  history.push(report);
  const summary = markdown(report, comparison);
  const changes = markdownChanges(report, comparison);
  await mkdir(output, { recursive: true });
  await Promise.all([
    writeFile(`${output}/report.json`, `${JSON.stringify({ ...report, comparison }, null, 2)}\n`),
    writeFile(`${output}/history.json`, `${JSON.stringify(history, null, 2)}\n`),
    writeFile(`${output}/summary.md`, summary),
    writeFile(`${output}/changes.md`, changes),
    writeFile(`${output}/report.html`, html(report, comparison, raw, history)),
    ...(resolve(input) !== resolve(`${output}/raw.json`) ? [writeFile(`${output}/raw.json`, `${JSON.stringify(raw, null, 2)}\n`)] : []),
  ]);
  const regressions = comparison.rows.filter((r) => r.regression);
  console.log(`Performance report: ${output}/report.html (${regressions.length} regression warnings)`);
  if (gate && regressions.length) process.exitCode = 1;
  return { report, comparison, history, summary };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const args = process.argv.slice(2);
  const options = {};
  while (args.length) {
    const arg = args.shift();
    if (arg === '--fail-on-regression') options.gate = true;
    else if (['--input', '--output', '--baseline-dir'].includes(arg) && args.length) {
      options[{ '--input': 'input', '--output': 'output', '--baseline-dir': 'baselineDir' }[arg]] = args.shift();
    } else throw new Error(`Unknown or missing argument: ${arg}`);
  }
  const result = await generate(options);
  if (process.env.GITHUB_STEP_SUMMARY) {
    await appendFile(process.env.GITHUB_STEP_SUMMARY, result.summary);
  }
}
