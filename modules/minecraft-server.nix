# ============================================================
# modules/minecraft-server.nix
#
# Minecraft server: modded (Fabric/Forge), exposed to the internet.
#
# WHY NOT services.minecraft-server:
#   That NixOS module only runs a single vanilla server.jar pinned in
#   the config — changing version/loader means editing Nix and
#   rebuilding. Haru wants launcher-like flexibility: swap Fabric/Forge
#   version whenever, drop mods in a folder, restart. So this module
#   only declares the PLUMBING (system user, firewall, JDKs, process
#   supervision) and leaves server.jar / mods/ / world data as plain
#   files the user manages by hand in /var/lib/minecraft, exactly like
#   running a server on any Linux box.
#
# ONE-TIME SETUP (after `rebuild`):
#   cd /var/lib/minecraft
#   sudo -u minecraft fabric-installer server -downloadMinecraft
#     → SHOULD produce fabric-server-launch.jar + server.jar (the plain
#       vanilla game jar, required literally under that name — see
#       fabric-server-launcher.properties' serverJar= key). In practice
#       nixpkgs' fabric-installer 1.1.1 -downloadMinecraft silently
#       failed to write server.jar (confirmed live 2026-10-09) — if `ls`
#       shows fabric-server-launch.jar but no server.jar, fetch it
#       straight from Mojang instead:
#         curl -s https://piston-meta.mojang.com/mc/game/version_manifest_v2.json \
#           | jq -r '.versions[] | select(.id=="<mcversion>") | .url' \
#           | xargs curl -s | jq -r '.downloads.server.url' \
#           | xargs sudo -u minecraft curl -o /var/lib/minecraft/server.jar
#   # drop mod jars into /var/lib/minecraft/mods/
#   sudo systemctl restart minecraft-server
#
#   For Forge: download the installer from files.minecraftforge.net,
#   `sudo -u minecraft java -jar forge-installer.jar --installServer`,
#   which produces its own run script/jar — start.sh below auto-detects
#   fabric-server-launch.jar vs plain server.jar, so for Forge either
#   symlink its launch jar to a name start.sh checks, or edit start.sh
#   directly (it's never touched by Nix again once it exists).
#
# SWITCHING VERSION/LOADER LATER: just repeat the steps above in the
# same directory (or a subdirectory per modpack) — no Nix rebuild needed.
#
# JAVA VERSION: MC needs different JDKs by version (8 for <=1.16, 17
# for 1.17-1.20.4, 21 for 1.20.5-ish, 25 for the current 26.x releases —
# confirmed live 2026-10-09: MC 26.3's server.jar is class file version
# 69, which only Java 25 (class version 69) runs; Java 21 (max 65)
# throws UnsupportedClassVersionError). /var/lib/minecraft/start.sh
# (seeded once below, never overwritten again) picks java25 by default —
# edit the JAVA= line there when running an older modpack.
{ config, pkgs, ... }:

let
  # Named java8/java17/java21 commands on PATH, so start.sh (which lives
  # in /var/lib/minecraft and is never touched by Nix again after it's
  # first written) can pick one by name instead of a store path that
  # would go stale on the next `nix flake update`.
  java8  = pkgs.writeShellScriptBin "java8"  ''exec ${pkgs.jdk8}/bin/java "$@"'';
  java17 = pkgs.writeShellScriptBin "java17" ''exec ${pkgs.jdk17}/bin/java "$@"'';
  java21 = pkgs.writeShellScriptBin "java21" ''exec ${pkgs.jdk21}/bin/java "$@"'';
  java25 = pkgs.writeShellScriptBin "java25" ''exec ${pkgs.jdk25}/bin/java "$@"'';

  # Console access: the server runs under systemd with no interactive
  # stdin attached (plain `journalctl -f` is read-only), so sending
  # commands (whitelist add, op, kick, ...) goes over RCON instead of a
  # TTY. This wrapper reads rcon.port/rcon.password straight out of the
  # live server.properties so Haru never has to type or store the
  # password separately — just `mc-console whitelist add <name>`.
  mc-console = pkgs.writeShellScriptBin "mc-console" ''
    set -euo pipefail
    props=/var/lib/minecraft/server.properties
    port=$(${pkgs.gnugrep}/bin/grep -oP '^rcon\.port=\K.*' "$props")
    pass=$(${pkgs.gnugrep}/bin/grep -oP '^rcon\.password=\K.*' "$props")
    exec ${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P "$port" -p "$pass" "$@"
  '';

  # Same as mc-console above but for any instance directory, not just the
  # original /var/lib/minecraft — used internally by aeriehosting-ctl for
  # servers created through the "+ Create server" flow. mc-console itself
  # stays exactly as-is (Haru already has it memorized for the original
  # server) rather than changing its CLI shape.
  mc-console-at = pkgs.writeShellScriptBin "mc-console-at" ''
    set -euo pipefail
    base="$1"; shift
    props="$base/server.properties"
    port=$(${pkgs.gnugrep}/bin/grep -oP '^rcon\.port=\K.*' "$props")
    pass=$(${pkgs.gnugrep}/bin/grep -oP '^rcon\.password=\K.*' "$props")
    exec ${pkgs.mcrcon}/bin/mcrcon -H 127.0.0.1 -P "$port" -p "$pass" "$@"
  '';
in
{
  # ------------------------------------------------------------
  # SYSTEM USER — isolates the server process and its files from
  # the harua account.
  # ------------------------------------------------------------
  users.groups.minecraft = {};
  users.users.minecraft = {
    isSystemUser = true;
    group        = "minecraft";
    home         = "/var/lib/minecraft";
    createHome   = true;
    shell        = pkgs.bashInteractive; # needed so `sudo -u minecraft <cmd>` works nicely
  };

  # ------------------------------------------------------------
  # PACKAGES — all three JDKs (so any MC version works) plus the
  # Fabric installer CLI. Forge has no nixpkgs installer; download
  # its installer jar by hand per the comment above.
  # ------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    jdk8
    jdk17
    jdk21
    jdk25
    java8
    java17
    java21
    java25
    fabric-installer
    mcrcon
    mc-console
    mc-console-at
  ];

  # ------------------------------------------------------------
  # FIREWALL — open to the internet per Haru's request. Forward port
  # 25565/tcp to this machine on the router too; NixOS's firewall
  # alone doesn't reach past NAT.
  #
  # 19132/udp is Bedrock's default join port (Geyser, installed as a
  # Fabric mod — see mods/ — listens here and translates to/from the Java
  # server on 25565/tcp). Forward this UDP port on the router too for
  # Bedrock players joining over the internet, same as 25565/tcp.
  #
  # 25566-25570/tcp are pre-opened headroom for additional Minecraft
  # instances created through AerieHostingBubbles' "+ Create server" flow
  # (see modules/aeriehosting.nix's `provision` subcommand) — NixOS's
  # firewall is declarative, so a brand-new instance's port can't be
  # opened at runtime without a rebuild; pre-opening a small range avoids
  # needing one per server. RCON ports need no entry here regardless
  # (never internet-exposed, localhost/LAN only, same as the original
  # server's 25575).
  # ------------------------------------------------------------
  networking.firewall.allowedTCPPorts = [ 25565 25566 25567 25568 25569 25570 ];
  networking.firewall.allowedUDPPorts = [ 19132 ];

  # ------------------------------------------------------------
  # SEED FILES — written once if missing, then left alone forever so
  # Haru can freely edit start.sh / eula.txt / server.properties
  # without `rebuild` fighting the edits.
  # ------------------------------------------------------------
  system.activationScripts.minecraftServerSeed = ''
    mkdir -p /var/lib/minecraft/mods
    if [ ! -f /var/lib/minecraft/eula.txt ]; then
      echo "eula=true" > /var/lib/minecraft/eula.txt
    fi
    if [ ! -f /var/lib/minecraft/start.sh ]; then
      cat > /var/lib/minecraft/start.sh <<'EOF'
#!/usr/bin/env bash
# Edit JAVA= below to match the loaded MC version:
#   8  -> MC <= 1.16.5
#   17 -> MC 1.17 - 1.20.4
#   21 -> MC >= 1.20.5
JAVA=java25
# Fabric/Forge produce their own bootstrap jar (fabric-server-launch.jar);
# that's the real entry point and it loads the plain vanilla game jar
# (which must be literally named server.jar) itself. Plain vanilla has
# no bootstrap jar, so fall back to running server.jar directly.
if [ -f fabric-server-launch.jar ]; then
  LAUNCH_JAR=fabric-server-launch.jar
else
  LAUNCH_JAR=server.jar
fi
exec "''${JAVA}" -Xms4G -Xmx4G -jar "''${LAUNCH_JAR}" nogui
EOF
      chmod +x /var/lib/minecraft/start.sh
    fi
    chown -R minecraft:minecraft /var/lib/minecraft
  '';

  # ------------------------------------------------------------
  # SERVICE — just supervises start.sh. Stdout/stderr land in the
  # journal (`journalctl -u minecraft-server -f` for read-only live
  # output); send commands with `mc-console <command>` (RCON — see the
  # mc-console wrapper above). RCON's port (25575) is deliberately NOT
  # opened in the firewall below — it's only for localhost/LAN use.
  # ------------------------------------------------------------
  systemd.services.minecraft-server = {
    description = "Minecraft server (Fabric/Forge, version managed by hand)";
    after       = [ "network.target" ];
    wantedBy    = [ "multi-user.target" ];
    # So start.sh's bare `java8`/`java17`/`java21` resolve — systemd units
    # don't inherit any interactive shell's PATH.
    path        = [ java8 java17 java21 java25 ];

    serviceConfig = {
      User             = "minecraft";
      Group            = "minecraft";
      WorkingDirectory = "/var/lib/minecraft";
      # Invoke bash directly rather than relying on start.sh's own
      # `#!/usr/bin/env bash` shebang: systemd's default PATH has no
      # nixpkgs bash on it, so `env bash` fails with exit 127.
      ExecStart        = "${pkgs.bash}/bin/bash /var/lib/minecraft/start.sh";
      Restart          = "on-failure";
      RestartSec       = "10s";
      # Give the server time to flush/save the world on stop.
      TimeoutStopSec   = "60s";
      KillSignal       = "SIGINT";
      # SIGINT makes the process exit 130 (128+SIGINT) on a graceful,
      # successful stop — without this, systemd doesn't know that's the
      # EXPECTED outcome for this unit and marks it "failed" even on a
      # perfectly clean shutdown (confirmed live: AerieHostingBubbles'
      # Stop button reported "Failed" even though the journal showed a
      # normal "Stopping... / Stopped" sequence). This tells systemd 130
      # is a successful exit for this unit specifically.
      SuccessExitStatus = [ 130 ];
    };
  };

  # ------------------------------------------------------------
  # TEMPLATE SERVICE — for every Minecraft instance created through
  # AerieHostingBubbles' "+ Create server" flow (modules/aeriehosting.nix's
  # `provision` subcommand), NOT the original server above. The trailing
  # "@" is NixOS's template-unit syntax — this generates a real
  # minecraft-server@.service template; %i is the instance slug,
  # substituted by systemd itself at start time (not a Nix string, so it's
  # written literally here). Deliberately not `wantedBy` — individual
  # instances are enabled explicitly by `provision` via `systemctl enable
  # --now minecraft-server@<slug>`, since a bare template can't be enabled
  # directly. Same shared `minecraft` user as the original — directory-
  # level mode 700 isolation per instance is sufficient (Haru is the only
  # human operator regardless of which account a process runs as).
  # ------------------------------------------------------------
  systemd.services."minecraft-server@" = {
    description = "Minecraft server instance '%i' (Fabric/Forge, version managed by hand)";
    after       = [ "network.target" ];
    path        = [ java8 java17 java21 java25 ];

    serviceConfig = {
      User             = "minecraft";
      Group            = "minecraft";
      WorkingDirectory = "/var/lib/minecraft-%i";
      ExecStart        = "${pkgs.bash}/bin/bash /var/lib/minecraft-%i/start.sh";
      Restart          = "on-failure";
      RestartSec       = "10s";
      TimeoutStopSec   = "60s";
      KillSignal       = "SIGINT";
      # Same fix as the original service above — SIGINT's exit 130 is the
      # expected outcome for a graceful stop, not a failure.
      SuccessExitStatus = [ 130 ];
    };
  };
}
