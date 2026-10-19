{modules, ...}: {
  imports = [
    modules.profiles.base.darwin

    modules.toolsets.net.system

    modules.cli.nh.darwin
    modules.cli.rebuild.system
    modules.cli.yazi.system
  ];
}
