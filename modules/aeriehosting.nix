# ============================================================
# modules/aeriehosting.nix
#
# Privilege plumbing for AerieHostingBubbles (the game-server hosting
# control panel at /home/harua/Projects/AerieHostingBubbles). The Node app
# itself runs as an unprivileged system user and holds NO direct access to
# /var/lib/minecraft (owned minecraft:minecraft, mode 700) or to
# systemctl. Every privileged action funnels through exactly ONE trusted
# helper script below — that is the entire security boundary: the sudoers
# rule just allows running that one script with any args; all real
# validation (path-escape checks, symlink refusal, subcommand whitelist)
# lives inside the script itself, so there is exactly one place to audit.
#
# HOW IT LINKS:
#   Imported by → hosts/victus/configuration.nix, alongside
#   modules/minecraft-server.nix (which this module's helper script calls
#   into — systemctl on the minecraft-server unit, the mc-console RCON
#   wrapper, and /var/lib/minecraft's files).
# ============================================================
{ config, pkgs, lib, ... }:

let
  # ------------------------------------------------------------
  # GAME SERVER REGISTRY — Phase 3's driver abstraction, Nix side. Adding a
  # second game type is "add an entry here" (plus a matching
  # src/drivers/*.js on the Node side, see AerieHostingBubbles's own repo)
  # — nothing else in this file changes. Only "minecraft" exists today;
  # this attrset is what the aeriehosting-ctl case statement below is
  # generated from, instead of being hand-written per server.
  # ------------------------------------------------------------
  gameServers = {
    minecraft = {
      unit  = "minecraft-server";
      base  = "/var/lib/minecraft";
      owner = "minecraft";
    };
  };

  aeriehostingCtlCaseBody = lib.concatStrings (lib.mapAttrsToList (slug: cfg: ''
    ${slug})
      UNIT=${cfg.unit}
      BASE=${cfg.base}
      OWNER=${cfg.owner}
      ;;
  '') gameServers);

  # ------------------------------------------------------------
  # aeriehosting-ctl — the one trusted helper.
  #
  # Invocation convention, uniform across every subcommand:
  #   aeriehosting-ctl <subcommand> <server-id> [subcommand-specific args...]
  #
  # <server-id> is resolved through the generated case below (from
  # `gameServers` above) into {UNIT, BASE, OWNER}.
  # ------------------------------------------------------------
  aeriehostingAclScript = pkgs.writeShellScript "aeriehosting-acl-setup" ''
    set -euo pipefail
    ${pkgs.acl}/bin/setfacl -m u:aeriehosting:--x,m::x /home/harua
    ${pkgs.acl}/bin/setfacl -R -m u:aeriehosting:rX,m::rX /home/harua/Projects/AerieHostingBubbles
    ${pkgs.acl}/bin/setfacl -R -d -m u:aeriehosting:rX,m::rX /home/harua/Projects/AerieHostingBubbles
  '';

  aeriehosting-ctl = pkgs.writeShellScriptBin "aeriehosting-ctl" ''
    set -euo pipefail

    log() { ${pkgs.util-linux}/bin/logger -t aeriehosting-ctl -- "$*"; }
    log "invoked: $*"

    if [ "$#" -lt 2 ]; then
      echo "usage: aeriehosting-ctl <subcommand> <server-id> [args...]" >&2
      exit 2
    fi

    cmd="$1"
    serverId="$2"
    shift 2

    # "minecraft" (the original server) is explicitly registered above via
    # `gameServers`. Any OTHER server-id is resolved by convention instead
    # of a per-entry whitelist — this is what lets "+ Create server" work
    # without a Nix rebuild per instance. Safety comes from the regex (no
    # path-escape characters possible) plus the fixed path prefix, same
    # spirit as resolve_safe()'s own containment check below.
    case "$serverId" in
      ${aeriehostingCtlCaseBody}
      *)
        if [[ "$serverId" =~ ^[a-z][a-z0-9-]{0,30}$ ]]; then
          UNIT="minecraft-server@$serverId"
          BASE="/var/lib/minecraft-$serverId"
          OWNER=minecraft
        else
          echo "unknown server id: $serverId" >&2
          exit 2
        fi
        ;;
    esac

    # Every fs-* subcommand funnels its relpath argument through here:
    # reject absolute paths and any ".." component, resolve symlinks away,
    # then re-verify the result is still under $BASE. Mirrors the spirit of
    # homebase's resolveSafePath(), just living in the trusted script
    # instead of app code (the app itself has no filesystem access to
    # verify against).
    resolve_safe() {
      local rel="$1"
      case "$rel" in
        /*|*..*)
          echo "rejected: unsafe path" >&2
          exit 3
          ;;
      esac
      local abs
      abs=$(${pkgs.coreutils}/bin/realpath -m -- "$BASE/$rel")
      case "$abs" in
        "$BASE"/*|"$BASE")
          ;;
        *)
          echo "rejected: path escapes server root" >&2
          exit 3
          ;;
      esac
      printf '%s' "$abs"
    }

    # Worlds helpers — reused by world-activate/world-wipe/
    # world-regen-dimension below. Rebuilds server.properties with one key
    # replaced (grep -v + append) rather than sed's s/// substitution,
    # since a value containing & or \ would otherwise be misinterpreted by
    # sed's replacement-string syntax. $key is always one of this script's
    # own literal strings, never user input, so no regex-injection concern
    # in the grep pattern itself.
    propSet() {
      local key="$1" val="$2"
      ${pkgs.gnugrep}/bin/grep -v "^''${key}=" "$BASE/server.properties" > "$BASE/server.properties.tmp" 2>/dev/null || true
      echo "''${key}=''${val}" >> "$BASE/server.properties.tmp"
      ${pkgs.coreutils}/bin/mv -- "$BASE/server.properties.tmp" "$BASE/server.properties"
    }
    readProp() {
      local key="$1"
      ${pkgs.gnugrep}/bin/grep "^''${key}=" "$BASE/server.properties" 2>/dev/null \
        | ${pkgs.coreutils}/bin/tail -1 | ${pkgs.coreutils}/bin/cut -d= -f2-
    }
    safeWorldSlug() {
      [[ "$1" =~ ^[a-z][a-z0-9-]{0,30}$ ]] || { echo "rejected: unsafe world slug" >&2; exit 3; }
    }

    case "$cmd" in
      power)
        action="$1"
        case "$action" in
          start|stop|restart)
            ${pkgs.systemd}/bin/systemctl "$action" "$UNIT"
            ;;
          status)
            ${pkgs.systemd}/bin/systemctl is-active "$UNIT" || true
            ;;
          *)
            echo "bad power action: $action" >&2
            exit 2
            ;;
        esac
        ;;

      console-exec)
        # $1 is base64 of the RCON command text — avoids all shell-quoting
        # / injection concerns around arbitrary player-supplied command text.
        # mc-console-at reads rcon.port/password straight out of $BASE's own
        # server.properties, so this works identically for the original
        # server and any instance created later.
        decoded=$(printf '%s' "$1" | ${pkgs.coreutils}/bin/base64 -d)
        mc-console-at "$BASE" "$decoded"
        ;;

      fs-list)
        abs=$(resolve_safe "$1")
        ${pkgs.findutils}/bin/find "$abs" -maxdepth 1 -mindepth 1 \
          -printf '%f\t%y\t%s\t%T@\n'
        ;;

      fs-read)
        abs=$(resolve_safe "$1")
        [ -L "$abs" ] && { echo "rejected: symlink" >&2; exit 3; }
        ${pkgs.coreutils}/bin/cat -- "$abs"
        ;;

      fs-write)
        abs=$(resolve_safe "$1")
        [ -e "$abs" ] && [ -L "$abs" ] && { echo "rejected: symlink target" >&2; exit 3; }
        tmp="$abs.aeriehosting-tmp.$$"
        ${pkgs.coreutils}/bin/cat > "$tmp"
        ${pkgs.coreutils}/bin/chown "$OWNER:$OWNER" "$tmp"
        ${pkgs.coreutils}/bin/mv -T -- "$tmp" "$abs"
        ;;

      fs-delete)
        abs=$(resolve_safe "$1")
        trashId="$2"
        ${pkgs.coreutils}/bin/mkdir -p "$BASE/.trash"
        ${pkgs.coreutils}/bin/mv -- "$abs" "$BASE/.trash/''${trashId}__$(${pkgs.coreutils}/bin/basename -- "$abs")"
        ;;

      fs-restore)
        trashId="$1"
        destRel="$2"
        dest=$(resolve_safe "$destRel")
        src=$(${pkgs.findutils}/bin/find "$BASE/.trash" -maxdepth 1 -name "''${trashId}__*" | head -1)
        [ -z "$src" ] && { echo "not found in trash: $trashId" >&2; exit 4; }
        ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname -- "$dest")"
        ${pkgs.coreutils}/bin/mv -- "$src" "$dest"
        ${pkgs.coreutils}/bin/chown "$OWNER:$OWNER" "$dest"
        ;;

      fs-purge)
        trashId="$1"
        src=$(${pkgs.findutils}/bin/find "$BASE/.trash" -maxdepth 1 -name "''${trashId}__*" | head -1)
        [ -n "$src" ] && ${pkgs.coreutils}/bin/rm -f -- "$src"
        ;;

      du)
        ${pkgs.coreutils}/bin/du -sb "$BASE" 2>/dev/null | cut -f1
        ;;

      # ---------------- Phase 2: backups ----------------
      # Curated set, not the whole BASE (skips libraries/.cache/.fabric —
      # regenerable build artifacts — and logs/, not essential to restore).
      backup-create)
        filename="$1"
        ${pkgs.coreutils}/bin/mkdir -p "$BASE/.backups"
        cd "$BASE"
        items=()
        for f in world server.properties whitelist.json ops.json banned-players.json banned-ips.json mods config eula.txt; do
          [ -e "$f" ] && items+=("$f")
        done
        ${pkgs.gnutar}/bin/tar --use-compress-program=${pkgs.gzip}/bin/gzip \
          -cf "$BASE/.backups/$filename" "''${items[@]}"
        ${pkgs.coreutils}/bin/chown "$OWNER:$OWNER" "$BASE/.backups/$filename"
        ;;

      backup-restore)
        # NOTE: tar's -z flag shells out to an external `gzip` binary by
        # bare name — confirmed live this isn't on PATH in this script's
        # execution context ("gzip: command not found"), so
        # --use-compress-program with gzip's absolute store path is used
        # instead everywhere, same as every other binary in this script.
        filename="$1"
        path="$BASE/.backups/$filename"
        [ -f "$path" ] || { echo "backup not found: $filename" >&2; exit 4; }
        ${pkgs.gnutar}/bin/tar --use-compress-program=${pkgs.gzip}/bin/gzip -xf "$path" -C "$BASE"
        ${pkgs.gnutar}/bin/tar --use-compress-program=${pkgs.gzip}/bin/gzip -tf "$path" | while IFS= read -r entry; do
          ${pkgs.coreutils}/bin/chown -R "$OWNER:$OWNER" "$BASE/$entry" 2>/dev/null || true
        done
        ;;

      # ---------------- Phase 2: startup (version/loader switching) ----------------
      # Wraps the exact manual flow from this session's Minecraft setup —
      # see concepts/nixos-setup.md for the two real bugs that motivated
      # the extra validation here (a clobbered server.jar symlink, and
      # fabric-installer's -downloadMinecraft silently no-op'ing).
      startup-fetch)
        # Node already validated this came from Mojang's own piston-meta
        # manifest before calling us; re-checked here too so the one
        # trusted script never blindly curls an arbitrary URL even if a
        # future caller forgets to validate upstream.
        url="$1"
        case "$url" in
          https://piston-data.mojang.com/*) ;;
          *) echo "rejected: url must be from piston-data.mojang.com" >&2; exit 3 ;;
        esac
        dest="$BASE/server.jar"
        [ -e "$dest" ] && [ -L "$dest" ] && { echo "rejected: destination is a symlink" >&2; exit 3; }
        tmp="$dest.aeriehosting-tmp.$$"
        ${pkgs.curl}/bin/curl -fsSL -o "$tmp" "$url"
        ${pkgs.coreutils}/bin/chown "$OWNER:$OWNER" "$tmp"
        ${pkgs.coreutils}/bin/mv -T -- "$tmp" "$dest"
        ;;

      startup-install-fabric)
        mcVersion="$1"
        loaderVersion="$2"
        case "$mcVersion" in [a-zA-Z0-9._-]*) ;; *) echo "bad mc version" >&2; exit 2 ;; esac
        case "$loaderVersion" in [a-zA-Z0-9._-]*) ;; *) echo "bad loader version" >&2; exit 2 ;; esac
        cd "$BASE"
        ${pkgs.util-linux}/bin/runuser -u "$OWNER" -- \
          ${pkgs.fabric-installer}/bin/fabric-installer server -mcversion "$mcVersion" -loader "$loaderVersion"
        ${pkgs.coreutils}/bin/chown -R "$OWNER:$OWNER" "$BASE/libraries" "$BASE/fabric-server-launch.jar" 2>/dev/null || true
        ;;

      startup-set-java)
        version="$1"
        case "$version" in
          8|17|21|25) ;;
          *) echo "bad java version: $version" >&2; exit 2 ;;
        esac
        ${pkgs.gnused}/bin/sed -i "s/^JAVA=java.*/JAVA=java$version/" "$BASE/start.sh"
        ;;

      # ---------------- Software tab: Paper/Purpur/Folia (direct-jar) ----------------
      # These are drop-in server.jar replacements (run via the same
      # `java -jar server.jar` as vanilla), unlike Forge/NeoForge/Quilt
      # below which need a separate installer run. Node already resolved
      # the exact build URL from the project's own API before calling us;
      # re-checked here too, same defense-in-depth as startup-fetch.
      # NOTE: fill.papermc.io is the BUILDS-LISTING api host only — the
      # actual jar download it returns lives on a separate CDN host,
      # fill-data.papermc.io (confirmed live; an earlier draft assumed
      # same-host and a real install attempt failed with "rejected: url
      # must be from fill.papermc.io" until this was corrected — same
      # split pattern as Mojang's piston-meta/piston-data elsewhere in
      # this script).
      startup-fetch-plugin-jar)
        kind="$1"; url="$2"
        case "$kind" in
          paper|folia)
            case "$url" in
              https://fill-data.papermc.io/*) ;;
              *) echo "rejected: url must be from fill-data.papermc.io" >&2; exit 3 ;;
            esac
            ;;
          purpur)
            case "$url" in
              https://api.purpurmc.org/*) ;;
              *) echo "rejected: url must be from api.purpurmc.org" >&2; exit 3 ;;
            esac
            ;;
          *) echo "bad plugin-jar kind: $kind" >&2; exit 2 ;;
        esac
        dest="$BASE/server.jar"
        [ -e "$dest" ] && [ -L "$dest" ] && { echo "rejected: destination is a symlink" >&2; exit 3; }
        tmp="$dest.aeriehosting-tmp.$$"
        ${pkgs.curl}/bin/curl -fsSL -o "$tmp" "$url"
        ${pkgs.coreutils}/bin/chown "$OWNER:$OWNER" "$tmp"
        ${pkgs.coreutils}/bin/mv -T -- "$tmp" "$dest"
        ;;

      # ---------------- Software tab: Forge/NeoForge/Quilt (installer-run) ----------------
      # Unlike every other network fetch in this script, this one curls an
      # executable jar AND THEN RUNS IT (as $OWNER via runuser, same
      # privilege level fabric-installer already runs at — never root).
      # That's a real step up in trust surface versus a passive file
      # download: the hostname pin is the only control, same as Mojang's
      # above, just applied to a new category of artifact. Quilt's exact
      # installer CLI flags are NOT independently verified against a real
      # run (unlike Forge/NeoForge's well-established --installServer) —
      # expect this may need correcting after the first live attempt, same
      # as fabric-installer's own -downloadMinecraft surprise.
      startup-install-modloader)
        loader="$1"; mcVersion="$2"; loaderVersion="$3"
        case "$mcVersion" in [a-zA-Z0-9._-]*) ;; *) echo "bad mc version" >&2; exit 2 ;; esac
        case "$loaderVersion" in [a-zA-Z0-9._-]*) ;; *) echo "bad loader version" >&2; exit 2 ;; esac
        case "$loader" in
          forge)
            url="https://maven.minecraftforge.net/net/minecraftforge/forge/''${mcVersion}-''${loaderVersion}/forge-''${mcVersion}-''${loaderVersion}-installer.jar"
            ;;
          neoforge)
            url="https://maven.neoforged.net/releases/net/neoforged/neoforge/''${loaderVersion}/neoforge-''${loaderVersion}-installer.jar"
            ;;
          quilt)
            url="https://maven.quiltmc.org/repository/release/org/quiltmc/quilt-installer/''${loaderVersion}/quilt-installer-''${loaderVersion}.jar"
            ;;
          *) echo "bad modloader: $loader" >&2; exit 2 ;;
        esac
        case "$url" in
          https://maven.minecraftforge.net/*|https://maven.neoforged.net/*|https://maven.quiltmc.org/*) ;;
          *) echo "rejected: unexpected installer host" >&2; exit 3 ;;
        esac

        cd "$BASE"
        installer="$BASE/.installer-tmp-$$.jar"
        ${pkgs.curl}/bin/curl -fsSL -o "$installer" "$url"
        case "$loader" in
          forge|neoforge)
            ${pkgs.util-linux}/bin/runuser -u "$OWNER" -- ${pkgs.jdk25}/bin/java -jar "$installer" --installServer
            ;;
          quilt)
            ${pkgs.util-linux}/bin/runuser -u "$OWNER" -- ${pkgs.jdk25}/bin/java -jar "$installer" install server "$mcVersion" --install-dir=. --download-server
            ;;
        esac
        ${pkgs.coreutils}/bin/rm -f -- "$installer" "$installer.log"

        # Forge/NeoForge (and possibly Quilt) generate their own run.sh
        # launcher instead of a plain jar — confirmed live against a real
        # NeoForge install ("The server installed successfully", a real
        # run.sh produced). But run.sh hardcodes a BARE `java` call, and
        # this systemd unit's PATH (minecraft-server.nix) is deliberately
        # minimal — ONLY the java8/17/21/25 wrapper dirs, no coreutils at
        # all. A first attempt bridging this via `mktemp`+`ln`+`exec bash
        # run.sh` failed live with exit code 127 ("command not found") —
        # none of mktemp/ln/a bare `bash` exist on this PATH either.
        # Fixed by avoiding every external binary: resolve the chosen
        # JAVA wrapper's real path via the `command` BUILTIN, then exec
        # it directly against run.sh's own @argfile convention (bash
        # globstar, also a builtin, replaces `find` for locating
        # unix_args.txt without caring which loader's library layout
        # produced it).
        currentJava=$(${pkgs.gnugrep}/bin/grep '^JAVA=' "$BASE/start.sh" 2>/dev/null | ${pkgs.coreutils}/bin/cut -d= -f2)
        [ -z "$currentJava" ] && currentJava="java25"
        cat > "$BASE/start.sh" <<EOF
#!/usr/bin/env bash
JAVA=$currentJava
if [ -f run.sh ]; then
  shopt -s globstar nullglob
  argfiles=(libraries/**/unix_args.txt)
  javabin="\$(command -v "\$JAVA")"
  exec "\$javabin" @user_jvm_args.txt @"\''${argfiles[0]}" nogui
fi
if [ -f fabric-server-launch.jar ]; then
  LAUNCH_JAR=fabric-server-launch.jar
else
  LAUNCH_JAR=server.jar
fi
exec "\$JAVA" -Xms2G -Xmx2G -jar "\$LAUNCH_JAR" nogui
EOF
        ${pkgs.coreutils}/bin/chmod +x "$BASE/start.sh"
        ${pkgs.coreutils}/bin/chown -R "$OWNER:$OWNER" "$BASE"
        ;;

      # ---------------- Phase 4: provision a brand-new instance ----------------
      # Only ever called for a convention-resolved $BASE (never the
      # original "minecraft" id — that one already exists). Refuses to run
      # twice over the same instance so a retried/duplicate API call can't
      # clobber a server that's already been set up.
      provision)
        port="$1"
        rconPort="$2"
        [ -e "$BASE" ] && { echo "already provisioned: $BASE exists" >&2; exit 4; }

        ${pkgs.coreutils}/bin/mkdir -p "$BASE/mods"
        echo "eula=true" > "$BASE/eula.txt"

        rconPass=$(${pkgs.coreutils}/bin/head -c18 /dev/urandom | ${pkgs.coreutils}/bin/base64)
        cat > "$BASE/server.properties" <<PROPS
server-port=$port
rcon.port=$rconPort
rcon.password=$rconPass
enable-rcon=true
white-list=false
online-mode=true
PROPS

        cat > "$BASE/start.sh" <<'EOF'
#!/usr/bin/env bash
JAVA=java25
# Forge/NeoForge/Quilt's own installer generates a run.sh launcher
# instead of a plain jar — it hardcodes a bare `java` call, which isn't
# on this systemd unit's deliberately minimal PATH (only the java8/17/
# 21/25 wrapper dirs — see minecraft-server.nix). Resolved here via the
# `command` BUILTIN (no external binary needed) and exec'd directly
# against run.sh's own @argfile convention; globstar (also a builtin)
# finds unix_args.txt without caring which loader's library layout
# produced it.
if [ -f run.sh ]; then
  shopt -s globstar nullglob
  argfiles=(libraries/**/unix_args.txt)
  javabin="$(command -v "''${JAVA}")"
  exec "''${javabin}" @user_jvm_args.txt @"''${argfiles[0]}" nogui
fi
if [ -f fabric-server-launch.jar ]; then
  LAUNCH_JAR=fabric-server-launch.jar
else
  LAUNCH_JAR=server.jar
fi
exec "''${JAVA}" -Xms2G -Xmx2G -jar "''${LAUNCH_JAR}" nogui
EOF
        ${pkgs.coreutils}/bin/chmod +x "$BASE/start.sh"
        ${pkgs.coreutils}/bin/chown -R "$OWNER:$OWNER" "$BASE"

        # `enable` (not just `start`) would need to write a symlink under
        # /etc/systemd/system/multi-user.target.wants/ — but on NixOS that
        # whole tree is generated declaratively by the systemd module and
        # is read-only at runtime (confirmed live: "Failed to enable unit:
        # ... Read-only file system"). `start` alone instantiates the
        # template fine with no such write. Tradeoff: a dynamically
        # created instance does NOT come back on its own after a reboot
        # (the original "minecraft" server still does, since it's
        # declared `wantedBy` in Nix) — persisting that across reboots
        # would require a Nix rebuild per created server, which defeats
        # the entire point of this template-unit design. Acceptable for
        # now; Haru can restart any created instance manually (power-on
        # from the panel) after a reboot.
        ${pkgs.systemd}/bin/systemctl start "$UNIT"
        ;;

      # ---------------- Worlds: named save-slots ----------------
      # world-activate switches which world is loaded (level-name), baking
      # in the given generation settings only if this slug has never been
      # generated before ($BASE/$slug doesn't exist yet) — switching back
      # to an already-generated world leaves its data untouched. seed and
      # generator-settings arrive base64-encoded (args 6/7), same
      # avoids-shell-escaping convention console-exec already uses for
      # arbitrary command text.
      world-activate)
        slug="$1"; levelType="$2"; genStructures="$3"; hardcore="$4"
        seedB64="$5"; genSettingsB64="$6"
        safeWorldSlug "$slug"
        case "$genStructures" in true|false) ;; *) echo "bad generateStructures" >&2; exit 2 ;; esac
        case "$hardcore" in true|false) ;; *) echo "bad hardcore" >&2; exit 2 ;; esac
        seed=$(printf '%s' "$seedB64" | ${pkgs.coreutils}/bin/base64 -d)
        genSettings=$(printf '%s' "$genSettingsB64" | ${pkgs.coreutils}/bin/base64 -d)

        ${pkgs.systemd}/bin/systemctl stop "$UNIT" || true

        if [ ! -e "$BASE/$slug" ]; then
          propSet "level-type" "$levelType"
          propSet "generate-structures" "$genStructures"
          propSet "hardcore" "$hardcore"
          propSet "level-seed" "$seed"
          propSet "generator-settings" "$genSettings"
        fi
        propSet "level-name" "$slug"

        ${pkgs.systemd}/bin/systemctl start "$UNIT"
        ;;

      # world-wipe deletes a save-slot's directory. Refuses on the
      # currently-active world (must Activate a different slot first) so
      # this can never delete live, in-use world data out from under the
      # running server.
      world-wipe)
        slug="$1"
        safeWorldSlug "$slug"
        current=$(readProp level-name)
        [ "$slug" = "$current" ] && { echo "refusing to wipe the active world" >&2; exit 4; }
        ${pkgs.coreutils}/bin/rm -rf -- "$BASE/$slug"
        ;;

      # world-regen-dimension wipes just one dimension's data out of the
      # CURRENTLY ACTIVE world, keeping the rest (playerdata, the other
      # two dimensions) intact — Minecraft regenerates the wiped
      # dimension fresh from the world's existing seed on next load.
      world-regen-dimension)
        dimension="$1"
        case "$dimension" in overworld|nether|end) ;; *) echo "bad dimension: $dimension" >&2; exit 2 ;; esac
        ${pkgs.systemd}/bin/systemctl stop "$UNIT" || true
        level=$(readProp level-name)
        worldDir="$BASE/$level"
        # Confirmed live against a real MC 26.2 world: this version keeps
        # ALL THREE dimensions' chunk data under a unified
        # dimensions/minecraft/<name>/ tree — there is no top-level
        # region/poi/entities for the overworld and no legacy DIM-1/DIM1
        # for nether/end (that older asymmetric layout was assumed in an
        # earlier draft of this subcommand and found wrong by actually
        # looking, not guessed from docs). Both old- and new-layout paths
        # are removed here regardless — rm -rf on a path that doesn't
        # exist is a harmless no-op, so this stays correct if a server
        # ever runs an older MC version with the legacy layout too.
        case "$dimension" in
          overworld)
            ${pkgs.coreutils}/bin/rm -rf -- \
              "$worldDir/dimensions/minecraft/overworld" \
              "$worldDir/region" "$worldDir/poi" "$worldDir/entities"
            ;;
          nether)
            ${pkgs.coreutils}/bin/rm -rf -- \
              "$worldDir/dimensions/minecraft/the_nether" "$worldDir/DIM-1"
            ;;
          end)
            ${pkgs.coreutils}/bin/rm -rf -- \
              "$worldDir/dimensions/minecraft/the_end" "$worldDir/DIM1"
            ;;
        esac
        ${pkgs.systemd}/bin/systemctl start "$UNIT"
        ;;

      # ---------------- Mods tab: Modrinth catalog install ----------------
      # Node already re-resolved the exact file URL from Modrinth's own
      # /version/:id endpoint by versionId before calling us (never trusts
      # a client-supplied URL) — re-checked here too, same defense-in-depth
      # as every other network fetch in this script. targetDir is
      # 'mods' or 'plugins' depending on the server's software type
      # (Node decides which, based on servers.software_type).
      mod-fetch)
        targetDir="$1"; url="$2"; filename="$3"
        case "$targetDir" in
          mods|plugins) ;;
          *) echo "bad targetDir: $targetDir" >&2; exit 2 ;;
        esac
        case "$url" in
          https://cdn.modrinth.com/*) ;;
          *) echo "rejected: url must be from cdn.modrinth.com" >&2; exit 3 ;;
        esac
        case "$filename" in
          */*|*..*) echo "rejected: unsafe filename" >&2; exit 3 ;;
        esac
        ${pkgs.coreutils}/bin/mkdir -p "$BASE/$targetDir"
        dest="$BASE/$targetDir/$filename"
        [ -e "$dest" ] && [ -L "$dest" ] && { echo "rejected: destination is a symlink" >&2; exit 3; }
        tmp="$dest.aeriehosting-tmp.$$"
        ${pkgs.curl}/bin/curl -fsSL -o "$tmp" "$url"
        ${pkgs.coreutils}/bin/chown "$OWNER:$OWNER" "$tmp"
        ${pkgs.coreutils}/bin/mv -T -- "$tmp" "$dest"
        ;;

      # ---------------- Databases tab: provision a new database+role ----------------
      # The only genuinely privileged Postgres action this app needs —
      # listing/checking existing databases needs no special privilege at
      # all (pg_database is a world-readable catalog, queried directly
      # from the app's own ordinary connection), but CREATE DATABASE/
      # CREATE ROLE require superuser (or explicit CREATEDB/CREATEROLE
      # grants this app's own web-facing role deliberately does NOT
      # have — same privilege-separation posture as every OS-level action
      # in this script). Connects as the `postgres` OS user, which NixOS's
      # default peer-auth setup maps straight to the real Postgres
      # superuser role, same mechanism already used manually (as harua)
      # earlier for LuckPerms' own database setup, now automated here.
      # $serverId is consumed by the generic resolution above like every
      # other subcommand (keeping the CLI convention uniform) but
      # genuinely unused below — this has no filesystem/systemd angle.
      db-create)
        dbName="$1"; dbUser="$2"
        [[ "$dbName" =~ ^[a-z_][a-z0-9_]{0,62}$ ]] || { echo "rejected: unsafe db name" >&2; exit 3; }
        [[ "$dbUser" =~ ^[a-z_][a-z0-9_]{0,62}$ ]] || { echo "rejected: unsafe db user" >&2; exit 3; }
        dbPass=$(${pkgs.coreutils}/bin/head -c18 /dev/urandom | ${pkgs.coreutils}/bin/base64)
        ${pkgs.util-linux}/bin/runuser -u postgres -- ${pkgs.postgresql_16}/bin/psql -v ON_ERROR_STOP=1 >/dev/null <<SQL
CREATE ROLE "$dbUser" LOGIN PASSWORD '$dbPass';
CREATE DATABASE "$dbName" OWNER "$dbUser";
SQL
        printf '%s' "$dbPass"
        ;;

      *)
        echo "unknown subcommand: $cmd" >&2
        exit 2
        ;;
    esac
  '';
in
{
  # ------------------------------------------------------------
  # SERVICE ACCOUNT — the Node app runs as this user, never root.
  # ------------------------------------------------------------
  users.groups.aeriehosting = {};
  users.users.aeriehosting = {
    isSystemUser = true;
    group        = "aeriehosting";
    home         = "/var/lib/aeriehosting";
    createHome   = true;
    # Read-only journal access (console live-tail) — a standard, narrow,
    # OS-level grant. No sudo needed for this half of the console feature.
    extraGroups  = [ "systemd-journal" ];
    shell        = pkgs.bashInteractive;
  };

  environment.systemPackages = [ aeriehosting-ctl ];

  # ------------------------------------------------------------
  # THE ONE SUDOERS RULE — fixed path, wildcard args. All real validation
  # is inside aeriehosting-ctl itself (see above), not in this rule.
  # ------------------------------------------------------------
  security.sudo.extraRules = [
    {
      users = [ "aeriehosting" ];
      runAs = "root";
      commands = [{
        command = "${aeriehosting-ctl}/bin/aeriehosting-ctl";
        options = [ "NOPASSWD" ];
      }];
    }
    {
      # Lets StarFire (~/Projects/starfire, runs as harua) manage
      # AerieHostingBubbles's pm2 process under the dedicated aeriehosting
      # account, without giving harua any broader access to that account —
      # scoped to the pm2 binary itself, nothing else. Without this,
      # starting/stopping/restarting the app from StarFire's dashboard has
      # no way to run it as anyone but harua, which defeats the privilege
      # boundary above entirely (see concepts/nixos-setup.md's "stale
      # personal pm2 dump" writeup for the incident that led here).
      users = [ "harua" ];
      runAs = "aeriehosting";
      commands = [{
        command = "${pkgs.pm2}/bin/pm2";
        options = [ "NOPASSWD" ];
      }];
    }
  ];

  # ------------------------------------------------------------
  # THE APP ITSELF — no longer systemd-managed. Haru runs it under `pm2`
  # instead (as the `aeriehosting` user, so the privilege boundary above
  # stays exactly intact — pm2 just replaces systemd as the process
  # supervisor, for its nicer `pm2 logs`/`pm2 monit` CLI). See
  # ~/Projects/AerieHostingBubbles/ecosystem.config.js for the pm2 process
  # definition; AERIEHOSTING_CTL there is resolved dynamically via
  # fs.realpathSync on /run/current-system/sw/bin/aeriehosting-ctl at pm2
  # start time, since there's no Nix-managed unit left to inject the
  # literal store path as a build-time string — same requirement either
  # way: sudo matches on the literal resolved path, not the symlink, so a
  # `pm2 restart` is needed after any rebuild that changes this
  # derivation's hash, exactly like the old systemd unit also needed a
  # restart for the same reason.
  # ------------------------------------------------------------

  # ------------------------------------------------------------
  # ACL MAINTENANCE — re-applies the project-directory ACL (see above) at
  # every boot. Confirmed live, three times now: something in the normal
  # activation/switch sequence silently re-zeroes the ACL mask on
  # /home/harua, dropping aeriehosting's effective permission back to
  # nothing — and this oneshot only re-runs when ITS OWN content changes,
  # not on every switch, so an unrelated config change (e.g. the Geyser/
  # firewall edit) can silently leave it stale. Tried forcing a restart on
  # every switch via `restartTriggers = [ config.system.build.toplevel ]`
  # — causes infinite recursion (toplevel depends on this very unit via
  # the systemd module, circularly). No clean Nix-level fix found; the
  # real fix is procedural: ALWAYS run
  # `sudo systemctl restart aeriehosting-acl-setup` immediately after
  # every `nixos-rebuild switch`, every time, no exceptions — bundle it
  # into the same script/command as the switch itself, never a separate
  # optional step.
  # ------------------------------------------------------------
  systemd.services.aeriehosting-acl-setup = {
    description = "Re-apply aeriehosting's ACL grant on ~harua/Projects/AerieHostingBubbles";
    wantedBy    = [ "multi-user.target" ];
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      ExecStart       = "${aeriehostingAclScript}";
    };
  };
}
