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
