# 🎯 Performance Engineering Guide

## Critical Performance Principles

### 1. Measurement First
```bash
# Profile before optimizing
perf record -g ./your_app
perf report

# Generate flamegraph
perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg

# Find hot functions
perf top
```

### 2. The Performance Hierarchy

```
1. ALGORITHM COMPLEXITY    (1000x impact)
   - O(1) vs O(n) vs O(n²)
   - Hash table vs Linear search
   
2. DATA LOCALITY          (100x impact)
   - Cache hits vs cache misses
   - Sequential vs random access
   
3. LOCK-FREE             (10x impact)
   - No mutex contention
   - Atomic operations
   
4. SIMD                  (8x impact)
   - Process 8-64 items at once
   - Vectorized operations
   
5. ZERO-COPY             (5x impact)
   - No memcpy
   - Shared memory
   
6. COMPILER              (2x impact)
   - Inlining
   - Loop unrolling
   - PGO (Profile-Guided Optimization)
   
7. LANGUAGE              (1.5x impact)
   - C++ vs Rust vs Go
```

---

## 🚀 Rust Performance Tuning

### Cargo.toml Optimizations

```toml
[profile.release]
opt-level = 3              # Maximum optimization
lto = "fat"                # Link-time optimization (whole program)
codegen-units = 1          # Better optimization (slower compile)
strip = true               # Remove debug symbols
panic = "abort"            # Smaller binary, faster unwinding

# Profile-Guided Optimization (PGO)
[profile.pgo-generate]
inherits = "release"
debug = true

[profile.pgo-use]
inherits = "release"
```

### Build Commands

```bash
# Standard release build
cargo build --release

# PGO (2-stage build)
# Step 1: Generate profile data
RUSTFLAGS="-Cprofile-generate=/tmp/pgo-data" cargo build --release
./target/release/your_app  # Run with typical workload
llvm-profdata merge -o /tmp/pgo-data/merged.profdata /tmp/pgo-data

# Step 2: Use profile data
RUSTFLAGS="-Cprofile-use=/tmp/pgo-data/merged.profdata" cargo build --release

# Target-specific optimizations
RUSTFLAGS="-C target-cpu=native" cargo build --release

# Ultra-aggressive (risky - test thoroughly)
RUSTFLAGS="-C target-cpu=native -C opt-level=3 -C lto=fat -C embed-bitcode=yes" \
  cargo build --release
```

### Global Allocator

```rust
// src/main.rs or lib.rs

// Option 1: mimalloc (FASTEST)
use mimalloc::MiMalloc;
#[global_allocator]
static GLOBAL: MiMalloc = MiMalloc;

// Option 2: jemalloc (Good for fragmentation)
// use tikv_jemallocator::Jemalloc;
// #[global_allocator]
// static GLOBAL: Jemalloc = Jemalloc;
```

### Hot Path Optimization

```rust
// 1. Inline aggressively
#[inline(always)]
fn hot_function() { }

// 2. Branch prediction hints
#[cold]
fn error_path() { }

#[inline]
fn likely_true(x: bool) -> bool {
    if x { true } else { false }
}

// 3. Cache line alignment
#[repr(align(64))]
struct CacheLineAligned {
    data: [u8; 64],
}

// 4. Prefetching
use std::arch::x86_64::*;
unsafe {
    _mm_prefetch(ptr as *const i8, _MM_HINT_T0);
}

// 5. SIMD
use std::simd::*;
fn add_arrays(a: &[f32], b: &[f32]) -> Vec<f32> {
    a.chunks_exact(8)
        .zip(b.chunks_exact(8))
        .flat_map(|(a_chunk, b_chunk)| {
            let va = f32x8::from_slice(a_chunk);
            let vb = f32x8::from_slice(b_chunk);
            (va + vb).to_array()
        })
        .collect()
}
```

---

## 💾 Memory Optimization

### Reduce Allocations

```rust
// ❌ BAD: Allocates on every call
fn process_data(input: &str) -> String {
    format!("Processed: {}", input)
}

// ✅ GOOD: Reuse buffer
fn process_data(input: &str, output: &mut String) {
    output.clear();
    output.push_str("Processed: ");
    output.push_str(input);
}

// ✅ BETTER: Use stack or static
use arrayvec::ArrayString;
fn process_data(input: &str) -> ArrayString<128> {
    let mut s = ArrayString::new();
    s.push_str("Processed: ");
    s.push_str(input);
    s
}
```

### Object Pooling

```rust
use deadpool::managed::Pool;

// Reuse expensive objects
struct ConnectionPool {
    pool: Pool<DatabaseConnection>,
}

impl ConnectionPool {
    async fn get(&self) -> Connection {
        self.pool.get().await.unwrap()
    }
}
```

### Arena Allocation

```rust
use bumpalo::Bump;

fn process_requests(requests: &[Request]) {
    let arena = Bump::new();
    
    for req in requests {
        // All allocations from arena
        let data = arena.alloc_slice_fill_copy(1024, 0u8);
        process(data);
        // No individual frees needed
    }
    // Everything freed at once
}
```

---

## 🔐 Lock-Free Programming

### Atomic Operations

```rust
use std::sync::atomic::{AtomicU64, Ordering};

static COUNTER: AtomicU64 = AtomicU64::new(0);

// Increment counter (lock-free)
COUNTER.fetch_add(1, Ordering::Relaxed);

// Compare-and-swap
let mut current = COUNTER.load(Ordering::Acquire);
loop {
    let new = current + 1;
    match COUNTER.compare_exchange_weak(
        current,
        new,
        Ordering::Release,
        Ordering::Acquire,
    ) {
        Ok(_) => break,
        Err(x) => current = x,
    }
}
```

### Lock-Free Data Structures

```rust
use crossbeam::queue::ArrayQueue;

// Lock-free queue
let queue = ArrayQueue::new(1000);

// Producer
queue.push(item).ok();

// Consumer
if let Some(item) = queue.pop() {
    process(item);
}
```

### ArcSwap Pattern

```rust
use arc_swap::ArcSwap;
use std::sync::Arc;

struct Config {
    data: String,
}

static CONFIG: ArcSwap<Config> = ArcSwap::from_pointee(Config {
    data: String::new(),
});

// Read (lock-free)
let config = CONFIG.load();
println!("{}", config.data);

// Update (lock-free for readers)
CONFIG.store(Arc::new(Config {
    data: "new config".to_string(),
}));
```

---

## 🌐 Network Performance

### TCP Tuning

```bash
# /etc/sysctl.conf

# TCP Buffer sizes (16MB)
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# TCP Fast Open
net.ipv4.tcp_fastopen = 3

# BBR Congestion Control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Connection tracking
net.netfilter.nf_conntrack_max = 1048576
net.nf_conntrack_max = 1048576

# Backlog
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535

# Port range
net.ipv4.ip_local_port_range = 1024 65535

# Reuse sockets
net.ipv4.tcp_tw_reuse = 1

# Apply changes
sudo sysctl -p
```

### NIC Tuning

```bash
# Ring buffer size (max)
sudo ethtool -G eth0 rx 4096 tx 4096

# Enable all offloading
sudo ethtool -K eth0 tso on gso on gro on
sudo ethtool -K eth0 rx-checksumming on tx-checksumming on

# RSS (Receive Side Scaling)
sudo ethtool -L eth0 combined 16  # Match CPU cores

# Check stats
ethtool -S eth0 | grep -E 'error|drop'
```

### io_uring Configuration

```rust
use glommio::prelude::*;

fn main() {
    LocalExecutorBuilder::default()
        .ring_depth(4096)  // Larger ring = more batching
        .preempt_timer(Duration::from_millis(1))
        .spawn(|| async move {
            // Your async code
        })
        .unwrap()
        .join()
        .unwrap();
}
```

---

## 💽 Disk I/O Performance

### Filesystem & Mount Options

```bash
# Use XFS (better than ext4 for databases)
mkfs.xfs -f -d su=64k,sw=4 /dev/nvme0n1

# Mount with performance options
mount -t xfs -o noatime,nodiratime,discard,largeio,swalloc /dev/nvme0n1 /data

# /etc/fstab entry
/dev/nvme0n1 /data xfs noatime,nodiratime,discard,largeio 0 0
```

### I/O Scheduler

```bash
# For NVMe, use none
echo none > /sys/block/nvme0n1/queue/scheduler

# Or set in /etc/default/grub
GRUB_CMDLINE_LINUX="elevator=none"

# Update grub
sudo update-grub
```

### Direct I/O

```rust
use std::fs::OpenOptions;
use std::os::unix::fs::OpenOptionsExt;

let file = OpenOptions::new()
    .read(true)
    .write(true)
    .custom_flags(libc::O_DIRECT)  // Bypass page cache
    .open("data.bin")?;
```

---

## 🧮 CPU Optimization

### CPU Affinity

```bash
# Pin process to CPUs 0-15
taskset -c 0-15 ./your_app

# Or in Rust
use core_affinity;

fn main() {
    let core_ids = core_affinity::get_core_ids().unwrap();
    
    for (i, core_id) in core_ids.iter().enumerate() {
        std::thread::spawn(move || {
            core_affinity::set_for_current(core_id);
            // Thread now pinned to specific core
        });
    }
}
```

### Huge Pages

```bash
# Enable transparent huge pages
echo always > /sys/kernel/mm/transparent_hugepage/enabled
echo always > /sys/kernel/mm/transparent_hugepage/defrag

# For explicit huge pages (2MB)
echo 1024 > /proc/sys/vm/nr_hugepages  # 2GB of huge pages

# For 1GB pages
echo 4 > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
```

### CPU Governor

```bash
# Set to performance mode
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > $cpu
done

# Disable C-States (prevent CPU sleep)
for cpu in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
    echo 1 > $cpu
done
```

---

## 📊 Benchmarking Best Practices

### Micro-benchmarks with Criterion

```rust
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn fibonacci(n: u64) -> u64 {
    match n {
        0 => 1,
        1 => 1,
        n => fibonacci(n-1) + fibonacci(n-2),
    }
}

fn criterion_benchmark(c: &mut Criterion) {
    c.bench_function("fib 20", |b| {
        b.iter(|| fibonacci(black_box(20)))
    });
}

criterion_group!(benches, criterion_benchmark);
criterion_main!(benches);
```

### Load Testing

```bash
# wrk2 - constant throughput load testing
wrk2 -t8 -c400 -d30s -R10000 --latency http://localhost:8080/

# vegeta - versatile load testing
echo "GET http://localhost:8080/" | \
    vegeta attack -rate=10000 -duration=30s | \
    vegeta report

# bombardier - fast HTTP benchmarking
bombardier -c 400 -n 1000000 -l http://localhost:8080/
```

---

## 🔍 Profiling

### CPU Profiling

```bash
# perf (Linux)
perf record -g -F 999 ./your_app
perf report

# Flamegraph
perf record -g -F 999 ./your_app
perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg

# In Rust with pprof
# [dependencies]
# pprof = { version = "0.13", features = ["flamegraph", "criterion"] }
```

### Memory Profiling

```bash
# Valgrind massif
valgrind --tool=massif ./your_app
ms_print massif.out.*

# heaptrack
heaptrack ./your_app
heaptrack_gui heaptrack.your_app.*.gz

# DHAT (cache profiling)
valgrind --tool=dhat ./your_app
```

### In Production

```rust
// Use pprof crate for live profiling
use pprof::ProfilerGuard;

let guard = ProfilerGuard::new(100).unwrap();

// Run your code

if let Ok(report) = guard.report().build() {
    let file = std::fs::File::create("flamegraph.svg").unwrap();
    report.flamegraph(file).unwrap();
}
```

---

## 🎯 Performance Checklist

### Before Deploying:

```
✅ Profile with perf/flamegraph
✅ Run load tests (wrk2/vegeta)
✅ Check memory leaks (valgrind/heaptrack)
✅ Measure p99/p99.9 latency
✅ Enable PGO (Profile-Guided Optimization)
✅ Set correct allocator (mimalloc)
✅ Tune TCP stack
✅ Tune NIC (ring buffers, offloading)
✅ Pin to NUMA nodes
✅ Enable huge pages
✅ Set CPU governor to performance
✅ Disable C-States
✅ Use io_uring for disk I/O
✅ Verify zero lock contention (perf lock)
✅ Check cache miss rate (perf stat)
```

---

## 🏆 Performance Tips Summary

1. **Measure first** - Don't guess, profile
2. **Algorithm > everything** - O(1) beats optimized O(n)
3. **Cache locality** - Sequential > random access
4. **Lock-free** - Atomics > mutexes
5. **Zero-copy** - Avoid memcpy
6. **Inline hot paths** - #[inline(always)]
7. **SIMD** - Process multiple items
8. **Huge pages** - Reduce TLB misses
9. **CPU pinning** - Better cache utilization
10. **PGO** - Profile-guided optimization

**Remember**: Premature optimization is the root of all evil, but targeted optimization based on profiling data is essential for high-performance systems.
