# ============================================================
# modules/gpu-switch.nix
#
# GPU mode management and switching for the HP Victus laptop.
# Hardware: Intel UHD Graphics (iGPU) + NVIDIA RTX 4050 (dGPU)
#
# HOW IT LINKS:
#   Imported by → hosts/victus/configuration.nix
#   Works alongside → modules/nvidia.nix (which sets the active mode)
#
# THREE GPU MODES — HOW TO SWITCH:
# ─────────────────────────────────
#
# MODE 1 — NVIDIA PRIME SYNC (current default, set in nvidia.nix)
#   NVIDIA renders ALL frames. Intel handles only the display output.
#   Both GPUs are always powered on. Best performance, worst battery.
#   Config in nvidia.nix: prime.sync.enable = true
#   Reboot required after switching.
#
# MODE 2 — NVIDIA PRIME OFFLOAD (hybrid — recommended for daily use)
#   Intel iGPU runs the entire desktop. NVIDIA powers on only when you
#   explicitly launch an app with `nvidia-run <app>`.
#   Better battery; desktop latency identical to Intel-only.
#   Config in nvidia.nix: prime.sync.enable = false;
#                          prime.offload.enable = true;
#                          prime.offload.enableOffloadCmd = true;
#   Also provided as the `nvidia-run` wrapper below.
#
# MODE 3 — INTEL ONLY (maximum battery life)
#   NVIDIA GPU is completely disabled. Only Intel iGPU runs.
#   Best for travel/battery. Cannot run CUDA or NVIDIA-only apps.
#   Config in nvidia.nix: comment out all prime.* options,
#   remove "nvidia" from services.xserver.videoDrivers,
#   set hardware.nvidia.modesetting.enable = false.
#
# QUICK SWITCH TOOL — envycontrol:
#   `sudo envycontrol --switch integrated` → Intel only (then reboot)
#   `sudo envycontrol --switch hybrid`     → PRIME Offload mode
#   `sudo envycontrol --switch nvidia`     → Full NVIDIA (current)
#   `sudo envycontrol --query`             → Show current mode
#
#   WARNING on NixOS: envycontrol writes to /etc/X11/xorg.conf.d/ and
#   /lib/modprobe.d/ which may be overwritten by the next nixos-rebuild.
#   For permanent mode changes, update nvidia.nix and rebuild instead.
#   envycontrol is still useful for TESTING a mode before committing it.
# ============================================================
{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [

    # ============================================================
    # ENVYCONTROL — GPU Mode Switcher
    # ============================================================
    # envycontrol is NOT packaged in nixpkgs 26.05. Install it manually:
    #   pip install envycontrol          (system Python)
    #   nix shell nixpkgs#python3 -c pip install envycontrol
    #
    # Once installed, usage:
    #   sudo envycontrol --switch integrated   # Intel iGPU only
    #   sudo envycontrol --switch hybrid       # PRIME Offload mode
    #   sudo envycontrol --switch nvidia       # Full NVIDIA (current mode)
    #   sudo envycontrol --query               # Show current mode
    # Requires a reboot to take effect.
    # NOTE: On NixOS, envycontrol writes to /etc/X11/xorg.conf.d/ which
    # nixos-rebuild may overwrite. See the MODE SWITCHING NOTES section below
    # for the proper NixOS way to switch GPU modes.

    # ============================================================
    # GPU MONITORING
    # ============================================================
    # nvtop: combined NVIDIA + Intel GPU usage in one TUI view.
    # Shows utilization %, VRAM usage, temperature, power draw per GPU.
    # Usage: nvtop
    nvtopPackages.full

    # OpenGL info and quick render test.
    # mesa-demos provides both `glxinfo` and `glxgears` (glxinfo was merged into it).
    mesa-demos

    # ============================================================
    # WRAPPER SCRIPTS — Per-App GPU Selection
    # ============================================================

    # nvidia-run: launch any app on the NVIDIA GPU explicitly.
    # Works in PRIME Offload / Hybrid mode. In PRIME Sync mode the NVIDIA
    # GPU already renders everything, but the vars still work as a test.
    #
    # Usage:
    #   nvidia-run glxinfo | grep "OpenGL renderer"   # confirm NVIDIA active
    #   nvidia-run steam                               # run Steam on NVIDIA
    #   nvidia-run blender                             # GPU rendering on NVIDIA
    #   nvidia-run %command%                           # Steam launch option
    (writeShellScriptBin "nvidia-run" ''
      # These four environment variables tell the NVIDIA driver + Mesa loader
      # to use the NVIDIA GPU for this process instead of the iGPU default.
      export __NV_PRIME_RENDER_OFFLOAD=1
      export __NV_PRIME_RENDER_OFFLOAD_PROVIDER="NVIDIA-G0"
      export __GLX_VENDOR_LIBRARY_NAME="nvidia"
      export __VK_LAYER_NV_optimus="NVIDIA_only"
      exec "$@"
    '')

    # intel-run: force a command to use the Intel iGPU.
    # Useful when in full PRIME Sync (NVIDIA always-on) mode and you want
    # to test an app on Intel — e.g. to check battery impact or compatibility.
    #
    # Usage:
    #   intel-run glxinfo | grep "OpenGL renderer"   # confirm Intel active
    #   intel-run mpv video.mkv                       # watch video on iGPU (saves power)
    (writeShellScriptBin "intel-run" ''
      # Clear any NVIDIA offload vars so Mesa picks the Intel/modesetting driver.
      unset __NV_PRIME_RENDER_OFFLOAD
      unset __NV_PRIME_RENDER_OFFLOAD_PROVIDER
      unset __GLX_VENDOR_LIBRARY_NAME
      unset __VK_LAYER_NV_optimus
      # DRI_PRIME=0 explicitly selects the first DRM device (Intel iGPU).
      export DRI_PRIME=0
      exec "$@"
    '')

    # gpu-info: show a summary of both GPUs, active renderer, and current mode.
    # Usage: gpu-info
    (writeShellScriptBin "gpu-info" ''
      echo "╔══════════════════════════════════════╗"
      echo "║           GPU STATUS REPORT          ║"
      echo "╚══════════════════════════════════════╝"
      echo ""

      echo "── PCI Devices ─────────────────────────"
      ${pciutils}/bin/lspci | grep -E "VGA|3D|Display"
      echo ""

      echo "── NVIDIA GPU (nvidia-smi) ─────────────"
      if command -v nvidia-smi &>/dev/null; then
        nvidia-smi \
          --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw \
          --format=csv,noheader,nounits \
          | awk -F',' '{
              printf "  Name:        %s\n", $1
              printf "  GPU Usage:   %s%%\n", $2
              printf "  VRAM Used:   %s / %s MiB\n", $3, $4
              printf "  Temperature: %s°C\n", $5
              printf "  Power Draw:  %s W\n", $6
            }'
      else
        echo "  nvidia-smi not in PATH"
      fi
      echo ""

      echo "── OpenGL Renderer (current session) ───"
      # Shows which GPU is actually rendering for this user session.
      # glxinfo is provided by the mesa-demos package.
      glxinfo 2>/dev/null | grep -E "OpenGL renderer|OpenGL version" \
        | sed 's/^/  /' \
        || echo "  glxinfo unavailable (need a display)"
      echo ""

      echo "── envycontrol mode ────────────────────"
      # envycontrol is not in nixpkgs 26.05 — install via pip to use this.
      if command -v envycontrol &>/dev/null; then
        envycontrol --query 2>/dev/null | sed 's/^/  /'
      else
        echo "  (not installed — run: pip install envycontrol)"
      fi
      echo ""

      echo "── DRM Devices ─────────────────────────"
      ls -la /dev/dri/ 2>/dev/null | sed 's/^/  /'
    '')
  ];

  # ============================================================
  # NVIDIA POWER MANAGEMENT (Fine-Grained in Offload Mode)
  # ============================================================
  # When running in PRIME Offload / Hybrid mode, this allows the NVIDIA
  # GPU to fully power down (RTD3 runtime power management) when no app
  # is using it. The RTX 4050 can draw 0–1 W when powered down vs.
  # 15–30 W at idle in PRIME Sync mode.
  #
  # ONLY enable these lines if you switch to PRIME Offload mode.
  # In PRIME Sync mode they have no effect and cause a log warning.
  #
  # hardware.nvidia.powerManagement.enable = true;
  # hardware.nvidia.powerManagement.finegrained = true;

  # ============================================================
  # NOTES FOR SWITCHING MODES
  # ============================================================
  # To switch from PRIME Sync (current) to PRIME Offload (hybrid):
  #
  # 1. In modules/nvidia.nix change:
  #      prime.sync.enable = false;
  #      prime.offload.enable = true;
  #      prime.offload.enableOffloadCmd = true;
  #
  # 2. Uncomment the two powerManagement lines above for battery savings.
  #
  # 3. Rebuild and reboot:
  #      sudo nixos-rebuild switch --flake /etc/nixos#victus
  #
  # 4. After reboot, use `nvidia-run <app>` to run on NVIDIA.
  #    The desktop runs on Intel by default (better battery life).
  #
  # To switch to Intel-only mode (no NVIDIA):
  # 1. In modules/nvidia.nix comment out all of hardware.nvidia.*
  #    and remove "nvidia" from services.xserver.videoDrivers.
  # 2. Remove NVIDIA-specific env vars from nnn.nix (GBM_BACKEND etc.)
  # 3. Rebuild and reboot.
}
