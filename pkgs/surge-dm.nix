{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule (finalAttrs: {
  pname = "surge-dm";
  version = "0.8.2";

  src = fetchFromGitHub {
    owner = "SurgeDM";
    repo = "Surge";
    tag = "v${finalAttrs.version}";
    hash = "sha256-sRKbtGcsWn36YntYyZy9TdBHhWEwy23BD6CUZ3MvesY=";
  };

  vendorHash = "sha256-aOgs3wbTqYdknT/aiV1KeBRGMREz2segvTy5I+z6jgE=";

  subPackages = ["."];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = ["--flake"];
  };

  meta = {
    description = "Blazing fast TUI download manager built in Go for power users";
    homepage = "https://github.com/SurgeDM/Surge";
    license = lib.licenses.mit;
    mainProgram = "Surge";
  };
})
