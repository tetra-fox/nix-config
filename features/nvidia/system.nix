{ ... }:

{
  hardware = {
    graphics.enable = true;
    nvidia = {
      open = false; # fuck it we ball
      modesetting.enable = true;
      powerManagement.enable = true;
    };
  };

  services.xserver.videoDrivers = [ "nvidia" ];
}
