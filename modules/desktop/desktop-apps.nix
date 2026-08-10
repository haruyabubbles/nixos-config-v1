# ============================================================
# modules/desktop/desktop-apps.nix
#
# Cinnamon-equivalent desktop application suite for the NNN stack.
# (Niri + Noctalia + NixOS)
#
# HOW IT LINKS:
#   Imported by → hosts/victus/configuration.nix
#   These packages complement modules/desktop/nnn.nix (which handles
#   the compositor, shell, and login manager).
#
# WHY THIS FILE EXISTS:
#   Cinnamon ships a full app suite: archive manager, image viewer,
#   display settings, Bluetooth manager, sound settings, disk utility,
#   calendar, calculator, etc. The NNN stack is a compositor + shell,
#   not a full DE, so these must be chosen and installed explicitly.
#   This file provides feature-parity with a Cinnamon install.
#
# ORGANISATION:
#   1. Audio / Sound
#   2. Bluetooth
#   3. Display / Monitor configuration
#   4. GTK / QT theming
#   5. File management
#   6. Image / Media viewing
#   7. Office / Documents
#   8. System tools (disk, fonts, keyring, system monitor)
#   9. Wayland-specific tools
#   10. Idle management / logout screen
# ============================================================
{ config, pkgs, lib, ... }:

{
  # ============================================================
  # QT THEMING — Match Qt apps to the GTK/Catppuccin theme
  # ============================================================
  # Qt apps (VLC, OBS Qt widgets, etc.) render with their own theme
  # engine. Without this config they look out of place on a GTK desktop.
  # qt5ct / qt6ct are the GUI config tools; kvantum is a theme engine
  # that can follow the GTK colour scheme exactly.
  environment.sessionVariables = {
    # Tell Qt 5 and Qt 6 apps to read their platform/style from qt5ct/qt6ct
    # instead of auto-detecting (which usually results in an ugly Fusion style).
    QT_QPA_PLATFORMTHEME = "qt6ct";
  };

  environment.systemPackages = with pkgs; [

    # ============================================================
    # 1. AUDIO / SOUND
    # ============================================================

    # PulseAudio Volume Control — full-featured audio mixer GUI.
    # Works with PipeWire's PulseAudio emulation layer out of the box.
    # Features: per-app volume, device switching, input monitor.
    # Cinnamon equivalent: Sound Settings (simpler), this is more powerful.
    # Usage: pavucontrol
    pavucontrol

    # EasyEffects — system-wide audio processing pipeline.
    # Sits between PipeWire and your apps, applying effects to all audio:
    #   - Loudness Equalizer (for making quiet content louder safely)
    #   - Bass Enhancer       (add sub-bass punch to thin laptop speakers)
    #   - Parametric EQ       (10-band or custom-frequency EQ)
    #   - Compressor          (makes loud parts quieter, quiet parts louder)
    #   - Limiter             (hard ceiling to prevent clipping at high volumes)
    #   - Stereo Widener      (spatial audio effect)
    #   - Convolver           (room/speaker impulse response simulation)
    # The "Loudness Equalizer" preset + gain boost is the clean way to
    # exceed 100 % volume without the distortion you get from pactl alone.
    # Usage: easyeffects  (then enable via the systray icon in Noctalia)
    easyeffects

    # ============================================================
    # 2. BLUETOOTH
    # ============================================================

    # Blueman — full-featured Bluetooth manager with system-tray applet.
    # Features: device pairing, connection management, file transfer,
    # audio profile switching (A2DP ↔ HSP/HFP).
    # The blueman-applet runs in the system tray (SNI protocol → Noctalia).
    # Cinnamon equivalent: Bluetooth settings panel (less powerful).
    # Usage: blueman-manager  /  blueman-applet (tray icon at login)
    blueman

    # ============================================================
    # 3. DISPLAY / MONITOR CONFIGURATION
    # ============================================================

    # wdisplays — Wayland display configuration GUI.
    # Drag-and-drop monitor arrangement, resolution, refresh rate, scaling.
    # Cinnamon equivalent: Display Settings.
    # NOTE: Changes are applied live but not persistent. To make them
    # permanent, write them to ~/.config/kanshi/config (see kanshi below).
    # Usage: wdisplays
    wdisplays

    # kanshi — automatic monitor profile switching.
    # Detects connected monitors and applies a pre-configured layout.
    # Example use: dock at home (3-monitor setup) vs. laptop-only (travel).
    # Configure at: ~/.config/kanshi/config
    # Usage: kanshi (runs as a background daemon, start at login via systemd)
    kanshi

    # wlr-randr — Wayland CLI for display config (like xrandr for Wayland).
    # Useful for scripting monitor changes or quick command-line adjustments.
    # Usage: wlr-randr  (lists modes)
    #        wlr-randr --output HDMI-A-1 --mode 1920x1080@60
    wlr-randr

    # ============================================================
    # 4. GTK / QT THEMING
    # ============================================================

    # nwg-look — GTK 3/4 theme settings for Wayland.
    # Sets cursor theme, icon theme, GTK colour scheme, font rendering.
    # Cinnamon equivalent: Themes settings panel.
    # NOTE: this is the Wayland equivalent of lxappearance.
    # Usage: nwg-look
    nwg-look

    # Qt 6 theme configuration tool.
    # Set Qt 6 app style, icon theme, font to match GTK (Catppuccin).
    # Renamed from `qt6ct` to `qt6Packages.qt6ct` in nixpkgs 26.05.
    # Usage: qt6ct
    qt6Packages.qt6ct

    # Qt 5 theme configuration (for older Qt 5 apps like older VLC, etc.)
    # Usage: qt5ct
    libsForQt5.qt5ct

    # Kvantum — Qt theme engine with full SVG-based skinning.
    # Lets Qt apps use a Catppuccin kvantum theme that matches the GTK theme.
    # Install: get a Catppuccin Kvantum theme from GitHub and apply in kvantummanager.
    # Usage: kvantummanager
    libsForQt5.qtstyleplugin-kvantum
    kdePackages.qtstyleplugin-kvantum

    # Adwaita Qt theme — makes Qt apps look like GNOME/Adwaita.
    # Package is named `adwaita-qt` in nixpkgs (covers both Qt5 and Qt6).
    adwaita-qt

    # ============================================================
    # 5. FILE MANAGEMENT
    # ============================================================

    # File Roller — archive manager (zip, tar, 7z, rar, etc.).
    # Integrates with Nemo for right-click "Extract Here" / "Add to archive".
    # Cinnamon equivalent: Archive Manager (same app, File Roller).
    file-roller

    # Dolphin (optional KDE file manager — more features than Nemo).
    # Better network share browsing (SMB, SFTP), split view, tabs.
    # Uncomment if you prefer Dolphin over Nemo for heavy file management:
    # dolphin

    # ============================================================
    # 6. IMAGE / MEDIA VIEWING
    # ============================================================

    # Loupe — GNOME 45+ image viewer. Fast, minimal, gesture-friendly.
    # Handles HEIC, AVIF, WebP, RAW (via libraw), SVG, and all common formats.
    # Cinnamon equivalent: Image Viewer (eog / gnome-photos).
    loupe

    # gThumb — more powerful image viewer with editing and slide-show.
    # Batch rename, resize, colour correction, GPS map view, web album export.
    # Use loupe for quick viewing, gthumb for batch operations.
    gthumb

    # MPV (media player — already in development.nix, listed here for clarity)
    # Used by: ani-cli, lobster. Also the best standalone video player.

    # ============================================================
    # 7. OFFICE / DOCUMENTS
    # ============================================================

    # GNOME Text Editor — modern replacement for gedit.
    # Syntax highlighting, session restore, Vi keybindings option.
    # Cinnamon equivalent: Text Editor (gedit).
    gnome-text-editor

    # Evince — document viewer for PDF, DjVu, PostScript, TIFF, CBZ.
    # Fast, minimal, supports forms and annotations.
    # Cinnamon equivalent: Document Viewer (same app).
    evince

    # Okular — KDE document viewer with PDF annotations + signing.
    # More powerful than Evince for annotating research papers.
    # KDE packages live under kdePackages.* in nixpkgs 26.05.
    kdePackages.okular

    # GNOME Calculator — scientific + programmer + unit conversion modes.
    # Cinnamon equivalent: Calculator (same underlying GNOME app).
    gnome-calculator

    # GNOME Calendar — calendar app that syncs with GNOME Online Accounts.
    # Cinnamon equivalent: Calendar applet (less powerful).
    gnome-calendar

    # ============================================================
    # 8. SYSTEM TOOLS
    # ============================================================

    # GNOME Disk Utility — graphical disk manager.
    # Format drives, create/restore disk images, run SMART tests,
    # benchmark read speed, manage partitions, set up LUKS encryption.
    # Cinnamon equivalent: Disks (same app).
    # Usage: gnome-disk-utility
    gnome-disk-utility

    # GNOME Font Viewer — preview and install fonts.
    # Drag a .ttf / .otf file onto it to preview or install for the current user.
    # Cinnamon equivalent: Font Viewer (same app).
    gnome-font-viewer

    # Seahorse — GNOME Keyring GUI manager.
    # View, add, and delete passwords, SSH keys, PGP keys, and certificates
    # stored in GNOME Keyring (which is already enabled via gnome-keyring.enable).
    # Cinnamon equivalent: Passwords and Keys (same app).
    seahorse

    # Resources — modern system monitor with per-process GPU tracking.
    # Shows CPU (per-core), RAM, GPU (NVIDIA + Intel), disk I/O, network,
    # and a list of running apps with per-resource breakdown.
    # This is BETTER than Cinnamon's System Monitor.
    resources

    # GNOME System Monitor (classic alternative to Resources).
    # Already familiar from GNOME/Cinnamon. Simpler but reliable.
    # Cinnamon equivalent: System Monitor.
    gnome-system-monitor

    # dconf Editor — view and edit ALL GSettings/dconf keys.
    # Like regedit but for GNOME settings. Useful for tweaking hidden options
    # that aren't exposed in any GUI. Use with care; wrong values can break things.
    # Usage: dconf-editor
    dconf-editor

    # NetworkManager GUI — advanced connection editor.
    # Edit VPN configs, static IPs, DNS, WiFi enterprise (802.1X), bonds, bridges.
    # Noctalia's network panel handles common cases; this handles edge cases.
    # Usage: nm-connection-editor
    networkmanagerapplet # Provides nm-connection-editor + nm-applet (tray)

    # Simple Scan — easy scanner / document scanner GUI.
    # Scan to PDF or JPEG; handles multi-page documents.
    # Cinnamon equivalent: Document Scanner (same app).
    simple-scan

    # ============================================================
    # 9. WAYLAND-SPECIFIC TOOLS
    # ============================================================

    # wf-recorder — simple Wayland screen recorder.
    # Records a region (with slurp for selection) or full screen to video.
    # OBS Studio (in development.nix) is better for streaming; wf-recorder
    # is better for quick CLI recordings without launching a full GUI.
    # Usage:
    #   wf-recorder -g "$(slurp)" -f recording.mp4   # record region
    #   wf-recorder -f output.mp4                      # record full screen
    #   Ctrl+C to stop
    wf-recorder

    # wl-screenrec — GPU-accelerated Wayland screen recorder (alternative).
    # Uses VAAPI hardware encoding for very low CPU overhead recordings.
    # Usage: wl-screenrec -g "$(slurp)" -f out.mp4
    wl-screenrec

    # Flameshot — advanced screenshot tool with annotation.
    # More features than grim+swappy: text, arrows, blur, upload to imgur.
    # Has a Wayland backend. Can be bound to Print key in niri config.
    # Usage: flameshot gui
    flameshot

    # xdg-utils — provides xdg-open, xdg-mime, xdg-settings.
    # xdg-open <file> opens a file with its default application.
    # Already likely pulled in transitively, but explicitly listed here.
    xdg-utils

    # handlr-regex — smarter xdg-open replacement.
    # Sets and queries per-MIME-type default apps from the command line.
    # Usage: handlr set text/plain kitty.desktop
    #        handlr open README.md
    handlr-regex

    # ============================================================
    # 10. IDLE / LOGOUT / LOCK
    # ============================================================

    # wlogout — Wayland logout / reboot / shutdown / lock screen.
    # Opens a full-screen overlay with: logout, reboot, shutdown, lock,
    # hibernate, suspend — with customisable icons and keybindings.
    # Cinnamon equivalent: the logout dialog (more polished but same concept).
    # Bind to Mod+Shift+E in niri config:
    #   binds { Mod+Shift+E { spawn "wlogout"; } }
    # Usage: wlogout
    wlogout

    # swayidle — idle timeout daemon.
    # Runs commands after N seconds of inactivity: dim screen, lock,
    # turn off display, suspend. Works on all Wayland compositors.
    # Configure with a command in niri's spawn-at-startup or systemd.
    # Example: swayidle -w timeout 300 'noctalia lock' timeout 600 'systemctl suspend'
    # Usage: swayidle (configure per-user; see comment above)
    swayidle

    # ============================================================
    # BONUS: Useful daily-driver apps
    # ============================================================

    # Thunar — lightweight XFCE file manager (alternative to Nemo).
    # Faster startup than Nemo; good for quick file operations.
    # Uncomment if you want it as a secondary option:
    # xfce.thunar

    # GNOME Clocks — world clock, alarm, stopwatch, timer.
    # Cinnamon equivalent: Calendar applet + separate clock widget.
    gnome-clocks

    # GNOME Weather — weather forecast app (uses local weather service).
    gnome-weather

    # Mission Center — another modern resource monitor (Electron-based).
    # Has beautiful graphs and a very clean UI.
    # Usage: mission-center
    mission-center

    # Impression — simple USB image flasher GUI (like Balena Etcher).
    # Flash Linux ISOs, NixOS images to USB drives with a GUI.
    # Usage: impression
    impression
  ];
}
