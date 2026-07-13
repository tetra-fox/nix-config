# options-only, so a consumer (authentik's containers read autoUpdate.containerLabels)
# can import the lab.podman contract without dragging in the podman backend itself.
# same pattern as postgres/options.nix and monitoring/registry.nix.
{
  config,
  lib,
  ...
}: let
  cfg = config.lab.podman;
in {
  options.lab.podman = {
    autoUpdate = {
      enable = lib.mkEnableOption "podman-auto-update timer (nightly pull+recreate of containers labelled io.containers.autoupdate=registry)";

      # deriving the container names here instead would recurse on oci-containers.containers
      containerLabels = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        readOnly = true;
        default = lib.optionalAttrs cfg.autoUpdate.enable {
          "io.containers.autoupdate" = "registry";
        };
      };
    };

    cadvisor = {
      enable = lib.mkEnableOption "cadvisor container metrics";
      port = lib.mkOption {
        type = lib.types.port;
        default = 8081; # 8080 collides with sabnzbd
      };
    };
  };
}
