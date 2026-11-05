import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import vm from 'node:vm';
import { compare, generate, html, markdown, markdownChanges, percentile, scenarioIds, summarize } from './performance-report.mjs';

function fixture() {
  return {
    schema_version: 1, suite_version: 2, platform: 'android', mode: 'profile',
    samples: 10, warmups: 2, fixture: 'controlled-repositories-no-network-no-wallet',
    environment: { device_model: 'Pixel 6', flutter_version: '3.47.6', runner: 'test', physical_device: true },
    machine: {
      host: { os: 'linux 6.1', arch: 'x64', cpu_model: 'Test CPU', logical_cores: 8, memory_bytes: 16 * 1024 ** 3 },
      device: { manufacturer: 'Google', model: 'Pixel 6', hardware: 'oriole', cpu_abi: 'arm64-v8a',
        cpu_cores: 8, memory_bytes: 8 * 1024 ** 3, display_width_px: 1080,
        display_height_px: 2400, density_dpi: 420 },
    },
    logical_size: { width: 393, height: 852 }, refresh_rate_hz: 60,
    commit: 'abc123', generated_at: '2026-10-13T00:00:00Z',
    scenarios: scenarioIds.map((id, index) => ({ id, label: id,
      duration_ms: [10, 20, 30, 40, 50, 60, 70, 80, 90, 100],
      frames: [
        { build_start_us: index * 2, build_ms: 1, raster_ms: 2, total_ms: 18 },
        { build_start_us: index * 2 + 1, build_ms: 17, raster_ms: 20, total_ms: 37 },
      ],
    })),
  };
}

test('nearest-rank percentiles and slow-frame union honor the refresh rate', () => {
  assert.equal(percentile([100, 1, 2, 3, 4], .95), 100);
  assert.equal(percentile([5, 1, 3, 2, 4], .5), 3);
  const raw = fixture();
  const row = summarize(raw).scenarios[0];
  assert.equal(row.duration_ms.p95, 100);
  assert.equal(row.duration_ms.p50, 50);
  assert.equal(row.slow_frames_percent, 50); // Count a slow frame once.
  raw.refresh_rate_hz = 120;
  raw.scenarios[0].frames[0].raster_ms = 9;
  assert.equal(summarize(raw).scenarios[0].slow_frames_percent, 100);
});

test('emulator reports keep raster timings diagnostic-only', () => {
  const raw = fixture();
  raw.environment.physical_device = false;
  raw.scenarios[0].frames[0].raster_ms = 30;
  const report = summarize(raw);
  assert.equal(report.scenarios[0].slow_frames_percent, 50);
  assert.equal(report.scenarios[0].ui_slow_frame_count, 1);
  assert.equal(report.scenarios[0].raster_slow_frame_count, 2);
  assert.equal(report.highlights.frames.raster_actionable, false);
  assert.equal(report.highlights.frames.slow_basis, 'ui');

  const next = structuredClone(report);
  next.scenarios[0].raster_ms.p95 += 100;
  const comparison = compare(next, report);
  assert.ok(!comparison.rows.some((row) => row.metric === 'raster_ms'));
  assert.match(markdown(next, comparison), /Software-GPU raster times are diagnostic only/);
  assert.match(html(next, comparison, raw, [report, next]), /UI slow frames/);
});

test('summary highlights user workflows and frame health', () => {
  const report = summarize(fixture());
  assert.equal(report.highlights.page_load.id, 'home_load');
  assert.equal(report.highlights.interaction_ready.id, 'market_buy_open_ready');
  assert.equal(report.highlights.quote.id, 'market_buy_quote');
  assert.equal(report.highlights.command.id, 'market_buy_preview');
  assert.equal(report.highlights.frames.count, 52);
  assert.equal(report.highlights.frames.slow_count, 26);
  assert.equal(report.machine.host.cpu_model, 'Test CPU');
});

test('summary frame health counts overlapping milestone frames once', () => {
  const raw = fixture();
  raw.scenarios[1].frames = structuredClone(raw.scenarios[0].frames);
  const report = summarize(raw);
  assert.equal(report.scenarios[0].frame_count, 2);
  assert.equal(report.scenarios[1].frame_count, 2);
  assert.equal(report.highlights.frames.count, 50);
  assert.equal(report.highlights.frames.slow_count, 25);
});

test('incomplete, invalid, debug, and web results fail instead of producing a green report', () => {
  for (const mutate of [
    (r) => { r.mode = 'debug'; }, (r) => { r.platform = 'web'; },
    (r) => { r.scenarios.pop(); }, (r) => { r.scenarios[1].id = r.scenarios[0].id; },
    (r) => { r.scenarios[0].duration_ms.pop(); }, (r) => { r.scenarios[0].frames = []; },
    (r) => { r.scenarios[0].duration_ms[0] = NaN; },
    (r) => { r.scenarios[0].frames[0].build_ms = -1; },
    (r) => { delete r.scenarios[0].frames[0].build_start_us; },
    (r) => { delete r.environment; }, (r) => { delete r.environment.physical_device; },
    (r) => { delete r.machine; },
    (r) => { r.machine.host.logical_cores = 0; }, (r) => { r.refresh_rate_hz = 0; },
  ]) {
    const raw = fixture(); mutate(raw);
    assert.throws(() => summarize(raw));
  }
});

test('baseline requires matching device, mode, SDK, viewport, refresh rate and suite', () => {
  const report = summarize(fixture());
  assert.equal(compare(report, null).comparable, false);
  for (const mutate of [
    (c) => { c.environment.device_model = 'another phone'; },
    (c) => { c.environment.flutter_version = 'new SDK'; },
    (c) => { c.environment.runner = 'physical runner'; },
    (c) => { c.logical_size.width = 400; }, (c) => { c.refresh_rate_hz = 120; },
    (c) => { c.report_version = 1; }, (c) => { c.suite_version = 1; },
    (c) => { c.samples = 20; },
    (c) => { c.diagnostic_tracing = true; },
  ]) {
    const old = structuredClone(report); mutate(old.compatibility);
    assert.equal(compare(report, old).comparable, false);
  }
  const reordered = structuredClone(report);
  reordered.compatibility.environment = {
    runner: 'test', physical_device: true, flutter_version: '3.47.6', device_model: 'Pixel 6',
  };
  assert.equal(compare(report, reordered).comparable, true);
  const otherHost = structuredClone(report);
  otherHost.machine.host.cpu_model = 'Another host CPU';
  otherHost.machine.host.memory_bytes *= 2;
  assert.equal(compare(report, otherHost).comparable, true);
});

test('regression thresholds combine relative and absolute tolerances', () => {
  const old = summarize(fixture());
  const next = structuredClone(old);
  next.scenarios[0].duration_ms.p95 = 121;
  next.scenarios[0].build_ms.p95 = 18;
  next.scenarios[0].slow_frames_percent = 56;
  const warnings = compare(next, old).rows.filter((r) => r.regression);
  assert.deepEqual(warnings.map((r) => r.metric), ['duration_ms', 'slow_frames_percent']);
  old.scenarios[0].duration_ms.p95 = 0;
  const zero = compare(next, old).rows[0];
  assert.equal(zero.percent, null);
  assert.equal(zero.regression, true);
});

test('change markdown lists significant improvements and regressions against the baseline', () => {
  const baseline = summarize(fixture());
  const current = structuredClone(baseline);
  current.commit = 'current';
  current.scenarios[0].duration_ms.p95 = 130;
  current.scenarios[1].duration_ms.p95 = 50;
  const changes = markdownChanges(current, compare(current, baseline));
  assert.match(changes, /Compared with main `abc123`/);
  assert.match(changes, /home_load/);
  assert.match(changes, /markets_load/);
  assert.match(changes, /\+30\.00ms/);
  assert.match(changes, /-50\.00ms/);
});

test('change markdown explains when no compatible baseline is available', () => {
  assert.match(markdownChanges(summarize(fixture()), compare(summarize(fixture()), null)), /No compatible main baseline is available/);
});

test('HTML is self-contained, escaped and contains valid interactive JavaScript', () => {
  const raw = fixture();
  raw.scenarios[0].label = '</script><script>alert(1)</script>';
  raw.commit = '<img src=x onerror=alert(1)>';
  const report = summarize(raw);
  const document = html(report, compare(report, null), raw, [report]);
  assert.ok(!document.includes(raw.scenarios[0].label));
  assert.ok(!document.includes(raw.commit));
  assert.ok(!document.includes('src="https://'));
  assert.match(document, /Test CPU/);
  assert.match(document, /Page load P95/);
  assert.match(document, /Test Environment/);
  const script = document.match(/<script>\n([\s\S]*?)<\/script>/)[1];
  assert.doesNotThrow(() => new vm.Script(script));
  const embedded = document.match(/type="application\/json">([\s\S]*?)<\/script>/)[1];
  assert.equal(JSON.parse(embedded).raw.commit, raw.commit);
});

test('report controls render both action samples and native frame samples', () => {
  const raw = fixture();
  const report = summarize(raw);
  const baseline = structuredClone(report);
  baseline.commit = 'previous';
  const document = html(report, compare(report, baseline), raw, [baseline, report]);
  const embedded = document.match(/type="application\/json">([\s\S]*?)<\/script>/)[1];
  const nodes = new Map();
  const getNode = (id) => {
    if (!nodes.has(id)) nodes.set(id, { value: '', textContent: '', innerHTML: '', options: [],
      append(option) { this.options.push(option); if (!this.value) this.value = option.value; } });
    return nodes.get(id);
  };
  getNode('data').textContent = embedded;
  getNode('metric').value = 'duration_ms';
  vm.runInNewContext(document.match(/<script>\n([\s\S]*?)<\/script>/)[1], {
    document: { getElementById: getNode, createElement: () => ({}) },
  });
  assert.equal(getNode('scenario').options.length, 26);
  assert.match(getNode('distribution').innerHTML, /Samples 10/);
  assert.match(getNode('bars').innerHTML, /main/);
  assert.match(getNode('trend').innerHTML, /previous/);
  getNode('metric').value = 'raster_ms';
  getNode('scenario').value = 'limit_sell_cancel';
  getNode('scenario').onchange();
  assert.match(getNode('distribution').innerHTML, /Samples 2/);
  assert.match(getNode('distribution').innerHTML, /Frame budget 16.67 ms/);
  assert.match(getNode('bars').innerHTML, /20.00/);
});

test('report generation writes all artifacts, keeps compatible history, and applies optional gate', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'vanta-performance-'));
  const { writeFile } = await import('node:fs/promises');
  const raw = fixture();
  const input = join(dir, 'input.json');
  const baselineDir = join(dir, 'baseline');
  const actionsSummary = join(dir, 'github-summary.md');
  const originalActionsSummary = process.env.GITHUB_STEP_SUMMARY;
  try {
    await writeFile(actionsSummary, 'existing summary\n');
    process.env.GITHUB_STEP_SUMMARY = actionsSummary;
    await writeFile(input, JSON.stringify(raw));
    await generate({ input, output: baselineDir, baselineDir: join(dir, 'missing') });
    raw.commit = 'def456';
    raw.scenarios[0].duration_ms = Array(10).fill(250);
    await writeFile(input, JSON.stringify(raw));
    const output = join(dir, 'current');
    const result = await generate({ input, output, baselineDir, gate: false });
    assert.equal(result.comparison.comparable, true);
    assert.deepEqual(result.history.map((h) => h.commit), ['abc123', 'def456']);
    for (const file of ['raw.json', 'report.json', 'history.json', 'report.html', 'summary.md', 'changes.md']) {
      assert.ok((await readFile(join(output, file), 'utf8')).length > 0);
    }
    await generate({ input, output, baselineDir, gate: true });
    assert.equal(process.exitCode, 1);
    process.exitCode = 0;
    assert.equal(await readFile(actionsSummary, 'utf8'), 'existing summary\n');
  } finally {
    if (originalActionsSummary === undefined) delete process.env.GITHUB_STEP_SUMMARY;
    else process.env.GITHUB_STEP_SUMMARY = originalActionsSummary;
    await rm(dir, { recursive: true, force: true });
  }
});
