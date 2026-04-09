{ stdenvNoCC, fetchurl }:

stdenvNoCC.mkDerivation {
  pname = "apple-color-emoji-linux";
  version = "macos-26-20260219";
  src = fetchurl {
    url = "https://github.com/samuelngs/apple-emoji-ttf/releases/download/macos-26-20260219-2aa12422/AppleColorEmoji-Linux.ttf";
    hash = "sha256-U1oEOvBHBtJEcQWeZHRb/IDWYXraLuo0NdxWINwPUxg=";
  };
  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    install -D $src $out/share/fonts/truetype/AppleColorEmoji-Linux.ttf
    runHook postInstall
  '';
}
