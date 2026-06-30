{pkgs, ...}: {
  services.pipewire.wireplumber = {
    extraLadspaPackages = [pkgs.rnnoise-plugin];

    extraScripts."rnnoise-dynamic.lua" = builtins.readFile ./rnnoise-dynamic.lua;

    extraConfig."99-rnnoise-dynamic" = {
      "wireplumber.components" = [
        {
          name = "rnnoise-dynamic.lua";
          type = "script/lua";
          provides = "custom.rnnoise-dynamic";
          arguments = {
            "vad.threshold" = 60.0;
            "vad.grace-ms" = 200;
            "vad.retro-grace-ms" = 0;
          };
        }
      ];
      "wireplumber.profiles".main."custom.rnnoise-dynamic" = "required";
    };
  };
}
