{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule (finalAttrs: {
  pname = "surge-dm";
  version = "0.8.1";

  src = fetchFromGitHub {
    owner = "SurgeDM";
    repo = "Surge";
    tag = "v${finalAttrs.version}";
    hash = "sha256-oCphQweIkzt9XY29CyK8/XTaedwsMW/yaC+KybZ8iqg=";
  };

  vendorHash = "sha256-0Lv8zZ6Bdlm3+hLyzsrfbapnf4SToxjsJSonXDx18iM=";

  subPackages = ["."];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  meta = {
    description = "Blazing fast TUI download manager with parallel connections";
    homepage = "https://github.com/SurgeDM/Surge";
    license = lib.licenses.mit;
    mainProgram = "Surge";
  };
})
