# ============================================================
# modules/vpn-hotspot.nix
#
# Goal: turn victus into a WiFi hotspot where every connected device's
# traffic egresses through the ProtonVPN WireGuard tunnel instead of the
# real uplink (Ethernet/eno1) — i.e. clients of the hotspot see the VPN's
# public IP, never victus's real one.
#
# Topology this assumes (confirmed on this machine):
#   eno1 (Ethernet)  — the real uplink to the router/internet.
#   wlo1 (RTL8852BE-VT, built-in WiFi) — dedicated AP-only radio.
#   CAFREE-14        — ProtonVPN WireGuard interface (full-tunnel,
#                       AllowedIPs = 0.0.0.0/0, ::/0).
#
# IMPORTANT: this intentionally does NOT use the internal WiFi card as
# the *uplink*. The rtw89 driver's AP+STA-concurrent mode (broadcasting
# an AP while also being a client on the same radio) is reported flaky/
# hang-prone on RTL8852BE as of kernel 6.14 (github.com/lwfinger/rtw89
# issue #402), and even where it works it's restricted to a single shared
# channel. Keeping wlo1 as AP-only and eno1 as the uplink sidesteps that
# entirely — this is also how the machine is actually wired up today.
#
# How traffic actually ends up going through the VPN:
#   wg-quick's policy routing (started by wg-quick-CAFREE-14.service)
#   installs a fwmark-based ip rule so that everything EXCEPT the
#   WireGuard daemon's own handshake packets is looked up in a routing
#   table whose default route is CAFREE-14. That applies just as much to
#   packets this host is *forwarding* (from hotspot clients) as to the
#   host's own traffic — so once the VPN is up, NetworkManager's hotspot
#   NAT (which doesn't pin an output interface) naturally masquerades out
#   CAFREE-14 instead of eno1.
#
# One-time manual setup (secrets intentionally kept OUT of this repo —
# see the comments below for why):
#
#   1. Move the ProtonVPN WireGuard config out of your home directory
#      (currently world-readable, containing your private key) into
#      /etc/wireguard, root-only:
#        sudo install -d -m 700 /etc/wireguard
#        sudo mv /home/harua/CAFREE-14.conf /etc/wireguard/CAFREE-14.conf
#        sudo chown root:root /etc/wireguard/CAFREE-14.conf
#        sudo chmod 600 /etc/wireguard/CAFREE-14.conf
#
#   2. Create the hotspot connection profile once (stored by
#      NetworkManager under /etc/NetworkManager/system-connections/,
#      which lives outside the Nix store and outside this git repo —
#      putting a WiFi password in a Nix option would commit it to git
#      in plaintext, which we don't want):
#        sudo nmcli device wifi hotspot ifname wlo1 con-name Hotspot \
#          ssid "YOUR_SSID_HERE" password "YOUR_PASSWORD_HERE"
#        sudo nmcli connection modify Hotspot connection.autoconnect no
#      (autoconnect off = you bring it up deliberately, after the VPN,
#      matching the WiFi/Ethernet -> VPN -> hotspot sequence you want.)
#
# Day-to-day usage after that one-time setup:
#   sudo systemctl start wg-quick-CAFREE-14   # 1. bring the VPN up
#   nmcli connection up Hotspot                # 2. start broadcasting
#   ...
#   nmcli connection down Hotspot              # stop the hotspot
#   sudo systemctl stop wg-quick-CAFREE-14     # drop the VPN
# ============================================================
{ pkgs, ... }:

{
  # Declarative, but NOT auto-started (autostart = false): you decide
  # when the VPN comes up, same as the manual `wg-quick up` workflow you
  # already had, except now it's a stable systemd unit
  # (wg-quick-CAFREE-14.service) instead of an ad-hoc command, and the
  # private key lives in /etc/wireguard (root-only) rather than your
  # home directory. wg-quick itself reads configFile straight off disk
  # at service-start time — it is never copied into /nix/store, so the
  # private key never becomes world-readable via the Nix store.
  networking.wg-quick.interfaces."CAFREE-14" = {
    configFile = "/etc/wireguard/CAFREE-14.conf";
    autostart = false;
  };

  # Belt-and-suspenders: NetworkManager's "shared" hotspot method also
  # flips this itself when the hotspot connection activates, but declaring
  # it here means forwarding works even if that behavior ever changes.
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # Let hotspot clients reach this host's DHCP/DNS (NetworkManager runs a
  # dnsmasq instance for "shared" connections) — this is the normal
  # INPUT-chain firewall, unrelated to the forwarding kill-switch below.
  networking.firewall.interfaces."wlo1" = {
    allowedUDPPorts = [ 53 67 ];
    allowedTCPPorts = [ 53 ];
  };

  # ------------------------------------------------------------
  # KILL SWITCH
  #
  # If CAFREE-14 ever goes down (VPN crash, server swap, forgot to start
  # it), the kernel's default route reverts to eno1 — and NetworkManager's
  # hotspot NAT would then happily masquerade hotspot clients' traffic out
  # over eno1, leaking your real IP to anything connected to the hotspot.
  #
  # This rule lives in its own independent nftables table (not inside
  # NixOS's `networking.firewall` table, and `networking.firewall.
  # filterForward` is deliberately left at its default/off) specifically
  # so it can't interact with Docker's, Waydroid's, or Tailscale's own
  # forwarding rules — it only ever inspects packets whose *input*
  # interface is the hotspot radio, wlo1.
  #
  # Effect: wlo1 -> anything-other-than-CAFREE-14 is dropped outright.
  # Hotspot clients simply lose connectivity if the VPN drops, instead of
  # silently falling back to the real uplink.
  # ------------------------------------------------------------
  systemd.services.hotspot-vpn-killswitch = {
    description = "Drop forwarded hotspot (wlo1) traffic that isn't exiting via the ProtonVPN tunnel (CAFREE-14)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-pre.target" ];
    before = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "hotspot-vpn-killswitch-start" ''
        set -e
        ${pkgs.nftables}/bin/nft add table inet hotspot_killswitch
        ${pkgs.nftables}/bin/nft -- add chain inet hotspot_killswitch forward '{ type filter hook forward priority -5 ; policy accept ; }'
        ${pkgs.nftables}/bin/nft flush chain inet hotspot_killswitch forward
        ${pkgs.nftables}/bin/nft add rule inet hotspot_killswitch forward iifname "wlo1" oifname != "CAFREE-14" drop
      '';
      ExecStop = pkgs.writeShellScript "hotspot-vpn-killswitch-stop" ''
        ${pkgs.nftables}/bin/nft delete table inet hotspot_killswitch || true
      '';
    };
  };
}
