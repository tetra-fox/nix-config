# bake FILL=1 into the icon font; Qt's variable-font renderer has artifacts on the FILL axis
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
