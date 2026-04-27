{
  # remove once nixos-unstable advances past NixOS/nixpkgs#513244
  # openvr's prebuilt blob references jsoncpp symbols that only exist
  # when both are built with c++17, which breaks monado linking
  nixpkgs.overlays = [
    (_: prev: {
      openvr = prev.openvr.overrideAttrs (old: {
        postPatch =
          (old.postPatch or "")
          + ''
            substituteInPlace CMakeLists.txt --replace-fail "-std=c++11" "-std=c++17"
          '';
      });
    })
  ];
}
