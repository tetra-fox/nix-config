{
  config,
  pkgs,
  ...
}: {
  # xrizer reads $XRIZER_CUSTOM_BINDINGS_DIR/<controller_type>.json
  # set it per-game in Steam -> game -> Properties -> Launch Options, e.g.
  #
  #   XRIZER_CUSTOM_BINDINGS_DIR=/home/tetra/.local/share/xrizer-bindings/vrchat %command%
  #
  # each game gets its own dir (./_xrizer-bindings/<game>/<controller>.json)
  # so the action names only apply to the intended game
  home.file.".local/share/xrizer-bindings".source = ./_xrizer-bindings;

  # wayvr is OpenXR-native so its bindings live in its own config file
  xdg.configFile."wayvr/openxr_actions.json5".source = ./_wayvr/openxr_actions.json5;

  # vrchat dumps screenshots inside the wine prefix by default. symlink
  # Pictures/VRChat to ~/Pictures/VRChat so they land somewhere
  # reachable. mkOutOfStoreSymlink because the target is mutable user data
  home.file.".local/share/Steam/steamapps/compatdata/438100/pfx/drive_c/users/steamuser/Pictures/VRChat".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Pictures/VRChat";

  # vrcx reads vrchat's playerprefs by running `wine reg query` against the
  # prefix. it finds wine at a hardcoded compatibilitytools.d/<tool>/files/bin/
  # wine, where <tool> is the name config.vdf maps appid 438100 to
  # (GE-Proton-rtsp here). but it execs that binary directly on the host via
  # bash, with no steam-runtime container. proton's own wine is a 32-bit binary
  # built for the pressure-vessel container (interpreter /lib/ld-linux.so.2,
  # absent on nixos), so it fails with "cannot execute: required file not
  # found". vrcx has no env/config override for the wine path, so the only
  # lever is this directory.
  #
  # give vrcx a host-runnable wine by faking the compat-tool layout it expects:
  # a dir named GE-Proton-rtsp with files/bin/wine pointing at nixpkgs wine.
  # steam itself doesn't use this dir for proton (it finds GE-Proton-rtsp via
  # STEAM_EXTRA_COMPAT_TOOLS_PATHS in the store), so vrchat launching is
  # unaffected. wineWowPackages handles the 64-bit prefix vrchat uses.
  home.file.".local/share/Steam/compatibilitytools.d/GE-Proton-rtsp".source =
    pkgs.runCommandLocal "vrcx-wine-shim" {} ''
      mkdir -p $out/files/bin
      ln -s ${pkgs.wineWow64Packages.stable}/bin/wine $out/files/bin/wine
    '';

  # link the monado runtime to openxr
  xdg.configFile."openxr/1/active_runtime.json".source = "${pkgs.monado}/share/openxr/1/openxr_monado.json";

  # point openvr to xrizer
  xdg.configFile."openvr/openvrpaths.vrpath".text = let
    steam = "${config.xdg.dataHome}/Steam";
  in
    builtins.toJSON {
      version = 1;
      jsonid = "vrpathreg";

      external_drivers = null;
      config = ["${steam}/config"];

      log = ["${steam}/logs"];

      runtime = [
        "${pkgs.xrizer}/lib/xrizer"
        # OR
        # "${pkgs.opencomposite}/lib/opencomposite"
      ];
    };
}
