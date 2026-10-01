# ============================================================
# modules/waydroid.nix
#
# Waydroid — runs a full Android container (LXC + binder) with Wayland
# integration, so Android-only apps can run as normal windows.
#
# Why: some apps (e.g. LokLok) have no native Linux build and no usable
# web app — Android, iPhone, Windows Store, and TV are the only official
# targets. Waydroid runs the real Android APK instead of relying on Wine,
# which has essentially no support for Windows Store (UWP) apps.
#
# Networking note: Waydroid's container traffic is NAT'd out through the
# host's default route (via the waydroid0 bridge interface) — it does not
# have its own independent network stack. Whatever VPN (e.g. ProtonVPN) is
# active on the host applies to Waydroid automatically; no split-tunnel
# config is needed.
#
# First-time setup (run manually after `nixos-rebuild switch`):
#   sudo waydroid init -s GAPPS     # downloads the Android system image (~1GB)
#   sudo systemctl start waydroid-container
#   waydroid session start
#   waydroid show-full-ui
#
# To install an APK directly (bypassing the Play Store):
#   waydroid app install /path/to/app.apk
#
# waydroid-helper (GUI) can also install APKs, manage extensions
# (clipboard sync, app icon integration), and toggle GApps.
# ============================================================
{ pkgs, ... }:

{
  virtualisation.waydroid.enable = true;

  environment.systemPackages = with pkgs; [
    waydroid-helper
    android-tools  # adb — push files/APKs into the Waydroid container
  ];

  # BUG FIX: waydroid-net.sh shells out to legacy `iptables` to set up the
  # waydroid0 bridge/NAT rules. This kernel does not ship the legacy
  # xtables kernel modules (ip_tables, iptable_filter, iptable_nat,
  # iptable_mangle) — `modprobe ip_tables` fails with "Module not found",
  # and `waydroid session start` dies with a bare RuntimeError.
  #
  # Fix: switch the system's `iptables` binary to the iptables-nft
  # compatibility layer, which translates iptables rules to nftables
  # instead of relying on the (missing) legacy netfilter modules. This
  # also switches how `networking.firewall` implements its rules — NixOS's
  # firewall module supports both backends transparently, so this is safe.
  networking.nftables.enable = true;
}
