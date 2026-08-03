# ron

Rails demo app for [docker-mise-cluster](https://github.com/Ruby-on-Rails-Wizardry/docker-mise-cluster).

## Host UX (like ubuntu-sample)

Uses prebuilt **`ubuntu-mise:dev`** + shared **`ubuntu-mise-cache`**.

| | |
|--|--|
| Dev image | `ubuntu-mise:dev` (`pull_policy: never`) |
| Cache | `ubuntu-mise-cache` |
| PG major | `POSTGRESQL_VERSION` in [`.mise.env`](.mise.env) (default **18**) |

### Multi-app cluster (recommended)

```bash
cd ..   # cluster root
mise install && task doctor
cd ../ubuntu-mise && task build && cd -
task setup
task up:ron
# http://localhost:8080/ron/
```

### Standalone (this directory)

```bash
mise install
# build base if needed
task setup
task shell
task compose:up   # http://localhost:3000
```

### Production image (no mise)

```bash
SECRET_KEY_BASE=$(bin/rails secret) task compose:prod -- up --build
```

## Kamal

Production deploy remains Kamal per app (`config/deploy.yml`) — not cluster compose.
