# partially instantiate the icon font with FILL=1 baked in
# Qt's variable font renderer has artifacts with the FILL axis, so we
# fix that axis and leave the rest (wght, GRAD, opsz) variable.
{pkgs}:
pkgs.runCommand "material-symbols-filled"
{
  nativeBuildInputs = [
    (pkgs.python3.withPackages (ps: [ps.fonttools]))
  ];
}
''
  mkdir -p $out/share/fonts/truetype
  python3 ${./fill-font.py} \
    "${pkgs.material-symbols}/share/fonts/truetype/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf" \
    $out/share/fonts/truetype/MaterialSymbolsRoundedFilled.ttf
''
