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

# assert the fleet discovery engine stays generic (lib/fleet-test.nix)
fleet-test:
    @out=$(nix eval --impure --raw --expr 'import ./lib/fleet-test.nix { lib = (builtins.getFlake (toString ./.)).inputs.nixpkgs.lib; }'); [ "$out" = ok ] || { echo "fleet-test: $out"; exit 1; }; echo "fleet-test: ok"

# assert every file under secrets/ is actually sops-encrypted. sops-nix's
# validateSopsFiles only hashes these files, it never checks they are encrypted, so a
# hand-written plaintext secrets file would eval, build and commit cleanly.
secrets-check:
    #!/usr/bin/env python3
    import glob, re, sys

    bad = []
    for path in sorted(glob.glob("secrets/*.yaml")):
        # everything above the sops: metadata block is payload; the block itself holds
        # plaintext bookkeeping (recipients, mac, version) and is meant to be readable
        body = open(path, encoding="utf-8").read().split("\nsops:", 1)[0]
        if "ENC[AES256_GCM" not in body:
            bad.append(path + ": no encrypted values at all")
            continue
        for n, line in enumerate(body.splitlines(), 1):
            m = re.match(r"^\s*[\w.\-]+:\s+(\S.*)$", line)
            if m and not m.group(1).startswith("ENC["):
                bad.append(path + ":" + str(n) + ": plaintext value")

    for b in bad:
        print("secrets-check: " + b, file=sys.stderr)
    if bad:
        sys.exit(1)
    print("secrets-check: ok, " + str(len(glob.glob("secrets/*.yaml"))) + " files encrypted")

# run a VM integration test from tests/ (edge-vip-failover, db-failover); needs kvm
vm-test name:
    nix build .#checks.x86_64-linux.{{name}} -L --no-link

# rebuild this host; args pass through to rebuild.sh (e.g. `just rebuild boot`, `just rebuild --target-host mesa-svc-01`)
rebuild *args:
    bash modules/cli/rebuild/_rebuild.sh {{ args }}

# regenerate topology SVGs under images/topology
update-topology:
    out=$(nix build --no-link --print-out-paths .#topology.x86_64-linux.config.output) && \
    mkdir -p images/topology && \
    install -m 644 "$out"/main.svg images/topology/main.svg && \
    install -m 644 "$out"/network.svg images/topology/network.svg && \
    echo "wrote images/topology/main.svg and images/topology/network.svg"

# lab.caddy.package pins a fixed-output hash over the xcaddy+plugins vendor dir (see
# modules/services/caddy/system.nix), which drifts whenever caddy or a plugin version bumps.
# this forces a placeholder hash, rebuilds, and reads the real one back out of the mismatch
# error instead of copy-pasting it out of a failed `just rebuild` by hand.
update-caddy-hash:
    #!/usr/bin/env bash
    set -euo pipefail
    file=modules/services/caddy/system.nix
    old=$(sed -n 's/.*hash = "\(sha256-[^"]*\)".*/\1/p' "$file")
    fake="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    trap 'sed -i "s#$fake#$old#" "$file"' EXIT
    sed -i "s#$old#$fake#" "$file"
    out=$(nix build .#nixosConfigurations.mesa-edge-01.config.lab.caddy.package --no-link 2>&1) || true
    new=$(grep -oP 'got:\s+\Ksha256-\S+' <<<"$out" | head -1)
    if [ -z "$new" ]; then
      echo "$out" >&2
      echo "update-caddy-hash: build didn't fail with the expected hash mismatch, nothing to update" >&2
      exit 1
    fi
    trap - EXIT
    sed -i "s#$fake#$new#" "$file"
    echo "update-caddy-hash: $old -> $new"
