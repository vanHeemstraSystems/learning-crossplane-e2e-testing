# Metrics With Pixie

TODO: Intro

## Setup

> Install `px` by following the instructions at https://docs.px.dev/installing-pixie/install-schemes/cli

> Watch https://youtu.be/WiFLtcBvGMU if you are not familiar with Devbox. Alternatively, you can skip Devbox and install all the tools listed in `devbox.json` yourself.

> Please skip executing `devbox shell` if you are already inside the Shell from one of the previous episodes.

```bash
devbox shell

chmod +x manuscript/metrics/pixie.sh

./manuscript/metrics/pixie.sh
```

## Do

* Open https://work.withpixie.ai in a browser

```sh
px scripts list

px scripts run px/namespaces

px scripts run px/namespace -- --help

px scripts run px/namespace -- --namespace production

px scripts show px/namespace

px live px/namespaces

# Press `Ctrl+c` to stop it

px live px/namespace -- --namespace production

# Press `Ctrl+c` to stop it
```

## Continue the Adventure

* [Tracing](../tracing/README.md)
