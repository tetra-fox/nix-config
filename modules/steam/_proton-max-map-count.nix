{...}: {
  # required by some Proton games
  boot.kernel.sysctl."vm.max_map_count" = 2147483642;
}
