{
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.surge-dm];

  xdg.configFile."surge/settings.json".text = builtins.toJSON {
    general.warn_on_duplicate = false;
    extension.extension_prompt = false;
  };

  systemd.user.services.surge-dm = {
    Unit = {
      Description = "Surge download manager daemon";
      After = ["network.target"];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.surge-dm} server start";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = ["default.target"];
  };
}
