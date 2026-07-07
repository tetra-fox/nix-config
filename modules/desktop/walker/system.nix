_: {
  nix = {
    settings = {
      substitute = true;
      substituters = [
        "https://walker-git.cachix.org"
      ];
      trusted-public-keys = [
        "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
      ];
    };
  };
}
