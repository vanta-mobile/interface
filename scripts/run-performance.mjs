import { spawnSync } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { arch, cpus, platform, release, totalmem } from 'node:os';

function capture(command, args) {
  const result = spawnSync(command, args, { encoding: 'utf8' });
  if (result.error || result.status !== 0) {
    throw new Error(`${command} failed: ${result.error?.message ?? result.stderr}`);
  }
  return result.stdout.trim();
}

function captureOptional(command, args) {
  try { return capture(command, args); }
  catch { return null; }
}

const args = process.argv.slice(2);
if (args.length && (args.length !== 2 || args[0] !== '--device')) {
  throw new Error('Usage: node scripts/run-performance.mjs [--device <Android/iOS device ID>]');
}
const devices = JSON.parse(capture('flutter', ['devices', '--machine']));
const nativeDevices = devices.filter((d) => /^(android|ios)(-|$)/.test(d.targetPlatform));
const requested = args[1] ?? process.env.PERF_DEVICE;
const device = requested
  ? nativeDevices.find((d) => d.id === requested)
  : nativeDevices.length === 1 ? nativeDevices[0] : undefined;
if (!device) throw new Error('Select one connected Android/iOS device with --device. Web is unsupported.');
if (device.targetPlatform.startsWith('ios') && device.emulator) {
  throw new Error('iOS profile performance requires a physical device, not an iOS simulator.');
}
const flutter = JSON.parse(capture('flutter', ['--version', '--machine']));
const samples = Number(process.env.PERF_SAMPLES ?? 30);
const warmups = Number(process.env.PERF_WARMUPS ?? 2);
const output = process.env.PERF_OUTPUT_DIR ?? 'build/performance';
const diagnosticTracing = process.env.PERF_TRACE_SCENARIOS === 'true' ||
  process.env.PERF_TRACE_DETAILS === 'true';
if (!Number.isInteger(samples) || samples < 5 || !Number.isInteger(warmups) || warmups < 1) {
  throw new Error('PERF_SAMPLES must be >= 5 and PERF_WARMUPS must be >= 1');
}
const android = device.targetPlatform.startsWith('android');
const property = (key) => capture('adb', ['-s', device.id, 'shell', 'getprop', key]);
const shell = (...command) => captureOptional('adb', ['-s', device.id, 'shell', ...command]);
const deviceMemoryKb = Number(shell('cat', '/proc/meminfo')?.match(/MemTotal:\s+(\d+)\s+kB/)?.[1]);
const physicalSize = shell('wm', 'size')?.match(/Physical size:\s*(\d+)x(\d+)/);
const density = Number(shell('wm', 'density')?.match(/Physical density:\s*(\d+)/)?.[1]);
const cpuInfo = cpus();
const environment = {
  flutter_version: flutter.frameworkVersion,
  flutter_revision: flutter.frameworkRevision,
  target: device.targetPlatform,
  device_model: android ? property('ro.product.model') : device.name,
  os_version: device.sdk,
  physical_device: !device.emulator,
  runner: process.env.PERF_RUNNER_LABEL ?? `local-${process.platform}-${process.arch}`,
  ...(android ? { android_api: property('ro.build.version.sdk'), abi: property('ro.product.cpu.abi') } : {}),
};
const machine = {
  host: {
    os: `${platform()} ${release()}`,
    arch: arch(),
    cpu_model: cpuInfo[0]?.model ?? 'unknown',
    logical_cores: cpuInfo.length,
    memory_bytes: totalmem(),
  },
  device: {
    manufacturer: android ? property('ro.product.manufacturer') : 'Apple',
    model: environment.device_model,
    hardware: android ? property('ro.hardware') : null,
    cpu_abi: android ? environment.abi : null,
    cpu_cores: android ? Number(shell('getconf', '_NPROCESSORS_ONLN')) || null : null,
    memory_bytes: Number.isFinite(deviceMemoryKb) ? deviceMemoryKb * 1024 : null,
    display_width_px: physicalSize ? Number(physicalSize[1]) : null,
    display_height_px: physicalSize ? Number(physicalSize[2]) : null,
    density_dpi: Number.isFinite(density) ? density : null,
  },
};
// Remove only the previous raw result so a failed run cannot reuse stale data.
// The final report/artifacts are left intact until successfully regenerated.
await mkdir(output, { recursive: true });
const { rm } = await import('node:fs/promises');
await rm(`${output}/raw.json`, { force: true });
for (const scenario of [
  'details',
  'markets-load',
  'details-load',
  'market-buy-preview',
  'limit-buy-submit',
]) {
  await rm(`${output}/${scenario}-timeline.json`, { force: true });
}
const result = spawnSync('flutter', [
  'drive', '--profile', '--no-pub', '-d', device.id,
  '--driver=test_driver/performance_driver.dart',
  '--target=integration_test/performance_test.dart',
  `--dart-define=PERF_SAMPLES=${samples}`,
  `--dart-define=PERF_WARMUPS=${warmups}`,
  `--dart-define=PERF_OUTPUT_DIR=${output}`,
  `--dart-define=PERF_TRACE_SCENARIOS=${diagnosticTracing}`,
  ...(diagnosticTracing ? ['--no-dds'] : []),
  '--timeout=900',
], {
  stdio: 'inherit',
  // Flutter's drive timeout does not bound VM Service connection retries.
  // Leave time for diagnostics and artifact upload before the CI job expires.
  timeout: 25 * 60 * 1000,
  killSignal: 'SIGKILL',
});
if (result.error || result.status !== 0) {
  if (android) {
    const logcat = captureOptional('adb', ['-s', device.id, 'logcat', '-d', '-t', '2000']);
    if (logcat) await writeFile(`${output}/android-logcat.txt`, logcat);
  }
  console.error(`Native performance run failed: ${result.error?.message ?? result.status}`);
  process.exit(result.status || 1);
}
const raw = JSON.parse(await readFile(`${output}/raw.json`, 'utf8'));
raw.environment = environment;
raw.machine = machine;
raw.commit = process.env.PERF_COMMIT ?? process.env.GITHUB_SHA ?? capture('git', ['rev-parse', 'HEAD']);
raw.generated_at = new Date().toISOString();
await writeFile(`${output}/raw.json`, `${JSON.stringify(raw, null, 2)}\n`);
console.log(`Native performance data: ${output}/raw.json`);
