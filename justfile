set shell := ["bash", "-euo", "pipefail", "-c"]

# list available recipes
default:
    @just --list

# apply formatting
fmt:
    alejandra .

# check formatting
fmt-check:
    alejandra --check .

# lint with statix
lint:
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
