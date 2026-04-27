{
  # openldap's test017/test018 syncreplication tests are timing-sensitive
  # and flake under sandbox load, see NixOS/nixpkgs#440594 and #372569
  # pulled in transitively via bottles, only needed at build time
  nixpkgs.overlays = [
    (_: prev: {
      openldap = prev.openldap.overrideAttrs (_: {
        doCheck = false;
      });
    })
  ];
}
