# dolphin can't find its ServiceMenus unless XDG_CONFIG_DIRS has kservice's etc/xdg
# and sycoca is built against it
_inputs: _final: prev: {
  kdePackages = prev.kdePackages.overrideScope (_kfinal: kprev: {
    dolphin = prev.symlinkJoin {
      name = "dolphin-wrapped";
      paths = [kprev.dolphin kprev.dolphin.dev];
      nativeBuildInputs = [prev.makeWrapper];
      postBuild = ''
        rm $out/bin/dolphin
        makeWrapper ${kprev.dolphin}/bin/dolphin $out/bin/dolphin \
          --set XDG_CONFIG_DIRS "${prev.libsForQt5.__internalKF5.kservice}/etc/xdg:$XDG_CONFIG_DIRS" \
          --run "${kprev.kservice}/bin/kbuildsycoca6 --noincremental ${prev.libsForQt5.__internalKF5.kservice}/etc/xdg/menus/applications.menu"
      '';
      passthru = (kprev.dolphin.passthru or {}) // {dev = kprev.dolphin.dev;};
    };
  });
}
