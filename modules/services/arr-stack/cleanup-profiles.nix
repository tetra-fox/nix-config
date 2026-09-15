# recyclarr never deletes a profile (destructive when media is assigned), so a renamed
# or removed profile lingers. cleanup-profiles.sh reassigns everything on an orphaned
# profile to a managed default then deletes it. runs off recyclarr's OnSuccess so it sees
# the current managed set (from profiles.nix, the same list recyclarr builds from).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lab.arrStack;
  vpn = config.vpnNamespaces.wg;

  managedNames = (import ./profiles.nix).names;
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
      environment = {
        APP = arr;
        BASE_URL = "http://${vpn.namespaceAddress}:${toString spec.port}/api/v3";
        ARR_KEY_FILE = "/run/credentials/${arr}-cleanup-profiles.service/${arrKeyCred}";
        MANAGED_FILE = managedFile;
      };
      serviceConfig = {
        Type = "oneshot";
        LoadCredential = ["${arrKeyCred}:${config.sops.secrets.${spec.apiKeySecret}.path}"];
        ExecStart = lib.getExe cleanup;
      };
    };
  };
in {
  config = {
    systemd.services =
      lib.mapAttrs' mkUnit arrs
      // {
        # fires only after a completed sync. a wantedBy here would drag a full recyclarr run
        # into every boot and switch, before the arrs are listening
        recyclarr.onSuccess = map (arr: "${arr}-cleanup-profiles.service") (lib.attrNames arrs);
      };
  };
}
