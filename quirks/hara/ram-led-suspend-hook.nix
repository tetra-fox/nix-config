{pkgs, ...}: {
  systemd.services.ram-led-suspend-hook = {
    description = "Manage RAM LEDs during suspend and resume";

    before = ["sleep.target"];
    wantedBy = ["sleep.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";

      # sleep
      ExecStart = "${pkgs.openrgb}/bin/openrgb --device 'ENE DRAM' --mode Off";

      # wake
      ExecStop = "${pkgs.openrgb}/bin/openrgb --device 'ENE DRAM' --mode Rainbow --speed 0";
    };
  };
}
