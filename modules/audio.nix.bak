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
        "default.clock.quantum"     = 512;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 8192;
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
      "context.properties" = {
        # Disable flat volumes (per-stream volumes are independent of master)
        "pulse.default.req" = "256/48000"; # pulse request quantum
      };
      "pulse.properties" = {
        # server.default.fragments and fragment-size control the pulse
        # timing buffer. 2 fragments of 960 bytes each = minimal latency
        # for pulse apps without sacrificing stability.
        "server.default.fragments"     = 2;
        "server.default.fragment-size" = 960;
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
    };
  };
}
