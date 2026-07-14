{ lib
, stdenvNoCC
, fetchurl
}:

stdenvNoCC.mkDerivation {

    pname = "sober";

    version = "2026-06-22";

    src = fetchurl {

        url = "https://sober.vinegarhq.org/artifacts/2026-06-22_e24358e/c3e13e8abb1f0b8d02add53e0d1ad1cba3adff77822689fa574c1f6b746824de/sober-binaries-unified.tar.zst";

        hash = "sha256-...";
    };

    installPhase = ''

      install -Dm755 sober $out/bin/sober
      install -Dm755 sober_services $out/bin/sober_services
      install -Dm755 libmimalloc.so $out/bin/libmimalloc.so
      install -Dm755 libloader.so $out/bin/libloader.so
      install -Dm755 libbadcpu.so $out/bin/libbadcpu.so

      install -Dm644 org.vinegarhq.Sober.metainfo.xml \
        $out/share/metainfo/org.vinegarhq.Sober.metainfo.xml

      install -Dm644 org.vinegarhq.Sober.desktop \
        $out/share/applications/org.vinegarhq.Sober.desktop

      install -Dm644 sober.svg \
        $out/share/icons/hicolor/scalable/apps/org.vinegarhq.Sober.svg

      install -Dm644 notice.txt \
        $out/share/licenses/org.vinegarhq.Sober/EULA.txt

      install -Dm644 privacy.txt \
        $out/share/licenses/org.vinegarhq.Sober/PRIVACY.txt

    '';

    meta = with lib; {
      description = "Native Linux launcher for Roblox";
      homepage = "https://sober.vinegarhq.org/";
      license = licenses.unfree;
      platforms = platforms.linux;
    };

}