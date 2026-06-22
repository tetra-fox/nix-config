#!/usr/bin/env bash
# `rebuild` system binary. usage:
#   rebuild                                # local switch (default action)
#   rebuild boot                           # local boot (action as positional)
#   rebuild test                           # local test
#   rebuild dry-run                        # build + diff without activating
#   rebuild --target-host mesa-svc-01      # deploy switch to that host
#   rebuild boot --target-host mesa-svc-01 # deploy boot to that host
#   rebuild --target-host mesa-svc-01.local  # mdns/fqdn target works too
#   rebuild --target-host admin@1.2.3.4    # explicit user@ip target
#   rebuild --help                         # this message
#
# unrecognized flags pass through to nixos-rebuild, so e.g.
#   rebuild --specialisation foo
#   rebuild dry-run --show-trace
# work without the wrapper knowing about those flags.
#
# when --target-host is given:
#   - bare hostname/ip gets `admin@` prepended (servers use admin)
#   - flake attr defaults to the target's short name: the domain suffix is
#     stripped locally (mesa-svc-01.local -> mesa-svc-01), no ssh needed.
#     for a bare ip (no name to strip) the script ssh's to the target and
#     reads `hostname`, stripping any domain off that too.
#   - override the derived attr with --flake-attr; needed during initial
#     provisioning when the target's hostname isn't set yet
#   - --build-host=localhost and --elevate sudo are added automatically
#   - run WITHOUT local sudo so ssh uses your agent; see the agent preflight
#
# works as user (auto-elevates the activation step) AND via `sudo rebuild`
# for local rebuilds (resolves invoker's home via $SUDO_USER). remote deploys
# must NOT be run under sudo, see the agent preflight below.
set -e

usage() {
  # print the header comment block: the contiguous run of #-lines after the
  # shebang, with the leading "# " stripped. keyed off the comment structure
  # so it stays correct when the header is edited
  sed -n '2,/^[^#]/p' "$0" | sed -n 's/^#\( \|$\)//p'
}

if [ -n "$SUDO_USER" ]; then
  user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  user_home=$HOME
fi
flake="$user_home/Documents/git/nix-config"
if [ ! -f "$flake/flake.nix" ]; then
  echo "rebuild: no flake.nix at $flake - clone the nix-config repo there first" >&2
  exit 1
fi

# nixos-rebuild's subcommands. the first bare token that matches one is the
# action; everything else (flags and their values) passes through verbatim so
# nixos-rebuild's own arg parser handles flag arity
actions=" switch boot test build dry-build dry-run dry-activate build-vm build-vm-with-bootloader build-image list-generations repl edit "

action=""
target_host=""
flake_attr=""
passthrough=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)        usage; exit 0 ;;
    --target-host)
      [ $# -ge 2 ] || { echo "rebuild: --target-host needs a value" >&2; exit 1; }
      target_host="$2"
      # an explicit empty value would otherwise fall through to a LOCAL rebuild
      [ -n "$target_host" ] || { echo "rebuild: --target-host given an empty value" >&2; exit 1; }
      shift 2 ;;
    --target-host=*)
      target_host="${1#--target-host=}"
      # an explicit but empty value (e.g. --target-host="$UNSET_VAR") would
      # otherwise fall through to a LOCAL rebuild silently
      [ -n "$target_host" ] || { echo "rebuild: --target-host given an empty value" >&2; exit 1; }
      shift ;;
    --flake-attr)
      [ $# -ge 2 ] || { echo "rebuild: --flake-attr needs a value" >&2; exit 1; }
      flake_attr="$2"; shift 2 ;;
    --flake-attr=*)   flake_attr="${1#--flake-attr=}"; shift ;;
    -*)               passthrough+=("$1"); shift ;;
    *)
      if [ -z "$action" ] && [[ "$actions" == *" $1 "* ]]; then
        action="$1"
      else
        passthrough+=("$1")
      fi
      shift
      ;;
  esac
done

action="${action:-switch}"

if [ -n "$target_host" ]; then
  case "$target_host" in
    *@*) ;;
    *)   target_host="admin@$target_host" ;;
  esac

  # the remote deploy ssh's to the target as the invoking user, so it needs our
  # ssh agent. running under sudo (or anything that strips SSH_AUTH_SOCK) leaves
  # root with no agent and no key for admin@<target>, which would fail late with
  # a confusing permission-denied. catch it here instead
  if [ -z "$SSH_AUTH_SOCK" ] || [ ! -S "$SSH_AUTH_SOCK" ]; then
    echo "rebuild: no usable ssh agent (SSH_AUTH_SOCK unset or not a socket); are you running as root?" >&2
    echo "rebuild: run remote deploys without sudo so ssh can use your agent" >&2
    exit 1
  fi

  if [ -z "$flake_attr" ]; then
    derived="${target_host#*@}"  # drop user@
    if [[ "$derived" =~ ^[0-9]+(\.[0-9]+){3}$ || "$derived" == *:* ]]; then
      # bare ipv4/ipv6 literal, no local name to derive from. ssh and ask the
      # host its name. caller can still override with --flake-attr (needed
      # during initial provisioning before the target's hostname is set).
      # ssh's stderr flows to the terminal so the real cause (auth, host key,
      # timeout) is visible; only stdout is captured into remote_name
      remote_name=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$target_host" hostname) || {
        echo "rebuild: couldn't reach $target_host to derive flake-attr; if the host is up but unprovisioned, pass --flake-attr <name>" >&2
        exit 1
      }
      flake_attr="${remote_name%%.*}"
      if [ -z "$flake_attr" ]; then
        # remote answered but gave no usable name. refuse rather than fall
        # through to nixos-rebuild defaulting the attr to the local host
        echo "rebuild: $target_host returned no usable hostname; pass --flake-attr <name>" >&2
        exit 1
      fi
    else
      # hostname or fqdn; the short name is the flake attr. lowercase it because
      # flake attrs are lowercase but mdns/dns resolve the target
      # case-insensitively, so the typed casing is arbitrary
      short="${derived%%.*}"
      flake_attr="${short,,}"
    fi
  fi

  echo "rebuild: remote $action -> $target_host (attr $flake_attr)" >&2
  # --elevate sudo elevates the activation step on the *remote*. we run locally
  # as the user (not under sudo) so ssh uses our agent
  exec nixos-rebuild "$action" \
    --flake "$flake#$flake_attr" \
    --target-host "$target_host" \
    --build-host localhost \
    --elevate sudo \
    "${passthrough[@]}"
else
  echo "rebuild: local $action -> $(hostname)" >&2
  # local rebuild: --elevate sudo elevates only the activation step, so eval
  # and build run as us and read-only actions (build, dry-run, list-generations)
  # never prompt. running as us also lets nix reach the private nix-secrets
  # input over ssh with our own agent
  exec nixos-rebuild "$action" --flake "$flake#$(hostname)" --elevate sudo "${passthrough[@]}"
fi
