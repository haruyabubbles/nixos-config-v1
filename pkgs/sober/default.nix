{ pkgs ? import <nixpkgs> {} }:

let
  # Step 1: Extract the raw assets from the Flatpak distribution bundle
  sober-unwrapped = pkgs.stdenv.mkDerivation rec {
    pname = "sober-unwrapped";
    version = "1.0";

    src = fetchurl {
      # The flatpak endpoint containing the compressed ostree layer
      url = "https://sober.vinegarhq.org/repo/app/org.vinegarhq.Sober/x86_64/stable/active";
      # You will need to populate this with the true sha256 hash using `nix-prefetch-url`
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };

    # We need ostree or flatpak tools to natively unpack the bundle layer
    nativeBuildInputs = [ pkgs.flatpak pkgs.ostree ];

    dontBuild = true;

    unpackPhase = ''
      # Pull the raw files out of the flatpak bundle archive
      flatpak build-bundle --extract=extracted_dir $src
      cd extracted_dir
    '';

    installPhase = ''
      mkdir -p $out/share
      # Copy the internal files directory where the raw binary lives
      cp -r files $out/files
      
      # Grab the desktop icons/shortcuts for later use
      cp -r metadata $out/metadata
    '';
  };

in
# Step 2: Wrap the unwrapped binary inside a simulated standard Linux environment
pkgs.buildFHSEnv {
  name = "sober";

  # The executable that gets called when you type 'sober'
  runScript = "${sober-unwrapped}/files/bin/sober";

  # Target packages that will be mapped into /usr/lib and /lib inside the bubble
  targetPkgs = pkgs: with pkgs; [
    # Core system libraries
    glibc
    zlib
    
    # Graphics and windowing dependencies required by the Android translation layer
    libGL
    vulkan-loader
    xorg.libX11
    xorg.libXext
    xorg.libXcursor
    xorg.libXi
    
    # Audio frameworks
    alsa-lib
    libpulseaudio
  ];

  # Extra instructions to set up paths inside the chroot environment
  extraOutputsToInstall = [ "dev" ];
  
  extraInstallCommands = ''
    # Copy desktop launcher metadata into the final package output
    mkdir -p $out/share/applications
    cp ${sober-unwrapped}/files/share/applications/org.vinegarhq.Sober.desktop $out/share/applications/sober.desktop
    
    # Rewrite the shortcut launcher to point to our newly created FHS binary wrapper
    substituteInPlace $out/share/applications/sober.desktop \
      --replace "Exec=flatpak run org.vinegarhq.Sober" "Exec=$out/bin/sober"
  '';

  meta = with pkgs.lib; {
    description = "Sober Roblox runtime client running inside a declarative Nix FHS bubble";
    homepage = "https://sober.vinegarhq.org/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}