# ============================================================
# modules/audio.nix
#
# Audio stack configuration using PipeWire.
#
# HOW IT LINKS:
#   Imported by → hosts/victus/configuration.nix
#   No other module imports this file.
#   PipeWire itself runs as a per-user systemd service, started
#   automatically when harua logs in.
#
# AUDIO STACK PICTURE:
#   Hardware → ALSA (kernel driver) → PipeWire (user daemon)
#                                        ├── PulseAudio API  ← most desktop apps
#                                        ├── ALSA API        ← old/native Linux apps
#                                        └── JACK API        ← pro audio / DAWs
#
#   PipeWire is a single daemon that replaces both PulseAudio
#   and JACK. Apps that use any of the three APIs route through
#   it transparently.
#
# VOLUME BOOST (going above 100%):
#   Three methods, from simplest to most powerful:
#
#   1. Shell command (instant, no config):
#        pactl set-sink-volume @DEFAULT_SINK@ 200%
#      The shell aliases `boost`, `vol`, `volup`, `voldown` in home.nix
#      wrap this. PipeWire's pulse emulation supports up to ~655 % via pactl
#      (PA_VOLUME_MAX = 0xFFFFFFFF) but audible distortion starts around
#      150-200 % if the source signal is already loud.
#
#   2. EasyEffects (installed in desktop-apps.nix):
#      The "Loudness Equalizer" or "Autogain" preset + a Gain plugin
#      applies clean amplification with a Limiter to prevent clipping.
#      Better quality than raw pactl boosting.
#      Start: easyeffects → enable → add "Gain" plugin → set to +20 dB
#
#   3. PipeWire volume limit (this file):
#      The `flat-volumes = false` setting below makes PipeWire use
#      independent per-stream volumes rather than coupling them to the
#      master. This prevents Firefox from secretly changing your master
#      volume when you change its own volume.
# ============================================================
{ config, pkgs, lib, ... }:

{
  # PulseAudio and PipeWire CANNOT coexist. PulseAudio grabs the audio
  # hardware first, preventing PipeWire's pulse emulation from working.
  # Explicitly disabled so NixOS doesn't enable it elsewhere in the module tree.
  services.pulseaudio.enable = false;

  # RealtimeKit (rtkit) grants real-time CPU priority to audio threads on request.
  # PipeWire asks rtkit for RT priority so its mixer thread is never preempted
  # during CPU-heavy tasks, preventing audio pops and glitches under load.
  # Without rtkit, PipeWire still works but degrades under CPU pressure.
  security.rtkit.enable = true;

  services.pipewire = {
    # Start the PipeWire daemon and WirePlumber (session/policy manager).
    # WirePlumber decides which audio stream goes to which device and
    # handles auto-switching when you plug in headphones.
    enable = true;

    # ALSA compatibility layer.
    # Apps that use ALSA directly (CLI tools like `aplay`, FFmpeg, some games)
    # are redirected through PipeWire. Without this, ALSA apps bypass PipeWire
    # and conflict with it by trying to open the hardware device themselves.
    alsa.enable = true;

    # 32-bit ALSA support.
    # Required for: 32-bit Steam games, Wine/Proton, old games shipped as
    # 32-bit binaries. Without this, those apps go completely silent.
    alsa.support32Bit = true;

    # PulseAudio emulation socket.
    # Apps using libpulse (browsers, Spotify, Discord, most desktop apps)
    # talk to PipeWire transparently through this compatibility socket.
    pulse.enable = true;

    # JACK emulation socket.
    # DAWs (Ardour, REAPER, Carla), LV2/VST hosts, and low-latency audio
    # tools can use PipeWire as a JACK server. Safe to leave on even if
    # you don't use JACK apps — it just opens an extra idle socket.
    jack.enable = true;

    # ============================================================
    # PIPEWIRE QUALITY & LATENCY CONFIGURATION
    # ============================================================
    # These settings tune the core PipeWire graph clock and resampler.
    # They apply to the pipewire daemon itself (not the pulse/jack emulation).
    #
    # default.clock.rate: sample rate for internal mixing.
    #   48000 Hz is the universal standard for consumer audio hardware.
    #   Keep this at 48000 unless ALL your devices native rate is 44100.
    #
    # default.clock.quantum: buffer size (frames) for internal processing.
    #   Lower = less latency, more CPU load, risk of underruns (crackling).
    #   Higher = more latency, stable, good for background music.
    #   512 frames @ 48 000 Hz = ~10.7 ms — a good desktop balance.
    #
    # default.clock.min-quantum: PipeWire will never go below this buffer size
    #   even if an app requests lower. 32 frames = ~0.67 ms (pro audio territory).
    #   Raising this prevents crackling on CPUs that can't service the audio
    #   thread fast enough at very low quantum.
    #
    # default.clock.max-quantum: ceiling for apps that request large buffers.
    #   8192 frames = 170 ms — enough headroom for any use case.
    extraConfig.pipewire."99-haru-quality" = {
      "context.properties" = {
        # ---- Sample rate -------------------------------------------
        # 48 kHz is the native rate of HDMI, Bluetooth codecs (AAC, aptX HD,
        # LDAC), and most USB audio devices. Using 48 kHz avoids resampling
        # for the majority of audio sources.
        "default.clock.rate"        = 48000;
        "default.clock.allowed-rates" = [ 44100 48000 88200 96000 ];
        # Allow PipeWire to switch to the source's native rate when possible,
        # minimising resampling entirely.

        # ---- Buffer size (latency vs stability tradeoff) -----------
        # 512 @ 48 kHz = 10.67 ms latency. Good desktop balance.
        # Drop to 256 (5.3 ms) if you play games or use JACK instruments.
        # Raise to 1024 (21.3 ms) if you get crackling under CPU load.
        "default.clock.quantum"     = 1024;
        "default.clock.min-quantum" = 32;

        # BUG FIX: Spotify "Can't play" on pause/skip.
        # Root cause (confirmed via pw-top): Spotify forces the PipeWire graph
        # quantum to 8192 frames (185 ms at 44100 Hz). When Spotify pauses or
        # skips, the quantum collapses. When Spotify tries to reopen its stream,
        # the quantum renegotiation fails → "Can't play the current song."
        # The stressed node showed W/Q = 6.00 (waiting 6× its own quantum).
        # Capping max-quantum at 1024 prevents the huge jump. Spotify still
        # works fine at 1024 (21 ms buffer); it just can't destabilise the graph.
        "default.clock.max-quantum" = 1024;

        # BUG FIX ROUND 2 (2026-09-01): max-quantum alone did NOT fix it.
        # Confirmed live via `pw-top`: Spotify's own stream node was still
        # running at QUANT=8192 while the actual driver (the active sink)
        # ran at QUANT=1024 — max-quantum only caps the shared graph/driver
        # clock negotiation, but Spotify plays at 44100 Hz against a 48000 Hz
        # graph clock, so PipeWire gives it its own resampler/adapter node.
        # That adapter negotiates its buffer size from Spotify's own
        # PulseAudio client request (pulse.attr.tlength), which slips right
        # past max-quantum entirely.
        # force-quantum is not a ceiling, it's a MANDATE: every node in the
        # graph, including foreign-rate adapter nodes like Spotify's, is
        # pinned to exactly this quantum, no negotiation possible.
        "default.clock.force-quantum" = 1024;
        "link.max-buffers"          = 16;
      };
    };

    # ============================================================
    # PIPEWIRE-PULSE CONFIGURATION
    # ============================================================
    # These settings tune the PulseAudio emulation layer that PipeWire
    # exposes to apps using libpulse.
    #
    # flat-volumes: PulseAudio's default "flat volumes" behaviour couples
    #   the per-stream volume to the master sink volume. If you raise
    #   Firefox to 100 %, PulseAudio also raises the master to 100 %.
    #   Setting flat-volumes = false makes each stream volume independent.
    #   THIS IS IMPORTANT FOR VOLUME BOOSTING: without flat-volumes=false,
    #   boosting one app's volume to 200 % lifts the master volume too,
    #   which can cause surprise volume jumps on other apps.
    #
    # resample.quality: 0 (fastest/worst) to 15 (slowest/best).
    #   At 15, the resampler uses a very long filter (like SoX's VHQ mode).
    #   For desktop use at 48 kHz, quality 10 is indistinguishable from 15
    #   and uses significantly less CPU. Set to 15 only if you do critical
    #   listening or mastering work.
    extraConfig.pipewire-pulse."99-haru-pulse" = {
      # BUG FIX: Spotify "Can't play the current song" on PipeWire.
      #
      # Root cause: Spotify (Electron/Chromium) opens a new PipeWire-pulse
      # client connection on every skip, pause, or track change — but never
      # properly closes the old ones. These dead clients accumulate until the
      # default limit of 64 is hit, at which point PipeWire refuses new
      # connections and Spotify gets "Can't play the current song".
      # Restarting Spotify clears all dead clients, which is why that fixes it.
      #
      # Fix: raise max.clients from the default 64 to 256.
      # This is enough headroom that the limit is never reached in practice,
      # even with heavy skipping. PipeWire still garbage-collects dead clients;
      # we just give it more room before it starts refusing new ones.
      #
      # Source: https://community.spotify.com/t5/Desktop-Linux/
      #         1-1-2-86-502-g8cd7fb22-Spotify-can-t-play-this-right-now
      "context.properties" = {
        "max.clients" = 256;
      };
      "pulse.properties" = {
        "server.default.fragments"     = 4;
        "server.default.fragment-size" = 4096;
        "pulse.idle.timeout"           = 0;
        "flat-volumes"                 = false;
      };
      "stream.properties" = {
        # High-quality resampling for all pulse streams.
        # 10 = high quality with reasonable CPU cost.
        # 15 = highest quality (use for audiophile / mastering work).
        "resample.quality" = 10;

        # Keep streams alive when paused (don't suspend them).
        # Prevents a ~200 ms "pop" / resume delay when a paused app
        # starts playing audio again.
        "node.pause-on-idle" = false;
      };

      # BUG FIX ROUND 4 (2026-09-01): the ACTUAL fix for Spotify's
      # 8192-frame quantum stall — pulse.rules, not WirePlumber node.rules.
      #
      # Three earlier attempts, all verified live via pw-top/pw-dump and
      # all confirmed NOT to work:
      #   Round 1 — default.clock.max-quantum = 1024 (in context.properties
      #             above). Only bounds PipeWire's native graph/driver
      #             clock negotiation. Never seen by pulse-protocol clients.
      #   Round 2 — default.clock.force-quantum = 1024. Confirmed live via
      #             `pw-metadata -n settings` that the value WAS set and
      #             held — but Spotify's node stayed at QUANT=8192 anyway.
      #             force-quantum only governs native PipeWire graph nodes.
      #   Round 3 — WirePlumber node.rules update-props node.latency, in
      #             the "15-spotify-fix" block below. Looked like it worked
      #             (pause-on-idle from the same block was false, as
      #             expected) but that was a false positive — pause-on-idle
      #             is ALSO set unconditionally for every pulse stream via
      #             stream.properties below, so it proved nothing about
      #             whether the match itself was firing.
      #
      # ROUND 5 (2026-09-01) — the REAL bug behind rounds 3 and 4 both
      # silently failing: the match key was wrong the whole time.
      #   matches = [ { "application.process.binary" = "spotify"; } ]
      # never matched anything. Confirmed via pw-dump that Spotify's actual
      # application.process.binary is ".spotify-wrapped" (leading dot, the
      # literal argv[0] of the wrapped binary) — not "spotify". Both the
      # round 3 WirePlumber rule and the round 4 pulse.rules block below
      # were no-ops from the start. application.name, by contrast, is a
      # clean "spotify" in both the client and node property dumps — that's
      # what both match blocks use now.
      #
      # The real mechanism (still applies from round 4): libpipewire-
      # module-protocol-pulse (the PA-compat server itself, configured
      # right here under extraConfig.pipewire-pulse) has its OWN client-
      # matching rule system — "pulse.rules" — applied BEFORE the node is
      # created, at the point where the client's requested stream
      # properties are still being assembled. This is the only layer that
      # sits early enough to actually override Spotify's self-chosen
      # 8192-frame buffer request.
      "pulse.rules" = [
        {
          matches = [
            { "application.name" = "spotify"; }
          ];
          actions = {
            update-props = {
              "node.latency" = "1024/44100";
            };
          };
        }
      ];
    };

    # ============================================================
    # WIREPLUMBER CONFIGURATION
    # ============================================================
    # WirePlumber is the session manager: it routes streams to devices,
    # saves/restores device volumes, and handles profile switching
    # (A2DP ↔ HSP/HFP for Bluetooth headsets).
    wireplumber.extraConfig = {
      # ---- Bluetooth audio ------------------------------------------
      # By default, WirePlumber switches a Bluetooth headset to the
      # hands-free profile (HSP/HFP) when a call application (e.g. Discord
      # voice) opens a microphone stream. This sounds terrible for music.
      # Disable auto-switch so you stay on A2DP (high-quality stereo)
      # and switch profiles manually in pavucontrol or blueman if needed.
      "10-bluez-settings" = {
        "wireplumber.settings" = {
          "bluetooth.autoswitch-to-headset-profile" = false;
        };
      };

      # ---- Spotify stream fix ---------------------------------------
      # Keep Spotify's audio node alive even when paused or between tracks.
      # Without this, WirePlumber can suspend the node mid-track or during
      # the brief gap between songs, causing the "Can't play" error when
      # Spotify tries to resume or open the next stream.
      #
      # NOTE (2026-09-01): a node.latency override was tried here in this
      # same block (round 3 of the quantum-stall bugfix). Confirmed via
      # pw-dump it had NO effect — WirePlumber's node.rules only sees this
      # node AFTER pipewire-pulse has already created it with its buffer
      # already negotiated, too late to change node.latency. The actual
      # working fix is the "pulse.rules" block above, in
      # extraConfig.pipewire-pulse — see the round 4/5 writeup there.
      # Separately (round 5): this block's match key was ALSO wrong —
      # application.process.binary is ".spotify-wrapped", not "spotify" —
      # so this rule was never matching Spotify at all until round 5 fixed
      # it to match on application.name instead. pause-on-idle below was
      # never actually tested by that broken match; it happens to also be
      # set unconditionally for all pulse streams via stream.properties,
      # which is what was masking the broken match this whole time.
      "15-spotify-fix" = {
        "node.rules" = [
          {
            matches = [
              { "application.name" = "spotify"; }
            ];
            actions = {
              update-props = {
                "node.pause-on-idle"              = false;
                "session.suspend-timeout-seconds" = 0;
              };
            };
          }
        ];
      };

      # ---- Suspend policy -------------------------------------------
      # By default WirePlumber suspends (powers down) audio devices that
      # haven't been used for a few seconds. This causes a ~200 ms delay
      # + audible pop the next time audio plays (the device has to wake up).
      # For HDMI/DP audio and USB DACs, disabling suspend eliminates this.
      # Trade-off: slightly higher idle power draw on those devices.
      "20-suspend-timeout" = {
        "monitor.alsa.rules" = [
          {
            matches = [{ "node.name" = "~alsa_output.*"; }];
            actions = {
              update-props = {
                # 0 = never suspend. Set to a positive integer (seconds) to re-enable.
                "session.suspend-timeout-seconds" = 0;
              };
            };
          }
        ];
      };
      "21-stream-suspend-timeout" = {
        "node.rules" = [
          {
            matches = [{ "media.class" = "Audio/Sink"; }];
            actions = {
              update-props = {
                "session.suspend-timeout-seconds" = 0;
              };
            };
          }
        ];
      };
    };
  };
}
