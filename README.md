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
| opencode `meta`-provider sessions | Token usage + authoritative `cost` field |
| opencode `muse-spark-*` proxy sessions (e.g. `-free` models) | Token usage (`cost` 0, stats only) |

The record follows the stock contract (`schemaVersion`, `today*`,
`recentDays`, `modelUsage`, `activeDates`, `tierLabel`, `balance`, …),
so the panel lights up tokens-by-day, tokens-by-model, and the prepaid
**balance gauge** with zero panel changes.

Costs prefer opencode's priced `cost` field; native sessions fall back to
per-model rates read live from the CLI's own provider catalog
(`~/.local/share/muse/model-catalog/`), with the public rate card as
backup. The balance estimates the $20 free-credit ledger minus rated
contributor spend since `fundedAt`, and is labeled `estimated` in the UI.

Meta exposes **no** usage/limits API and no rate-limit response headers
(verified against the public API reference, the CLI binary, and a live
`GET /v1/models`), so reactive balance estimation is the best available
signal — same situation as OpenAI/Anthropic balance tracking.

## Requirements

- Omarchy 4 (Quattro) with the Agents panel (`omarchy.agents`)
- Python 3, `jq`
- At least one of: the `muse` CLI signed in (`muse login`), or opencode
  with the `meta` provider configured

## Install

```bash
./install.sh
omarchy agent usage update muse --force
```

The installer copies the collector to `/usr/bin/omarchy-agent-usage-muse`
(requires `sudo`), validates its output, and refreshes the usage record.
The panel picks up the Muse tab on its next refresh — or press `r` with
the panel open. The file is not owned by any pacman package, so it
survives `omarchy update`.

Optional: `./install.sh --with-assets` also installs the Muse marks into
the Agents plugin assets. Stock Omarchy has no `muse.svg`, and the panel
falls back to the generic glyph without it; note these copies live under
`/usr/share` and may be reset by system updates.

## Configure

Optional funding ledger, `~/.config/omarchy/agents/muse.json`:

```json
{
  "tier": "Prepaid",
  "fundedAmount": 20,
  "fundedAt": "2026-07-01",
  "currency": "USD"
}
```

Or copy the template: `cp muse.json.example ~/.config/omarchy/agents/muse.json`.
Without it, token stats still show — just no balance gauge.

The Muse tab is enabled by default (unknown providers default to on).
To hide it while keeping the collector:

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
