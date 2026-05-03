# pascal: open modules need turing+, only supported through legacy 580.
{config, ...}: {
  hardware.nvidia = {
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };
}
