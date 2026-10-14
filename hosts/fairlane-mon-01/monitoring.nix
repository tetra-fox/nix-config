# no authentik at fairlane, so grafana keeps its own login
{
  config,
  modules,
  ...
}: {
  imports = [modules.services.monitoring.unifi];

  lab.monitoring.unifi = {
    enable = true;
    controllerUrl = "https://${config.lab.net.gateway}";
  };
}
