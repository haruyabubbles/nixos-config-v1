# BUG FIX: was { pkgs ? import <nixpkgs> {} }: which breaks callPackage.
# callPackage matches argument names to pkgs attributes. "pkgs" is not a
# pkgs attribute, so the default fired — building against a separate nixpkgs.
# The outer derivation only needs lib/stdenv/fetchurl/buildFHSEnv/zstd;
# targetPkgs receives the full pkgs set from buildFHSEnv internally.
{ lib, stdenv, fetchurl, buildFHSEnv, zstd }:

let
  sober-assets = stdenv.mkDerivation {
    pname = "sober-assets";
    version = "2026-06-22";

    src = fetchurl {
      url = "https://sober.vinegarhq.org/artifacts/2026-06-22_e24358e/c3e13e8abb1f0b8d02add53e0d1ad1cba3adff77822689fa574c1f6b746824de/sober-binaries-unified.tar.zst";
      hash = "sha256-w+E+irsfC40CrdU+DRrRy6Ot/3eCJon6V0wfa3RoJN4=";
    };

    nativeBuildInputs = [ zstd ];

    dontBuild = true;

    installPhase = ''
      mkdir -p $out/libexec
      cp sober sober_services libmimalloc.so libloader.so libbadcpu.so $out/libexec/

      install -Dm644 org.vinegarhq.Sober.metainfo.xml $out/share/metainfo/org.vinegarhq.Sober.metainfo.xml
      install -Dm644 org.vinegarhq.Sober.desktop $out/share/applications/org.vinegarhq.Sober.desktop
      install -Dm644 sober.svg $out/share/icons/hicolor/scalable/apps/org.vinegarhq.Sober.svg
    '';
  };

in
buildFHSEnv {
  name = "sober";

  runScript = "${sober-assets}/libexec/sober";

  targetPkgs = pkgs: with pkgs; [
    glibc
    zlib
    zstd
    stdenv.cc.cc.lib
    gtk3
    gtk4
    webkitgtk_6_0
    libadwaita
    glib
    cairo
    pango
    atk
    gdk-pixbuf
    gsettings-desktop-schemas
    libseccomp
    openssl
    curl
    libuuid
    dbus
    libsecret
    libgcrypt
    libxml2
    icu
    libsoup_3
    flatpak
    bubblewrap
    libGL
    libGLU
    mesa
    vulkan-loader
    libdrm
    udev
    libva
    wayland
    libxkbcommon
    libxcb
    xorg.libX11
    xorg.libXext
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXinerama
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXtst
    xorg.libXxf86vm
    xorg.libXScrnSaver
    alsa-lib
    libpulseaudio
    pipewire
    libjack2
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    fontconfig
    freetype
    nss
    nspr
    expat
  ];

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

  meta = with lib; {
    description = "Declarative standalone native Linux deployment for Roblox";
    homepage = "https://sober.vinegarhq.org/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
