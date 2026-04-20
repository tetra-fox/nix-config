{
  lib,
  appimageTools,
  fetchurl,
  icu,
}:

let
  pname = "vrcx";
  version = "2026.02.11";

  src = fetchurl {
    url = "https://github.com/vrcx-team/VRCX/releases/download/v${version}/VRCX_${version}_x64.AppImage";
    hash = "sha256-IOOXhr7vk+VXbCUi4sMMsf87TF1CXoWJd82hvDcMc5k=";
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = _: [ icu ];

  extraInstallCommands =
    let
      contents = appimageTools.extractType2 { inherit pname version src; };
    in
    ''
      install -Dm444 ${contents}/vrcx.desktop $out/share/applications/vrcx.desktop
      substituteInPlace $out/share/applications/vrcx.desktop \
        --replace-warn 'Exec=AppRun' 'Exec=vrcx'
      install -Dm444 ${contents}/vrcx.png $out/share/pixmaps/VRCX.png
    '';

  meta = {
    description = "Friendship management tool for VRChat";
    homepage = "https://github.com/vrcx-team/VRCX";
    license = lib.licenses.gpl3Only;
    mainProgram = "vrcx";
    platforms = [ "x86_64-linux" ];
  };
}
