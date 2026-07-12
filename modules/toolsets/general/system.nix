{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    ripgrep
    jq
    tree
    pv
    wget
  ];
}
