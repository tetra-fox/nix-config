{
  config,
  pkgs,
  ...
}: {
  # xrizer reads $XRIZER_CUSTOM_BINDINGS_DIR/<controller_type>.json; set it per-game
  # in Steam -> game -> Properties -> Launch Options, e.g.
  #   XRIZER_CUSTOM_BINDINGS_DIR=/home/tetra/.local/share/xrizer-bindings/vrchat %command%
  home.file.".local/share/xrizer-bindings".source = ./_xrizer-bindings;

  # vrchat dumps screenshots inside the wine prefix; symlink them out to ~/Pictures/VRChat
  systemd.user.tmpfiles.rules = let
    target = "${config.home.homeDirectory}/Pictures/VRChat";
    link = "${config.home.homeDirectory}/.local/share/Steam/steamapps/compatdata/438100/pfx/drive_c/users/steamuser/Pictures/VRChat";
  in [
    "d ${target} 0755 - - - -"
    "L+ ${link} - - - - ${target}"
  ];

  xdg.configFile = {
    "wayvr/openxr_actions.json5".source = ./_wayvr/openxr_actions.json5;

    "openxr/1/active_runtime.json".source = "${pkgs.monado}/share/openxr/1/openxr_monado.json";

    "openvr/openvrpaths.vrpath".text = let
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
  };
}
