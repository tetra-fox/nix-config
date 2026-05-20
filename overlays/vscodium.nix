# bump vscodium past nixpkgs' 1.112.01907 pin. some extensions require
# 1.116+. remove this overlay once nixpkgs catches up.
# https://github.com/VSCodium/vscodium/releases/tag/1.116.02821
final: prev: {
  vscodium = prev.vscodium.overrideAttrs (_: let
    version = "1.116.02821";
    inherit (prev.stdenv.hostPlatform) system isDarwin;
    plat =
      {
        x86_64-linux = "linux-x64";
        x86_64-darwin = "darwin-x64";
        aarch64-linux = "linux-arm64";
        aarch64-darwin = "darwin-arm64";
      }
      .${system};
    hash =
      {
        x86_64-linux = "sha256-gscXPWqnQV9nd9XWbL5YkCdyxxnDDEY4WpFAgx5G7a0=";
        x86_64-darwin = "sha256-H6sKVtQi++U7NvSkKWipjDDJQsTu0Zg3tp9kijL85eU=";
        aarch64-linux = "sha256-09C5ER/nZBphWHZRRAf9o/hyB6qc2mqIuxOLNdlVSfU=";
        aarch64-darwin = "sha256-utDPI80JCPcXTFvK65UR5CBlyb+EsocpHM0KWeojaUI=";
      }
      .${system};
    archive_fmt =
      if isDarwin
      then "zip"
      else "tar.gz";
  in {
    inherit version;
    src = prev.fetchurl {
      url = "https://github.com/VSCodium/vscodium/releases/download/${version}/VSCodium-${plat}-${version}.${archive_fmt}";
      inherit hash;
    };
  });
}
