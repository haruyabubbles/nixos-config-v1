
{ pkgs ? import <nixpkgs> {} }:

let
  sober-assets = pkgs.stdenv.mkDerivation {
    pname = "sober-assets";
    version = "2026-06-22";

    src = pkgs.fetchurl {
      url = "https://sober.vinegarhq.org/artifacts/2026-06-22_e24358e/c3e13e8abb1f0b8d02add53e0d1ad1cba3adff77822689fa574c1f6b746824de/sober-binaries-unified.tar.zst";
      hash = "Its a secret";
    };

    nativeBuildInputs = [ pkgs.zstd ];

    dontBuild = true;

    installPhase = ''
      mkdir -p $out/libexec
      cp sober sober_services libmimalloc.so libloader.so libbadcpu.so $out/libexec/

      # Metadata installation
      install -Dm644 org.vinegarhq.Sober.metainfo.xml $out/share/metainfo/org.vinegarhq.Sober.metainfo.xml
      install -Dm644 org.vinegarhq.Sober.desktop $out/share/applications/org.vinegarhq.Sober.desktop
      install -Dm644 sober.svg $out/share/icons/hicolor/scalable/apps/org.vinegarhq.Sober.svg
    '';
  };

in
pkgs.buildFHSEnv {
  name = "sober";

  #runScript = "${sober-assets}/libexec/sober";
  runScript = "bash";

  targetPkgs = pkgs: with pkgs; [
    # Base Core & C++ System Runtimes
    glibc
    zlib
    zstd
    stdenv.cc.cc.lib
    # GNOME / GTK3 Desktop UI Stack
    gtk3
    gtk4
    webkitgtk_6_0
    libadwaita # design and widget companion library for GTK4
    glib
    cairo
    pango
    atk
    gdk-pixbuf
    gsettings-desktop-schemas

    libseccomp
    
    # Security, Data Parsing & Networking Pipelines
    openssl
    curl
    libuuid
    dbus
    libsecret # Secure credential wallet link
    libgcrypt
    libxml2 # libxml2.so.16!
    icu # Essential data/string utility engine link
    libsoup_3
    flatpak
    bubblewrap
    
    # Kernel Device Interfaces & 3D Hardware Drivers
    libGL
    libGLU
    mesa # Explicit OpenGL/Mesa runtime drivers
    vulkan-loader
    libdrm
    udev                      # Device monitoring hooks (libudev.so.1)
    libva # Hardware accelerated decoding
    
    # Window Display Protocols X11 Workspace Frameworks
    wayland
    libxkbcommon
    libxcb
    libx11
    libxext
    libxcursor
    libxi
    libXrandr
    libXrender
    libXinerama
    libXcomposite
    libXdamage
    libXtst
    xorg.libXxf86vm # legacy fallback video mode control for engine contexts
    xorg.libXScrnSaver # this just screensaver so it can handling utility
    
    # Line setup for Audio Servers
    alsa-lib
    libpulseaudio
    pipewire
    libjack2
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    
    # Font for Rendering engine and typography layouts My style for robloX XD
    fontconfig
    freetype
    nss
    nspr
    expat
  ];

  # Maps all relevant hardware graphics driver environment blocks
  profile = ''
    export LD_LIBRARY_PATH="${sober-assets}/libexec:/run/opengl-driver/lib:/run/opengl-driver-32/lib:$LD_LIBRARY_PATH"
    export XDG_DATA_DIRS="$XDG_DATA_DIRS:/usr/share"
    export GTK_USE_PORTAL=1
  '';

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cp ${sober-assets}/share/applications/org.vinegarhq.Sober.desktop $out/share/applications/sober.desktop
    
    substituteInPlace $out/share/applications/sober.desktop \
      --replace "Exec=flatpak run org.vinegarhq.Sober" "Exec=$out/bin/sober" \
      --replace "Exec=sober" "Exec=$out/bin/sober"
  '';

  meta = with pkgs.lib; {
    description = "Declarative standalone native Linux deployment for Roblox";
    homepage = "https://sober.vinegarhq.org/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}