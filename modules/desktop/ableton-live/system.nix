{
  inputs,
  pkgs,
  ...
}: {
  environment.systemPackages = [
    inputs.ableton-linux.packages.${pkgs.stdenv.hostPlatform.system}.ableton-wine
  ];

  # wine sync for live's audio deadlines. the device is 0666, no udev rule needed
  boot.kernelModules = ["ntsync"];
}
