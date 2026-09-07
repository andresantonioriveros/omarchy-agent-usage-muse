# omarchy-agent-usage-muse

Muse (Meta Muse Spark) support for Omarchy 4's **Agents** bar panel
(`omarchy.agents`), following the panel's documented extension contract:
the panel is display-only and renders whatever JSON record a
`bin/omarchy-agent-usage-<agent>` collector prints — so adding an agent
means shipping a collector. No plugin or shell code is touched.

Tracks Muse Spark **1.1 / 1.2 / 1.3** (standard + `contributor` tiers),
including the opencode-proxied `muse-spark-1.3-contributor-free` model.

## What it tracks

Three local sources, no network calls:

| Source | What |
|---|---|
| Native `muse` CLI sessions (`~/.local/share/muse/sessions/**/session.jsonl`) | Per-step token usage from `model_completed` run events |
| opencode `meta`-provider sessions | Token usage |
| opencode `muse-spark-*` proxy sessions (e.g. `-free` models) | Token usage |

The record follows the stock contract (`schemaVersion`, `today*`,
`recentDays`, `modelUsage`, `activeDates`, …), so the panel lights up
tokens-by-day, tokens-by-model, and prompt/session counts with zero panel
changes.

Deliberately no cost or balance section: Meta exposes no usage/billing
API, so any credit figure would be an estimate. (Per-minute throttle
headers exist on inference endpoints, but there is no plan-window,
quota, or ledger endpoint.) This collector reports measured usage
only. The hero label is likewise left generic: the account may be
prepaid credits or a subscription, and there is no local signal to
tell them apart.

## Requirements

- Omarchy 4 (Quattro) with the Agents panel (`omarchy.agents`)
- Python 3, `jq`
- At least one of: the `muse` CLI signed in (`muse login`), or opencode
  with the `meta` provider configured

## Install

```bash
./install.sh            # user mode (default): sudo-free sidecar timer
./install.sh --system   # system mode: drive through omarchy-agent-usage-update (sudo)
./install.sh --uninstall
```

**User mode** copies the collector to `~/.local/bin` and publishes its
record through a `systemd --user` timer every 10 minutes. The panel
renders whatever valid JSON lands in the usage directory, so no system
paths are touched and nothing needs re-linking after updates. The timer
runs slightly ahead of the panel's own 15-minute refresh, so the Muse
tab is typically fresher than the stock tabs. The installer validates
the collector output first, then enables the timer and publishes the
first record immediately, failing loudly if no record appears.

Two caveats of user mode: the panel's own refresh (`r` key, opening the
panel) only reruns the stock collectors, so Muse freshness comes from
the timer alone; and the sidecar **stands down whenever the update
pipeline owns a muse collector** — a sudo install of this repo, or a
future official upstream one — so two writers can never flap over
`muse.json`. To migrate from system to user mode, uninstall the system
files first; the next timer tick picks up publishing automatically.

Manage the timer directly with
`systemctl --user status omarchy-agent-usage-muse.timer`, and force a
refresh anytime with
`systemctl --user start omarchy-agent-usage-muse.service`. The timer
only runs while you are logged in, which is also the only time the
panel exists to display its output.

**Uninstall** (`./install.sh --uninstall`) disables and removes the
timer, deletes the `~/.local/bin` copies, removes the system files via
sudo (skipped gracefully without privileges), and deletes the
`muse.json` record so the tab disappears.

**System mode** copies the collector to `/usr/bin/omarchy-agent-usage-muse`
(requires `sudo`), links it into `$OMARCHY_PATH/bin` so
`omarchy-agent-usage-update` discovers it (the stock agents are symlinks
there too — without the link the refresh exits 0 but silently writes no
record), validates its output, refreshes the usage record, and fails if no
record was written.
The panel picks up the Muse tab on its next refresh — or press `r` with
the panel open. The file is not owned by any pacman package, so it
survives `omarchy update`; the link under `/usr/share` may be reset by
system updates, in which case just re-run `./install.sh --system`.

Optional: `./install.sh --with-assets` also installs the Muse marks into
the Agents plugin assets. Stock Omarchy has no `muse.svg`, and the panel
falls back to the generic glyph without it; note these copies live under
`/usr/share` and may be reset by system updates.

## Configure

Nothing required. The Muse tab is enabled by default (unknown providers
default to on). To hide it while keeping the collector:

```bash
omarchy bar set omarchy.agents providers '{
  "claude": { "enabled": true },
  "codex": { "enabled": true },
  "fireworks": { "enabled": true },
  "muse": { "enabled": false }
}' --json
```

## Privacy

Everything is read from local files. API keys and OAuth tokens are never
read (only checked for existence, to print a helpful auth hint), and
nothing leaves the machine.

## License

MIT — see [LICENSE](LICENSE).
