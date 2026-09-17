# Device configs

## Recovering DPs from an existing localtuya config

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

## Verifying a device config against the device

A device config is a claim about what the hardware does, and the sources it
gets written from do not settle it. Tuya's Standard Status Set lists what a
product category declares, and the console warns that it "shall be manually
created, and Tuya cannot guarantee that all hardware supports it". A config in
upstream's tree was checked against its author's unit, which may run other
firmware under another product id. Treat both as candidates.

Checking them needs a Home Assistant instance you can restart and a device you
can reach.

### Deploying a candidate device config

`mise run compile` writes the merged tree to `dist/upstream`. Copy the single
device file to `<config>/custom_components/tuya_local/devices/` on the Home
Assistant host, give it the ownership the other files there carry, and restart
Home Assistant.

Restart rather than reloading the config entry. Reloading re-registers
platforms that are already registered, which raises `ValueError: Config entry
... has already been setup!`. Afterwards the entry still reports `loaded` while
its receive loop is dead and every entity reads `unavailable`, so nothing
announces the failure.

HACS owns that directory, and updating tuya-local overwrites whatever you put
there. This iterates on a config; it does not install one.

### Reading what a Tuya device sends

`/api/diagnostics/config_entry/<entry_id>` returns `cached_state`, holding the
data points received so far, and `force_dps`, holding the ones `force: true`
adds to the poll. The UI shows neither.

Set `custom_components.tuya_local` to debug and the log carries every payload
as `<device> received {...}`, where `full_poll` separates a status query from a
pushed update. A day of those distinguishes the data points a device
volunteers, the ones it sends only on change, and the ones that never arrive.

### Mapping a data point that goes absent

A data point missing from a payload is not a data point reading false. Map the
absent case so the entity reports `unknown`:

```yaml
mapping:
  - dps_val: null
    value: null
  - dps_val: 6
    value: true
  - value: false
```

Drop the first entry and the catch-all answers for silence, so the entity
reports a state nothing observed. A food sensor reading `OK` because its device
has said nothing since booting is worse than one reading nothing at all.

Devices differ in how much they volunteer. Some return every data point on
every status query. Others return only what changed since they powered on and
recover the full set when the vendor app pairs them again, which leaves
entities at `unknown` between changes. `force: true` asks for a data point
explicitly, and a device that ignores the request costs a few seconds of every
poll cycle in exchange for nothing.

### Migrating a device from localtuya

A config that looks worse under tuya-local than under localtuya may be
reporting the same device more honestly. localtuya restores entity state across
restarts through `RestoreEntity`, and falls back to Tuya's cloud for data
points the local protocol never returns. tuya-local does neither, so a data
point that goes quiet reads `unknown` instead of holding its last value.
