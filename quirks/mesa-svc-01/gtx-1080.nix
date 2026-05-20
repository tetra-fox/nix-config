# pascal needs the legacy 580 driver; open modules require turing+
{config, ...}: {
  hardware.nvidia = {
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };
}
