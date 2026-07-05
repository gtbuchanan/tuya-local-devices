# Runs the merged tree's schema tests on Linux, for local use on hosts where
# Home Assistant can't be imported (Windows has no fcntl). CI runs `mise run
# test` natively on Linux and does not use this image.
#
# Build context is dist/upstream (run `mise run build` first). Only pyproject +
# manifest land in the image, so the dependency layer is cached and rebuilds
# only when the upstream release changes; the merged tree is mounted at run
# time (see the test-docker task), so a device-file edit just re-runs pytest.
FROM python:3.14

WORKDIR /deps
COPY pyproject.toml ./
COPY custom_components/tuya_local/manifest.json ./manifest.json
RUN python -m pip install --quiet --upgrade pip \
  && pip install --quiet --group dev \
  && python -c "import json; print(chr(10).join(json.load(open('manifest.json')).get('requirements', [])))" \
    | xargs -r pip install --quiet

WORKDIR /app
CMD ["python", "-m", "pytest", "tests/test_device_config.py", "tests/test_translations.py", "-q"]
