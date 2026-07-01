# recyclarr never deletes a profile (destructive when media is assigned), so a renamed
# or removed profile lingers. cleanup-profiles.sh reassigns everything on an orphaned
# profile to a managed default then deletes it. runs after recyclarr so it sees the
# current managed set (from profile-names.nix, the same list recyclarr builds from).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lab.arrStack;
  vpn = config.vpnNamespaces.wg;

  managedNames = import ./profile-names.nix;
  managedFile = pkgs.writeText "managed-profiles.json" (builtins.toJSON managedNames);

  cleanup = pkgs.writeShellApplication {
    name = "arr-cleanup-profiles";
    runtimeInputs = [pkgs.curl pkgs.jq];
    text = builtins.readFile ./cleanup-profiles.sh;
  };

  arrs = {
    sonarr = {
      port = cfg.lanProxyPorts.sonarr;
      apiKeySecret = "apps/sonarr_api_key";
    };
    radarr = {
      port = cfg.lanProxyPorts.radarr;
      apiKeySecret = "apps/radarr_api_key";
    };
  };

  mkUnit = arr: spec: let
    arrKeyCred = "${arr}-api-key";
  in {
    name = "${arr}-cleanup-profiles";
    value = {
      description = "delete unmanaged quality profiles from ${arr}";
      after = ["${arr}.service" "recyclarr.service"];
      wants = ["recyclarr.service"];
      wantedBy = ["multi-user.target"];
      environment = {
        APP = arr;
        BASE_URL = "http://${vpn.namespaceAddress}:${toString spec.port}/api/v3";
        ARR_KEY_FILE = "/run/credentials/${arr}-cleanup-profiles.service/${arrKeyCred}";
        MANAGED_FILE = managedFile;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        LoadCredential = ["${arrKeyCred}:${config.sops.secrets.${spec.apiKeySecret}.path}"];
        ExecStart = lib.getExe cleanup;
      };
    };
  };
in {
  config = {
    systemd.services = lib.mapAttrs' mkUnit arrs;
  };
}
