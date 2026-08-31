# Kestrel

A tiny task runner for people who only ever needed four commands.

[![build](https://img.shields.io/badge/build-passing-brightgreen.svg)](https://example.com)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://example.com)

Kestrel reads a `kestrel.toml` from the current directory, works out which tasks changed,
and runs only those. It is a sample project invented for documentation and parser tests —
there is nothing to install.

## Install

```bash
npm install --global kestrel
```

Or run it once, without installing:

```bash
npx kestrel run build
```

## Usage

```toml
# kestrel.toml
[task.build]
inputs = ["src/**/*.ts"]
outputs = ["dist"]
run = "tsc --project tsconfig.json"

[task.test]
needs = ["build"]
run = "node --test"
```

```bash
kestrel run test
```

| Command          | What it does                                        |
| ---------------- | --------------------------------------------------- |
| `kestrel run`    | Runs a task and everything it depends on             |
| `kestrel graph`  | Prints the dependency graph as a tree                |
| `kestrel clean`  | Removes every declared `outputs` path                |
| `kestrel watch`  | Re-runs a task whenever one of its inputs changes    |

## Configuration

| Key       | Type       | Default | Description                                  |
| --------- | ---------- | ------- | -------------------------------------------- |
| `inputs`  | `string[]` | `[]`    | Globs whose contents decide the cache key    |
| `outputs` | `string[]` | `[]`    | Paths written by the task                    |
| `needs`   | `string[]` | `[]`    | Tasks that must succeed first                |
| `run`     | `string`   | —       | The shell command to execute                 |

## Caching

A task is skipped when the hash of its `inputs` matches the hash recorded in
`.kestrel/cache.json`. Delete that file to force a full rebuild.

> **Note**
> The cache is keyed by content, not by timestamp, so touching a file does not invalidate
> anything.

## Contributing

Pull requests are welcome. Open an issue first if the change is larger than a bug fix.

## License

MIT
