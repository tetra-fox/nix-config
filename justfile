set shell := ["bash", "-euo", "pipefail", "-c"]

# list available recipes
default:
    @just --list

# apply formatting
fmt:
    alejandra .

# check formatting
fmt-check: sync-lockfiles
    alejandra --check .

# lint with statix
lint: sync-lockfiles
    statix check .

# rebuild this host; args pass through to rebuild.sh (e.g. `just rebuild boot`, `just rebuild --target-host mesa-svc-01`)
rebuild *args:
    bash modules/profiles/workstation/rebuild.sh {{ args }}

# regenerate topology SVGs under images/topology
update-topology:
    out=$(nix build --no-link --print-out-paths .#topology.x86_64-linux.config.output) && \
    mkdir -p images/topology && \
    install -m 644 "$out"/main.svg images/topology/main.svg && \
    install -m 644 "$out"/network.svg images/topology/network.svg && \
    echo "wrote images/topology/main.svg and images/topology/network.svg"

# ensure tools/flake.lock is fresh and in sync with root. always regenerates (it's gitignored),
# then overwrites its nixpkgs node to match the root's exact pin so CI never diverges from devenv.
sync-lockfiles:
    @root_rev=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock) && \
    root_narhash=$(jq -r '.nodes.nixpkgs.locked.narHash' flake.lock) && \
    root_lastmod=$(jq -r '.nodes.nixpkgs.locked.lastModified' flake.lock) && \
    rm -f tools/flake.lock && \
    cd tools && \
    nix flake update --quiet 2>&1 | grep -v "^@" || true && \
    jq \
      --arg rev "$root_rev" --arg nar "$root_narhash" --arg lmod "$root_lastmod" \
      '.nodes.nixpkgs.locked.rev = $rev | .nodes.nixpkgs.locked.narHash = $nar | .nodes.nixpkgs.locked.lastModified = ($lmod | tonumber)' \
      flake.lock > flake.lock.tmp && \
      mv flake.lock.tmp flake.lock && \
    echo "tools lockfile synced to root (nixpkgs=$root_rev)"
