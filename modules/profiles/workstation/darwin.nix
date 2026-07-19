# darwin face of the workstation profile: the mac is a workstation too.
# the linux face (system.nix) keeps the desktop/hardware stack that macos
# provides itself (audio, bluetooth, display, printing)
{modules, ...}: {
  imports = [
    modules.profiles.base.darwin

    modules.toolsets.archive.system
    modules.toolsets.general.system
    modules.toolsets.net.system

    modules.cli.rebuild.system
    modules.cli.yazi.system
  ];
}
