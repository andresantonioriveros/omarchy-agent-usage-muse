#!/bin/bash
# Sidecar writer for the Muse usage record (no-sudo deployment).
#
# The Agents panel renders whatever valid JSON lands in the usage directory,
# regardless of who wrote it — so instead of installing the collector into
# the root-owned update pipeline, a user timer runs this script, which runs
# the user-installed collector and publishes its record atomically.
#
# Supersede rule: whenever the update pipeline owns a muse collector
# (a sudo install of this repo, or a future official upstream one), this
# script stands down so two writers can never flap over muse.json.
set -euo pipefail

command -v jq >/dev/null || { echo "muse sidecar: jq is required" >&2; exit 1; }

collector="$HOME/.local/bin/omarchy-agent-usage-muse"
[[ -x $collector ]] || { echo "muse sidecar: collector not found: $collector" >&2; exit 1; }

omarchy_bin="${OMARCHY_PATH:-/usr/share/omarchy}/bin"
if [[ -x $omarchy_bin/omarchy-agent-usage-muse ]]; then
  exit 0
fi

record_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/agents/usage"
mkdir -p "$record_dir"
tmp="$(mktemp "$record_dir/.muse.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

if ! record="$("$collector" --force)" || [[ -z $record ]] || ! jq -e '.id == "muse"' >/dev/null <<<"$record"; then
  echo "muse sidecar: collector produced no valid record" >&2
  exit 1
fi
printf '%s\n' "$record" >"$tmp"
mv "$tmp" "$record_dir/muse.json"
trap - EXIT
