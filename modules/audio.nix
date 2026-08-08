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
#   and JACK. Apps that use any of the three APIs all route
#   through it transparently.
# ============================================================
{ config, pkgs, ... }:

{
  # PulseAudio is NixOS's historical default audio daemon.
  # PipeWire and PulseAudio CANNOT coexist — if PulseAudio is
  # running it grabs the audio hardware first and PipeWire's
  # pulse emulation socket will never be reachable.
  # We set this explicitly to false so NixOS doesn't enable it
  # somewhere else in the module tree.
  services.pulseaudio.enable = false;

  # RealtimeKit (rtkit) is a small D-Bus service that grants
  # real-time CPU scheduling priority to audio threads on request.
  # PipeWire asks rtkit for elevated priority so its audio processing
  # thread never gets preempted by other workloads, preventing pops
  # and crackles under CPU load. Without rtkit, PipeWire still works
  # but audio quality degrades when the system is busy.
  security.rtkit.enable = true;

  services.pipewire = {
    # Start the PipeWire daemon.
    # This also enables WirePlumber — the session/policy manager
    # that decides which audio stream goes to which device and
    # handles automatic device switching (e.g. plug in headphones).
    enable = true;

    # ALSA compatibility layer.
    # Apps that use ALSA directly (many CLI tools like `aplay`,
    # some native Linux games, FFmpeg) will be redirected through
    # PipeWire instead of talking to the kernel device themselves.
    # Without this, ALSA apps bypass PipeWire and can conflict with it.
    alsa.enable = true;

    # 32-bit ALSA support.
    # Required for 32-bit games (Proton, Wine, Steam's 32-bit titles)
    # to produce sound. The 32-bit libpipewire-alsa library is installed
    # alongside the 64-bit one. If you remove this, 32-bit apps go silent.
    alsa.support32Bit = true;

    # PulseAudio emulation socket.
    # Installs a compatibility socket at the standard PulseAudio path so
    # apps using libpulse (browsers, Spotify, Discord, most desktop apps)
    # talk to PipeWire without knowing it. This is what most audio in
    # everyday use goes through.
    pulse.enable = true;

    # JACK emulation socket.
    # JACK is a professional audio API used by DAWs (Ardour, REAPER,
    # Carla), audio plugins (LV2, VST), and low-latency music tools.
    # PipeWire opens a JACK-compatible socket so those apps work without
    # a separate JACK daemon. Safe to leave on even if you don't use
    # JACK apps — it just opens an extra socket that stays idle.
    jack.enable = true;

    # The old media-session was PipeWire's first session manager.
    # It was replaced by WirePlumber (enabled automatically when
    # `enable = true` above). There is nothing else to choose from,
    # so this stays commented out.
    #media-session.enable = true;
  };
}
