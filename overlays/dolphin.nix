# dolphin can't find its own ServiceMenus/actions unless XDG_CONFIG_DIRS includes the
# kservice etc/xdg path and the sycoca cache is built against it. upstream ships dolphin
# without that wiring, so wrap the binary to set XDG_CONFIG_DIRS and rebuild the sycoca
# on launch. the join also pulls in dolphin.dev so the .dev output stays available.
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
