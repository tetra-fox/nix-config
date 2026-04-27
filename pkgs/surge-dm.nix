{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule (finalAttrs: {
  pname = "surge-dm";
  version = "0.8.3";

  src = fetchFromGitHub {
    owner = "SurgeDM";
    repo = "Surge";
    tag = "v${finalAttrs.version}";
    hash = "sha256-uHCsisVe2O5hZ8W2kXmVd7IQ5QQZLKCx5EtywslSlI4=";
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
