# tuya-local-devices

Custom [tuya-local](https://github.com/make-all/tuya-local) device
configurations, distributed as a ready-to-install Home Assistant integration —
**without maintaining a fork**.

tuya-local discovers device configs by scanning
`custom_components/tuya_local/devices/*.yaml`, so a new device needs nothing
more than a YAML file in that directory. This repo keeps _only_ your custom
device files; CI downloads a pinned upstream release, overlays your files on
top, validates the result against upstream's own schema tests, and publishes a
GitHub release you install through HACS. Upstream is never vendored into the
repo, so the tracked diff is just your devices.

This exists to bridge the gap until upstream ships first-class custom-device
support ([make-all/tuya-local#2290](https://github.com/make-all/tuya-local/issues/2290)).
Because the integration `domain` and manifest `name` are left untouched, the
published build is indistinguishable from upstream inside Home Assistant, and
you can switch back to the official integration at any time (see
[Switching back to upstream](#switching-back-to-upstream)).

## How it works

- `overlay/` mirrors the `custom_components/tuya_local/` tree. Your device
  files live in `overlay/devices/`, but anything else in the component
  (icons, translations) can be overridden the same way.
- The `compile` task fetches an upstream release into `dist/upstream/` and
  copies `overlay/` over it.
- The `test:fast` task runs upstream's `test_device_config` and
  `test_translations` suites against the merged tree — a malformed device file
  or an upstream schema change fails here before anything ships.
- The `release` task stamps the release tag as the manifest version, copies
  upstream's MIT license into the component, zips it (manifest at the archive
  root for HACS `zip_release`), and publishes a GitHub release with the zip
  attached.

Release tags are `<upstream>.<build>` — the upstream release plus the GitHub
Actions run number as a fourth component (e.g. `2026.6.4.87`). The upstream
base stays visible, and the tag sorts monotonically so HACS always offers the
newest build.

## Installing in Home Assistant

1. In HACS, add this repository as a custom repository with category
   **Integration**.
1. Install **Tuya Local (custom devices)** and restart Home Assistant.

HACS unpacks the release zip into `custom_components/tuya_local/`, exactly where
the upstream integration installs, so devices covered by upstream and your
overlay both work.

## Contributing

Adding a device is a one-file change. See [CONTRIBUTING.md](CONTRIBUTING.md) for
setup and the build/test workflow.

## Switching back to upstream

Remove this custom repository in HACS and install the official **Tuya Local**
integration. Both install into `custom_components/tuya_local/` under the same
`tuya_local` domain, so your config entries and entities carry over untouched —
only devices that depended on a file unique to `overlay/devices/` stop matching
(until upstream supports them).
