# Fueki Wallet - Performance Benchmark Suite

## Overview

This document defines the comprehensive benchmark suite for measuring and tracking Fueki wallet performance across all critical operations.

---

## 1. Benchmark Categories

### 1.1 App Launch Benchmarks
### 1.2 Crypto Operations Benchmarks
### 1.3 Memory Usage Benchmarks
### 1.4 Network Performance Benchmarks
### 1.5 Battery Consumption Benchmarks

---

## 2. App Launch Benchmarks

### 2.1 Cold Start Benchmark

```javascript
// benchmarks/app-launch/cold-start.bench.ts
import { performance } from 'perf_hooks';
import { launchApp, clearCache } from '../test-utils';

describe('Cold Start Performance', () => {
  beforeEach(async () => {
    await clearCache(); // Clear all app data
    await device.relaunchApp({
      delete: true,
      permissions: { notifications: 'YES' }
    });
  });

  it('should cold start within p50 SLA (1500ms)', async () => {
    const measurements = [];

    for (let i = 0; i < 10; i++) {
      const start = performance.now();

      await device.launchApp({ newInstance: true });
      await waitFor(element(by.id('wallet-dashboard')))
        .toBeVisible()
        .withTimeout(5000);

      const duration = performance.now() - start;
      measurements.push(duration);

      await device.terminateApp();
      await sleep(2000); // Cool down period
    }

    const p50 = percentile(measurements, 50);
    const p95 = percentile(measurements, 95);
    const p99 = percentile(measurements, 99);

    console.log('Cold Start Results:');
    console.log(`  p50: ${p50.toFixed(0)}ms`);
    console.log(`  p95: ${p95.toFixed(0)}ms`);
    console.log(`  p99: ${p99.toFixed(0)}ms`);

    expect(p50).toBeLessThan(1500);
    expect(p95).toBeLessThan(2000);
    expect(p99).toBeLessThan(2500);
  });

  it('should measure launch phase breakdown', async () => {
    const phases = await measureLaunchPhases();

    console.log('Launch Phase Breakdown:');
    console.log(`  Native init: ${phases.nativeInit}ms`);
    console.log(`  JS bundle load: ${phases.bundleLoad}ms`);
    console.log(`  Crypto init: ${phases.cryptoInit}ms`);
    console.log(`  Blockchain connect: ${phases.blockchainConnect}ms`);
    console.log(`  UI render: ${phases.uiRender}ms`);

    // Phase-specific SLAs
    expect(phases.bundleLoad).toBeLessThan(300);
    expect(phases.cryptoInit).toBeLessThan(200);
    expect(phases.blockchainConnect).toBeLessThan(800);
  });
});

async function measureLaunchPhases() {
  const phases = {
    nativeInit: 0,
    bundleLoad: 0,
    cryptoInit: 0,
    blockchainConnect: 0,
    uiRender: 0,
  };

  // Use performance marks
  performance.mark('app-start');

  await device.launchApp({ newInstance: true });

  // Capture phase markers from app
  const markers = await device.getPerformanceMarkers();

  phases.nativeInit = markers['native-init'] - markers['app-start'];
  phases.bundleLoad = markers['bundle-loaded'] - markers['native-init'];
  phases.cryptoInit = markers['crypto-ready'] - markers['bundle-loaded'];
  phases.blockchainConnect = markers['blockchain-connected'] - markers['crypto-ready'];
  phases.uiRender = markers['ui-ready'] - markers['blockchain-connected'];

  return phases;
}
```

### 2.2 Warm Start Benchmark

```javascript
// benchmarks/app-launch/warm-start.bench.ts
describe('Warm Start Performance', () => {
  it('should warm start within p50 SLA (400ms)', async () => {
    // First launch
    await device.launchApp();
    await waitFor(element(by.id('wallet-dashboard'))).toBeVisible();

    const measurements = [];

    for (let i = 0; i < 20; i++) {
      // Background app
      await device.sendToHome();
      await sleep(1000);

      // Measure resume
      const start = performance.now();
      await device.launchApp({ newInstance: false });
      await waitFor(element(by.id('wallet-dashboard'))).toBeVisible();
      const duration = performance.now() - start;

      measurements.push(duration);
    }

    const p50 = percentile(measurements, 50);
    const p95 = percentile(measurements, 95);

    console.log('Warm Start Results:');
    console.log(`  p50: ${p50.toFixed(0)}ms`);
    console.log(`  p95: ${p95.toFixed(0)}ms`);

    expect(p50).toBeLessThan(400);
    expect(p95).toBeLessThan(600);
  });
});
```

---

## 3. Crypto Operations Benchmarks

### 3.1 TSS Key Generation Benchmark

```javascript
// benchmarks/crypto/tss-keygen.bench.ts
import { TSSKeyGenerator } from '../../src/crypto/tss';

describe('TSS Key Generation Performance', () => {
  it('should generate 2-of-3 keys within SLA (600ms p95)', async () => {
    const keygen = new TSSKeyGenerator();
    const measurements = [];

    for (let i = 0; i < 50; i++) {
      const start = performance.now();

      await keygen.generateKeys({
        threshold: 2,
        parties: 3,
      });

      const duration = performance.now() - start;
      measurements.push(duration);
    }

    const stats = calculateStats(measurements);

    console.log('TSS Keygen Results (2-of-3):');
    console.log(`  p50: ${stats.p50.toFixed(0)}ms`);
    console.log(`  p95: ${stats.p95.toFixed(0)}ms`);
    console.log(`  p99: ${stats.p99.toFixed(0)}ms`);
    console.log(`  avg: ${stats.mean.toFixed(0)}ms`);
    console.log(`  min: ${stats.min.toFixed(0)}ms`);
    console.log(`  max: ${stats.max.toFixed(0)}ms`);

    expect(stats.p50).toBeLessThan(450);
    expect(stats.p95).toBeLessThan(600);
    expect(stats.p99).toBeLessThan(800);
  });

  it('should scale properly with party count', async () => {
    const keygen = new TSSKeyGenerator();
    const configs = [
      { threshold: 2, parties: 3 },
      { threshold: 3, parties: 5 },
      { threshold: 4, parties: 7 },
    ];

    for (const config of configs) {
      const measurements = [];

      for (let i = 0; i < 20; i++) {
        const start = performance.now();
        await keygen.generateKeys(config);
        measurements.push(performance.now() - start);
      }

      const p50 = percentile(measurements, 50);
      console.log(`${config.threshold}-of-${config.parties}: ${p50.toFixed(0)}ms`);
    }

    // 3-of-5 should be < 2x slower than 2-of-3
    // Ensure sub-linear scaling
  });

  it('should benefit from WASM acceleration', async () => {
    const jsKeygen = new TSSKeyGenerator({ useWASM: false });
    const wasmKeygen = new TSSKeyGenerator({ useWASM: true });

    const jsTimes = await benchmarkKeygen(jsKeygen, 10);
    const wasmTimes = await benchmarkKeygen(wasmKeygen, 10);

    const jsP50 = percentile(jsTimes, 50);
    const wasmP50 = percentile(wasmTimes, 50);

    console.log(`JS p50: ${jsP50.toFixed(0)}ms`);
    console.log(`WASM p50: ${wasmP50.toFixed(0)}ms`);
    console.log(`Speedup: ${(jsP50 / wasmP50).toFixed(2)}x`);

    // WASM should be at least 2x faster
    expect(wasmP50).toBeLessThan(jsP50 / 2);
  });
});

async function benchmarkKeygen(keygen: TSSKeyGenerator, iterations: number) {
  const times = [];
  for (let i = 0; i < iterations; i++) {
    const start = performance.now();
    await keygen.generateKeys({ threshold: 2, parties: 3 });
    times.push(performance.now() - start);
  }
  return times;
}
```

### 3.2 TSS Signing Benchmark

```javascript
// benchmarks/crypto/tss-signing.bench.ts
import { TSSSigner } from '../../src/crypto/tss';

describe('TSS Signing Performance', () => {
  let signer: TSSSigner;
  let keyShares: KeyShare[];

  beforeAll(async () => {
    // Pre-generate keys
    const keygen = new TSSKeyGenerator();
    const keys = await keygen.generateKeys({ threshold: 2, parties: 3 });
    keyShares = keys.shares;
    signer = new TSSSigner();
  });

  it('should sign within SLA (500ms p95)', async () => {
    const message = new Uint8Array(32).fill(1);
    const measurements = [];

    for (let i = 0; i < 100; i++) {
      const start = performance.now();

      await signer.sign(message, keyShares.slice(0, 2));

      const duration = performance.now() - start;
      measurements.push(duration);
    }

    const stats = calculateStats(measurements);

    console.log('TSS Signing Results:');
    console.log(`  p50: ${stats.p50.toFixed(0)}ms`);
    console.log(`  p95: ${stats.p95.toFixed(0)}ms`);
    console.log(`  throughput: ${(1000 / stats.mean).toFixed(1)} sigs/sec`);

    expect(stats.p50).toBeLessThan(380);
    expect(stats.p95).toBeLessThan(500);
  });

  it('should measure signing phase breakdown', async () => {
    const message = new Uint8Array(32).fill(1);

    const phases = await signer.signWithPhases(message, keyShares.slice(0, 2));

    console.log('Signing Phase Breakdown:');
    console.log(`  Round 1 (commitment): ${phases.round1}ms`);
    console.log(`  Round 2 (challenge): ${phases.round2}ms`);
    console.log(`  Round 3 (response): ${phases.round3}ms`);
    console.log(`  Aggregation: ${phases.aggregation}ms`);

    // Each phase should meet sub-SLAs
    expect(phases.round1).toBeLessThan(100);
    expect(phases.round2).toBeLessThan(100);
    expect(phases.round3).toBeLessThan(150);
    expect(phases.aggregation).toBeLessThan(80);
  });

  it('should support batch signing', async () => {
    const messages = Array(10).fill(null).map((_, i) =>
      new Uint8Array(32).fill(i)
    );

    const start = performance.now();
    const signatures = await signer.signBatch(messages, keyShares.slice(0, 2));
    const duration = performance.now() - start;

    const avgPerSig = duration / messages.length;

    console.log(`Batch signing: ${duration.toFixed(0)}ms for 10 signatures`);
    console.log(`Average per signature: ${avgPerSig.toFixed(0)}ms`);

    // Batch should be more efficient than individual
    expect(avgPerSig).toBeLessThan(350); // Better than individual
  });
});
```

### 3.3 Key Derivation Benchmark

```javascript
// benchmarks/crypto/key-derivation.bench.ts
import { HDKey } from '../../src/crypto/hd-key';

describe('Key Derivation Performance', () => {
  let masterKey: HDKey;

  beforeAll(async () => {
    const seed = new Uint8Array(64).fill(1);
    masterKey = await HDKey.fromSeed(seed);
  });

  it('should derive keys within SLA (10ms cached)', async () => {
    const paths = [
      "m/44'/60'/0'/0/0",
      "m/44'/60'/0'/0/1",
      "m/44'/60'/0'/0/2",
    ];

    // First pass - uncached
    const uncachedTimes = [];
    for (const path of paths) {
      const start = performance.now();
      await masterKey.derive(path);
      uncachedTimes.push(performance.now() - start);
    }

    // Second pass - cached
    const cachedTimes = [];
    for (const path of paths) {
      const start = performance.now();
      await masterKey.derive(path);
      cachedTimes.push(performance.now() - start);
    }

    const uncachedAvg = average(uncachedTimes);
    const cachedAvg = average(cachedTimes);

    console.log(`Uncached derivation: ${uncachedAvg.toFixed(0)}ms`);
    console.log(`Cached derivation: ${cachedAvg.toFixed(0)}ms`);
    console.log(`Speedup: ${(uncachedAvg / cachedAvg).toFixed(0)}x`);

    expect(cachedAvg).toBeLessThan(10);
    expect(cachedAvg).toBeLessThan(uncachedAvg / 5); // 5x faster cached
  });

  it('should pre-derive common paths efficiently', async () => {
    const commonPaths = [
      "m/44'/60'/0'/0/0",  // ETH
      "m/44'/60'/0'/0/1",
      "m/44'/0'/0'/0/0",   // BTC
      "m/44'/2'/0'/0/0",   // LTC
    ];

    const start = performance.now();
    await masterKey.prederiveCommonPaths(commonPaths);
    const duration = performance.now() - start;

    console.log(`Pre-derivation of 4 paths: ${duration.toFixed(0)}ms`);

    // Parallel derivation should be efficient
    expect(duration).toBeLessThan(400); // 100ms per path on average
  });
});
```

---

## 4. Memory Usage Benchmarks

### 4.1 Transaction History Memory Benchmark

```javascript
// benchmarks/memory/transaction-history.bench.ts
describe('Transaction History Memory Usage', () => {
  it('should load 1000 transactions without exceeding memory limit', async () => {
    const baseline = await getMemoryUsage();

    // Load transaction history
    await loadTransactionHistory('0x123...', 1000);

    const peak = await getMemoryUsage();
    const increase = peak - baseline;

    console.log(`Baseline memory: ${formatBytes(baseline)}`);
    console.log(`Peak memory: ${formatBytes(peak)}`);
    console.log(`Memory increase: ${formatBytes(increase)}`);

    // Should not exceed 50MB for 1000 transactions
    expect(increase).toBeLessThan(50 * 1024 * 1024);
  });

  it('should properly release memory after navigation', async () => {
    const baseline = await getMemoryUsage();

    // Navigate to transaction history
    await navigateTo('TransactionHistory');
    const historyMemory = await getMemoryUsage();

    // Navigate away
    await navigateTo('Home');
    await sleep(2000); // Allow GC

    const afterMemory = await getMemoryUsage();

    const retained = afterMemory - baseline;

    console.log(`Baseline: ${formatBytes(baseline)}`);
    console.log(`With history: ${formatBytes(historyMemory)}`);
    console.log(`After nav: ${formatBytes(afterMemory)}`);
    console.log(`Retained: ${formatBytes(retained)}`);

    // Should release at least 80% of allocated memory
    expect(retained).toBeLessThan((historyMemory - baseline) * 0.2);
  });

  it('should use constant memory with pagination', async () => {
    const measurements = [];

    for (let page = 0; page < 10; page++) {
      await loadTransactionPage(page, 20);
      const memory = await getMemoryUsage();
      measurements.push(memory);

      console.log(`Page ${page}: ${formatBytes(memory)}`);
    }

    // Memory should remain relatively constant
    const firstPage = measurements[0];
    const lastPage = measurements[measurements.length - 1];
    const growth = lastPage - firstPage;

    console.log(`Memory growth over 10 pages: ${formatBytes(growth)}`);

    // Should not grow more than 20MB
    expect(growth).toBeLessThan(20 * 1024 * 1024);
  });
});

async function getMemoryUsage(): Promise<number> {
  if (process.memoryUsage) {
    return process.memoryUsage().heapUsed;
  }
  // For React Native, use native module
  return NativeModules.PerformanceModule.getMemoryUsage();
}
```

### 4.2 Cache Memory Benchmark

```javascript
// benchmarks/memory/cache-memory.bench.ts
describe('Cache Memory Management', () => {
  it('should respect cache size limits', async () => {
    const cache = new BlockchainCache({
      maxSize: 30 * 1024 * 1024, // 30MB
    });

    // Fill cache with data
    for (let i = 0; i < 1000; i++) {
      const blockData = generateMockBlockData(i);
      await cache.set(`block:${i}`, blockData);
    }

    const cacheSize = await cache.getSize();
    console.log(`Cache size: ${formatBytes(cacheSize)}`);

    // Should evict old entries to stay under limit
    expect(cacheSize).toBeLessThan(30 * 1024 * 1024);
  });

  it('should compress cached data effectively', async () => {
    const uncompressedCache = new BlockchainCache({ compress: false });
    const compressedCache = new BlockchainCache({ compress: true });

    const blockData = generateLargeBlockData();

    await uncompressedCache.set('block:1', blockData);
    await compressedCache.set('block:1', blockData);

    const uncompressedSize = await uncompressedCache.getSize();
    const compressedSize = await compressedCache.getSize();

    console.log(`Uncompressed: ${formatBytes(uncompressedSize)}`);
    console.log(`Compressed: ${formatBytes(compressedSize)}`);
    console.log(`Ratio: ${(compressedSize / uncompressedSize).toFixed(2)}`);

    // Should achieve at least 50% compression
    expect(compressedSize).toBeLessThan(uncompressedSize * 0.5);
  });
});
```

---

## 5. Network Performance Benchmarks

### 5.1 Parallel Data Loading Benchmark

```javascript
// benchmarks/network/parallel-loading.bench.ts
describe('Parallel Data Loading Performance', () => {
  it('should load wallet data faster in parallel', async () => {
    const address = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb';

    // Sequential loading
    const seqStart = performance.now();
    const balance = await fetchBalance(address);
    const transactions = await fetchTransactions(address);
    const tokens = await fetchTokenBalances(address);
    const prices = await fetchTokenPrices();
    const seqDuration = performance.now() - seqStart;

    // Parallel loading
    const parStart = performance.now();
    const [balanceP, transactionsP, tokensP, pricesP] = await Promise.all([
      fetchBalance(address),
      fetchTransactions(address),
      fetchTokenBalances(address),
      fetchTokenPrices(),
    ]);
    const parDuration = performance.now() - parStart;

    console.log(`Sequential loading: ${seqDuration.toFixed(0)}ms`);
    console.log(`Parallel loading: ${parDuration.toFixed(0)}ms`);
    console.log(`Speedup: ${(seqDuration / parDuration).toFixed(2)}x`);

    // Parallel should be at least 2x faster
    expect(parDuration).toBeLessThan(seqDuration / 2);
    expect(parDuration).toBeLessThan(900); // p95 SLA
  });
});
```

### 5.2 GraphQL Batching Benchmark

```javascript
// benchmarks/network/graphql-batching.bench.ts
describe('GraphQL Batching Performance', () => {
  it('should reduce requests with batching', async () => {
    const address = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb';

    // Individual REST requests
    let requestCount = 0;
    const restClient = createRESTClient({
      onRequest: () => requestCount++,
    });

    const restStart = performance.now();
    await restClient.getBalance(address);
    await restClient.getTransactions(address);
    await restClient.getTokens(address);
    await restClient.getPrices();
    const restDuration = performance.now() - restStart;

    // Single GraphQL query
    let gqlRequestCount = 0;
    const gqlClient = createGraphQLClient({
      onRequest: () => gqlRequestCount++,
    });

    const gqlStart = performance.now();
    await gqlClient.query(WALLET_DATA_QUERY, { address });
    const gqlDuration = performance.now() - gqlStart;

    console.log(`REST: ${requestCount} requests, ${restDuration.toFixed(0)}ms`);
    console.log(`GraphQL: ${gqlRequestCount} requests, ${gqlDuration.toFixed(0)}ms`);

    expect(gqlRequestCount).toBe(1);
    expect(requestCount).toBeGreaterThan(3);
    expect(gqlDuration).toBeLessThan(restDuration * 0.6); // 40% faster
  });
});
```

### 5.3 WebSocket Performance Benchmark

```javascript
// benchmarks/network/websocket-performance.bench.ts
describe('WebSocket Performance', () => {
  it('should reduce latency vs polling', async () => {
    const address = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb';

    // Polling approach
    const pollingLatencies = [];
    const poller = new PollingService(address, 10000); // 10s interval

    for (let i = 0; i < 10; i++) {
      const start = Date.now();
      await poller.poll();
      const latency = Date.now() - start;
      pollingLatencies.push(latency);
    }

    // WebSocket approach
    const wsLatencies = [];
    const ws = new WebSocketService(address);

    ws.on('update', (timestamp) => {
      const latency = Date.now() - timestamp;
      wsLatencies.push(latency);
    });

    await sleep(100000); // Wait for 10 updates

    const pollingAvg = average(pollingLatencies);
    const wsAvg = average(wsLatencies);

    console.log(`Polling avg latency: ${pollingAvg.toFixed(0)}ms`);
    console.log(`WebSocket avg latency: ${wsAvg.toFixed(0)}ms`);

    // WebSocket should have <100ms latency
    expect(wsAvg).toBeLessThan(100);
    expect(wsAvg).toBeLessThan(pollingAvg / 10);
  });

  it('should reduce bandwidth usage', async () => {
    const address = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb';

    // Measure polling bandwidth
    const pollingBytes = await measureBandwidth(async () => {
      const poller = new PollingService(address, 10000);
      for (let i = 0; i < 6; i++) {
        await poller.poll();
      }
    });

    // Measure WebSocket bandwidth
    const wsBytes = await measureBandwidth(async () => {
      const ws = new WebSocketService(address);
      await sleep(60000); // 1 minute
    });

    console.log(`Polling (1 min): ${formatBytes(pollingBytes)}`);
    console.log(`WebSocket (1 min): ${formatBytes(wsBytes)}`);
    console.log(`Savings: ${(100 - (wsBytes / pollingBytes) * 100).toFixed(0)}%`);

    // WebSocket should use < 10% of polling bandwidth
    expect(wsBytes).toBeLessThan(pollingBytes * 0.1);
  });
});
```

---

## 6. Battery Consumption Benchmarks

### 6.1 Background Activity Benchmark

```javascript
// benchmarks/battery/background-activity.bench.ts
describe('Background Activity Battery Impact', () => {
  it('should minimize background battery drain', async () => {
    // Baseline measurement (no app)
    const baselineDrain = await measureBatteryDrain(60000, async () => {
      // Do nothing
    });

    // Background polling
    const pollingDrain = await measureBatteryDrain(60000, async () => {
      const poller = new PollingService('0x123', 10000);
      // Poll for 1 minute
    });

    // Background WebSocket
    const wsDrain = await measureBatteryDrain(60000, async () => {
      const ws = new WebSocketService('0x123');
      // Keep connection open for 1 minute
    });

    // Optimized background
    const optimizedDrain = await measureBatteryDrain(60000, async () => {
      const bgService = new OptimizedBackgroundService('0x123');
      // Run for 1 minute
    });

    console.log('Battery drain (1 minute background):');
    console.log(`  Baseline: ${baselineDrain.toFixed(2)}%`);
    console.log(`  Polling: ${pollingDrain.toFixed(2)}%`);
    console.log(`  WebSocket: ${wsDrain.toFixed(2)}%`);
    console.log(`  Optimized: ${optimizedDrain.toFixed(2)}%`);

    // Optimized should be close to baseline
    expect(optimizedDrain - baselineDrain).toBeLessThan(0.1); // <0.1% per minute
  });
});
```

---

## 7. Benchmark Utilities

```javascript
// benchmarks/utils/stats.ts
export function calculateStats(measurements: number[]) {
  const sorted = [...measurements].sort((a, b) => a - b);

  return {
    min: sorted[0],
    max: sorted[sorted.length - 1],
    mean: average(measurements),
    median: percentile(measurements, 50),
    p50: percentile(measurements, 50),
    p95: percentile(measurements, 95),
    p99: percentile(measurements, 99),
    stddev: standardDeviation(measurements),
  };
}

export function percentile(arr: number[], p: number): number {
  const sorted = [...arr].sort((a, b) => a - b);
  const index = Math.ceil((sorted.length * p) / 100) - 1;
  return sorted[Math.max(0, index)];
}

export function average(arr: number[]): number {
  return arr.reduce((a, b) => a + b, 0) / arr.length;
}

export function standardDeviation(arr: number[]): number {
  const avg = average(arr);
  const squareDiffs = arr.map(value => Math.pow(value - avg, 2));
  return Math.sqrt(average(squareDiffs));
}

export function formatBytes(bytes: number): string {
  const units = ['B', 'KB', 'MB', 'GB'];
  let size = bytes;
  let unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  return `${size.toFixed(2)} ${units[unitIndex]}`;
}
```

---

## 8. Continuous Benchmarking

### 8.1 CI/CD Integration

```yaml
# .github/workflows/performance-benchmarks.yml
name: Performance Benchmarks

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]
  schedule:
    - cron: '0 0 * * *' # Daily

jobs:
  benchmark:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm ci

      - name: Run benchmarks
        run: npm run benchmark

      - name: Check performance regression
        run: |
          node scripts/check-performance-regression.js \
            --baseline benchmarks/baseline.json \
            --current benchmarks/results.json \
            --threshold 10

      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: benchmark-results
          path: benchmarks/results.json

      - name: Comment PR with results
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            const results = require('./benchmarks/results.json');
            const comment = generateBenchmarkComment(results);
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });
```

### 8.2 Performance Regression Detection

```javascript
// scripts/check-performance-regression.js
const baseline = require('../benchmarks/baseline.json');
const current = require('../benchmarks/results.json');

const REGRESSION_THRESHOLD = 0.10; // 10%

const regressions = [];

for (const [metric, baselineValue] of Object.entries(baseline)) {
  const currentValue = current[metric];

  if (!currentValue) {
    console.warn(`Missing metric: ${metric}`);
    continue;
  }

  const change = (currentValue - baselineValue) / baselineValue;

  if (change > REGRESSION_THRESHOLD) {
    regressions.push({
      metric,
      baseline: baselineValue,
      current: currentValue,
      regression: (change * 100).toFixed(1) + '%',
    });
  }
}

if (regressions.length > 0) {
  console.error('Performance regressions detected:');
  console.table(regressions);
  process.exit(1);
} else {
  console.log('No performance regressions detected.');
}
```

---

## 9. Benchmark Execution

### Run All Benchmarks
```bash
npm run benchmark
```

### Run Specific Category
```bash
npm run benchmark:crypto
npm run benchmark:network
npm run benchmark:memory
npm run benchmark:battery
```

### Generate Baseline
```bash
npm run benchmark:baseline
```

### Compare Against Baseline
```bash
npm run benchmark:compare
```

---

**Document Version**: 1.0
**Last Updated**: 2025-10-21
**Status**: READY FOR IMPLEMENTATION
