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
  # prefix. it looks for wine at a hardcoded compatibilitytools.d/<tool>/files/
  # bin/wine, where <tool> is the name config.vdf maps appid 438100 to
  # (GE-Proton-rtsp). our proton comes from programs.steam.extraCompatPackages,
  # so it's in the nix store surfaced via STEAM_EXTRA_COMPAT_TOOLS_PATHS, a path
  # vrcx doesn't scan. symlink the real tool where vrcx expects it. steam finds
  # proton via the env var regardless, so vrchat launching is unaffected. the
  # 32-bit wine here runs because environment.ldso32 (see system.nix) provides
  # /lib/ld-linux.so.2.
  home.file.".local/share/Steam/compatibilitytools.d/GE-Proton-rtsp".source =
    pkgs.proton-ge-rtsp-bin.steamcompattool;

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
