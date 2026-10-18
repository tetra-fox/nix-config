# built against the exact kwin it loads into. kwin skips plugins whose
# PluginFactory_iid (which embeds its version) doesn't match
{
  stdenv,
  cmake,
  pkg-config,
  kdePackages,
}:
stdenv.mkDerivation {
  pname = "kwin-meta-click";
  version = kdePackages.kwin.version;
  src = ./.;

  nativeBuildInputs = [
    cmake
    kdePackages.extra-cmake-modules
    pkg-config
  ];
  buildInputs = [kdePackages.kwin];
  # a plugin, there's no executable to wrap
  dontWrapQtApps = true;
}
