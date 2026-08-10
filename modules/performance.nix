# ============================================================
# modules/performance.nix
#
# System-wide performance tuning for the HP Victus laptop.
#
# HOW IT LINKS:
#   Imported by → hosts/victus/configuration.nix
#   No other module imports this file.
#
# WHAT THIS FIXES (confirmed problems found on this machine):
#   1. SwapTotal = 0 kB → NO SWAP at all. When RAM fills the system
#      hard-freezes. zram adds compressed RAM-backed swap instantly.
#   2. irqbalance inactive → all hardware IRQs pile on CPU core 0,
#      creating a bottleneck. irqbalance spreads them across all cores.
#   3. thermald inactive → kernel hard-throttles at thermal limit instead
#      of gently managing heat. Causes clock-speed cliffs under load.
#   4. earlyoom inactive → system freezes for minutes during OOM;
#      earlyoom kills the worst offender fast and keeps the DE alive.
#   5. vm.swappiness = 60 (default, too high with no swap / zram).
#      10 is correct for a desktop with fast storage.
#   6. No inotify tuning → VS Code / cargo-watch / webpack silently
#      stop detecting file changes at the default 8 192 limit.
# ============================================================
{ config, pkgs, lib, ... }:

{
  # ============================================================
  # KERNEL SYSCTL — Runtime Tunable Parameters
  # Applied at boot via /proc/sys.
  # Test any value live with: sudo sysctl -w key=value
  # ============================================================
  boot.kernel.sysctl = {

    # ---- Memory management ----------------------------------------

    # How aggressively the kernel moves anonymous pages to swap.
    # 10 = only start swapping when ~90 % of RAM is occupied.
    # Default 60 is calibrated for slow spinning-disk swap; with fast
    # zram we want to keep pages in RAM as long as possible.
    "vm.swappiness" = 10;

    # Dirty-page writeback thresholds (% of total RAM).
    # "Dirty" pages are modified in RAM but not yet flushed to disk.
    # dirty_ratio:            hard limit — new writes BLOCK until below this.
    # dirty_background_ratio: soft limit — background writeback starts here.
    # 10/5 % is a good SSD balance; defaults are 20/10 % (tuned for HDDs).
    "vm.dirty_ratio"            = 10;
    "vm.dirty_background_ratio" = 5;

    # Inode/dentry (filesystem metadata) cache pressure.
    # Default 100: kernel aggressively evicts cached directory entries.
    # 50: kernel prefers to keep recently-used metadata cached longer.
    # Makes repeated `ls`, `find`, and editor file-tree scanning faster.
    "vm.vfs_cache_pressure" = 50;

    # ---- File descriptors and inotify ----------------------------

    # VS Code, IntelliJ, cargo-watch, webpack dev-server, and even Niri
    # itself watch files via inotify. The kernel default (8 192 watches
    # per user) is hit instantly on large projects and causes silent
    # failures where the editor stops detecting file changes with no error.
    "fs.inotify.max_user_watches"   = 524288; # 512 K watches — enough for any project
    "fs.inotify.max_user_instances" = 512;    # max concurrent inotify fd objects
    "fs.inotify.max_queued_events"  = 32768;  # event queue depth before drops

    # ---- Network --------------------------------------------------

    # TCP Fast Open — sends data in the SYN packet on repeat connections
    # to servers that support it. Reduces handshake latency for browsers,
    # curl, package managers, etc.
    # 3 = enable for both outgoing (client) and incoming (server) roles.
    "net.ipv4.tcp_fastopen" = 3;

    # Maximum socket buffer sizes. Apps request what they need up to this.
    # Larger buffers improve throughput on fast LAN/NAS connections.
    "net.core.rmem_max" = 16777216; # 16 MiB receive buffer ceiling
    "net.core.wmem_max" = 16777216; # 16 MiB send buffer ceiling

    # Incoming-packet backlog before the kernel drops packets.
    # Helps under short bursts of high-rate traffic.
    "net.core.netdev_max_backlog" = 16384;
  };

  # ============================================================
  # ZRAM SWAP — Compressed RAM-Backed Swap Device
  # ============================================================
  # zram creates an in-kernel block device that compresses pages
  # before storing them inside a reserved portion of physical RAM.
  #
  # Why this machine MUST have it (24 GB RAM, 0 disk swap):
  #   Without any swap, when RAM fills up the kernel enters a hard OOM
  #   state. It freezes for up to 60 s trying to reclaim pages, then
  #   starts killing random processes. This is the most likely cause of
  #   the "something feels off / freezes" symptom.
  #
  # With zram enabled:
  #   - Inactive pages are compressed (~2–3× with zstd) and kept in RAM.
  #   - 24 GB × 25 % = 6 GB zram device ≈ 12–18 GB worth of pages stored.
  #   - Access latency is nanoseconds (RAM), not milliseconds (disk).
  #   - earlyoom still fires before the zram fills completely.
  zramSwap = {
    enable = true;

    # zstd: best compression ratio for swap workloads. Inactive pages
    # (cold code, heap) compress extremely well (often 3–4×).
    # lz4 is ~30 % faster to decompress but gives ~30 % less ratio.
    # For swap (accessed rarely) zstd's space savings are worth it.
    algorithm = "zstd";

    # Reserve 25 % of physical RAM for the zram device.
    # 24 GB × 25 % = 6 GB zram @ ~2.5× avg → ~15 GB of effective swap.
    # Raise to 50 % if you regularly compile + run heavy browser + Docker.
    memoryPercent = 25;
  };

  # ============================================================
  # EARLYOOM — Proactive Out-of-Memory Handler
  # ============================================================
  # The kernel OOM killer only fires after the system is already
  # completely stuck — typically 30–60 s of total unresponsiveness.
  # earlyoom polls /proc/meminfo every second and kills the single
  # highest oom_score process the moment BOTH thresholds are crossed.
  # The desktop stays alive throughout; you lose one process, not the session.
  services.earlyoom = {
    enable = true;

    # Kill when BOTH conditions are true simultaneously:
    #   free RAM  < 5 % of total RAM  → < ~1.2 GB on this 24 GB machine
    #   free swap < 5 % of total swap → < ~300 MB of the 6 GB zram device
    # earlyoom picks the process with the highest oom_score (most RAM used,
    # lowest user-configured priority) as the victim.
    freeMemThreshold  = 5;
    freeSwapThreshold = 5;

    # Send a D-Bus desktop notification before killing the process.
    # Shows up in Noctalia's notification center so you know what was OOM-killed.
    enableNotifications = true;
  };

  # ============================================================
  # SSD TRIM — Periodic Block Reclamation
  # ============================================================
  # TRIM tells the SSD's firmware which logical blocks are now free
  # (after file deletions). The firmware uses this to pre-erase blocks,
  # keeping future write performance high. Without TRIM, SSDs degrade
  # over months as they run out of pre-erased blocks and must
  # erase-then-write instead of just writing.
  services.fstrim = {
    enable   = true;
    interval = "weekly"; # Low overhead; weekly is plenty for typical laptop use
  };

  # ============================================================
  # IRQBALANCE — Distribute Hardware Interrupts Across CPU Cores
  # ============================================================
  # Every hardware event (NVMe DMA complete, WiFi packet received, GPU
  # interrupt, USB, timer tick) raises an IRQ that must be serviced by
  # a CPU core. Without irqbalance, ALL IRQs default to core 0 — making
  # it a hotspot while cores 1–11 sit idle during I/O-heavy work.
  # irqbalance polls every 10 s and migrates IRQs to underused cores.
  services.irqbalance.enable = true;

  # ============================================================
  # THERMALD — Intel Thermal Management Daemon
  # ============================================================
  # thermald reads Intel DPTF (Dynamic Platform and Thermal Framework)
  # thermal tables and applies GRADUATED power-limit reductions before
  # temperatures reach the point where the kernel's emergency p-state
  # reduction fires. Without thermald, the kernel's response is binary:
  # "fine → emergency throttle at -50 % clock". With thermald the
  # response is smooth: "-5 % at 85 °C → -10 % at 88 °C → -20 % …"
  # Result: more stable sustained clocks, less fan noise, no cliff.
  services.thermald.enable = true;

  # ============================================================
  # I/O SCHEDULER — Block Device Queue Algorithm
  # ============================================================
  # The I/O scheduler orders and batches disk requests before they
  # reach the hardware. The best algorithm depends heavily on device type.
  #
  # Current hardware on this machine:
  #   nvme0n1 — NVMe SSD → "none"
  #     NVMe drives have 64 000-entry internal queues and controller-level
  #     ordering. A software scheduler is pure overhead. Skip it.
  #   sda — SATA/USB SSD → "mq-deadline"
  #     Deadline per request prevents any I/O from being starved.
  #     Better than cfq for flash because it skips rotational optimisation.
  #
  # lib.mkAfter ensures these rules are appended AFTER any other udev
  # rules (e.g., the WiFi power rules in configuration.nix) so they
  # take precedence on conflicting device patterns.
  services.udev.extraRules = lib.mkAfter ''
    # NVMe: bypass the software scheduler entirely
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
    # SATA/USB SSD (rotational=0): deadline — no starvation, minimal overhead
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
    # Spinning HDD (rotational=1): BFQ — interactive-first fair queueing
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
  '';

  # ============================================================
  # BOOT KERNEL PARAMETERS — Additional Low-Level Tweaks
  # ============================================================
  boot.kernelParams = [
    # Transparent Huge Pages: "madvise" — allocate 2 MB pages only when
    # an app explicitly requests them via madvise(MADV_HUGEPAGE).
    # "always" wastes RAM on apps that don't benefit. "madvise" gives the
    # speedup (databases, JVMs, game engines benefit greatly) without waste.
    "transparent_hugepage=madvise"

    # Disable the PS/2 i8042 keyboard controller probe.
    # HP Victus uses USB/HID input only — the PS/2 probe at boot adds a
    # ~50 ms delay and sometimes generates spurious IRQ warnings in dmesg.
    "i8042.nopnp"
    "i8042.nomux"
  ];

  # ============================================================
  # PACKAGES — Performance Monitoring and Analysis Tools
  # ============================================================
  environment.systemPackages = with pkgs; [
    # TUI: stress-test CPU while watching freq/temp/power graph in real time.
    # Usage: s-tui
    s-tui

    # Intel power consumption analyser — identifies what is waking the
    # CPU from sleep states and which drivers block low-power C-states.
    # Usage: sudo powertop
    #   --auto-tune flag applies all suggested tunings temporarily (test first).
    powertop

    # General stress-test: CPU, RAM, I/O, network, atomic ops, etc.
    # Useful for verifying thermald+irqbalance work under load.
    # Usage: stress-ng --cpu 0 --timeout 60s
    stress-ng

    # Per-process disk I/O monitor — like top but for storage.
    # Shows which process is hammering the SSD right now.
    # Usage: sudo iotop -o
    iotop

    # Read raw DMI/SMBIOS hardware tables: RAM type, speed, slot count,
    # BIOS version, chassis info, CPU socket.
    # Usage: sudo dmidecode -t memory
    dmidecode

    # Hard disk parameter query and raw throughput benchmark.
    # Usage: sudo hdparm -tT /dev/nvme0n1
    hdparm
  ];
}
