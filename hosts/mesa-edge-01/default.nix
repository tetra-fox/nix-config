{modules, ...}: {
  imports = [../common/edge-host.nix];

  lab = {
    sops.secretsFile = ../../secrets/mesa-edge-01.yaml;

    site.hostIp = "192.168.10.150";
    site.internalIp = "10.10.0.150";

    caddy.staticTail = import ../common/mesa-caddy-tail.nix;
  };
}
