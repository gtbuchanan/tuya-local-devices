# Contributing to tuya-local-devices

## Setup

[mise] pins the dev tools and runs the tasks. With mise installed:

```sh
mise trust
mise install     # install pinned tools; wires up hk's Git hooks
mise run prepare # install pnpm deps (eslint needs them; also the worktrunk bootstrap)
```

## Tasks

Leaf tasks live under `mise-tasks/`; the aggregates and generated `hk:*` tasks
round them out. mise caches `compile`/`test:deps` on their inputs, so re-running
skips work that hasn't changed.

- `mise run compile` — download the upstream release (cached per version) into
  `dist/upstream/` and overlay `overlay/` on top. Pin a release with
  `UPSTREAM_VERSION=2026.6.4 mise run compile`.
- `mise run test:fast` — run upstream's `test_device_config` and
  `test_translations` suites against the merged tree. Home Assistant imports
  `fcntl`, so on Windows this runs in a Linux container automatically; Linux and
  macOS run natively.
- `mise run test` — all test tiers (currently just `test:fast`).
- `mise run build:ci` — compile + fast tests (the CI gate); `mise run build`
  adds the slower tiers once they exist.
- `mise run test:deps` — install upstream's python test harness. Run by
  `prepare` and by CI; run it once before `test:fast` if you skipped `prepare`.
- `mise run release` — package + publish a GitHub release (CI-only; needs
  `GH_TOKEN` and `BUILD_NUMBER`).
- `mise run hk:all` — run the hk hooks over all files; `mise run hk:base [ref]`
  over files changed from a base ref.

## Adding a device

1. Drop the device YAML into `overlay/devices/` — same format as upstream's
   `custom_components/tuya_local/devices/*.yaml`. `overlay/` mirrors the
   component tree, so translations or icons can be overridden the same way.
1. Run `mise run build:ci` to compile the merged tree and run the tests locally.
1. Open a PR. `pr.yml` runs the same checks, plus the hk hooks.
1. Merge. `release.yml` publishes a new build on the current latest upstream.

### Recovering DPs from an existing localtuya config

If the device already runs under the localtuya integration, its stored config
holds the DP → entity mapping — the hard part of writing a device file. Extract
just the entities and DP dump (no secrets) from Home Assistant's config storage:

```sh
jq '.data.entries[]
    | select(.domain=="localtuya")
    | .data.devices
    | map_values({
        friendly_name: (.entities[0].friendly_name // .friendly_name),
        dps_strings,
        entities: [.entities[] | del(.local_key, .device_id)]
      })' \
  config/.storage/core.config_entries
```

Descending only into `.data.devices` excludes the account-level `client_id` and
`client_secret`, and `del(.local_key, .device_id)` strips the per-device
secrets, so the output is safe to share. Note that `dps_strings` can include
cloud-backfilled data points that aren't emitted over the local protocol —
verify against a live debug log before relying on one.

## CI/CD

- `pr.yml` — pull-request checks: reusable `ci.yml` (compile + test) plus the
  shared hk pre-commit hooks.
- `release.yml` — the single publish pipeline. Runs on push to `main` (rebuild
  on the latest upstream with the overlay change), on a daily schedule (rebuild
  when upstream cuts a release not yet published), and on manual dispatch. It
  re-runs CI as a gate, then calls `cd.yml` to publish.
- `ci.yml` / `cd.yml` — reusable build/test and publish workflows.

Publishing runs in the `release` GitHub Environment. Add required reviewers
under **Settings → Environments → release** for a manual approval gate, or leave
it unprotected for hands-off publishing.

[mise]: https://mise.jdx.dev
