{...}: {
  services.pipewire.wireplumber.extraConfig."99-scarlett-volume-lock" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          {"node.name" = "~alsa_output.usb-Focusrite_Scarlett_2i2.*";}
        ];
        actions = {
          update-props = {
            "channelmix.lock-volumes" = true;
          };
        };
      }
    ];
  };
}
