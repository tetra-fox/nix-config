{lib, ...}: let
  dashboardSubmodule = lib.types.submodule {
    options = {
      id = lib.mkOption {
        type = lib.types.int;
        description = "grafana.com dashboard ID";
      };
      revision = lib.mkOption {
        type = lib.types.int;
        description = "specific revision to pin (find on the dashboard's grafana.com page)";
      };
      sha256 = lib.mkOption {
        type = lib.types.str;
        description = "sha256 of the fetched JSON (SRI or hex form)";
      };
      name = lib.mkOption {
        type = lib.types.str;
        description = "filename (no extension) - shows as dashboard slug in grafana";
      };
      datasource = lib.mkOption {
        type = lib.types.str;
        default = "prometheus";
        description = "value to replace \${DS_PROMETHEUS} with at build time";
      };
    };
  };
in {
  # shared options surface for grafana.com community dashboards. service
  # modules (docker, nvidia, ...) push their own dashboards onto
  # lab.observability.communityDashboards; the monitoring module reads the
  # full list and provisions grafana from it. declaring the option in a
  # tiny module that producers import lets a host import e.g. docker alone
  # without erroring on a missing option - the contribution is just silent
  # if no monitoring consumer reads it.
  #
  # prometheus scrape jobs do NOT go through here - service modules write
  # directly to services.prometheus.scrapeConfigs (a free-form list option
  # nixpkgs already declares whether or not prometheus is enabled).
  options.lab.observability.communityDashboards = lib.mkOption {
    type = lib.types.listOf dashboardSubmodule;
    default = [];
    description = ''
      Grafana dashboards (by grafana.com id + revision) contributed by service
      modules. Fetched at build time and provisioned via the monitoring module.
    '';
  };
}
