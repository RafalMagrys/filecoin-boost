# Boost (PoRep Market Fork)

Fork of [filecoin-project/boost](https://github.com/filecoin-project/boost) with devnet tooling for testing [porep-market](https://github.com/fidlabs/porep-market) contracts.

## Setup

```bash
git clone git@github.com:CodeWarriorr/filecoin-boost.git
cd filecoin-boost
git submodule update --init --recursive
```

## Build

```bash
make clean docker/all
```

Takes 15-30 min first time (Go + Rust compilation). Needs Node.js 22+ and Go 1.25+.

If on Apple Silicon and you hit FFI issues: `make clean docker/all ffi_from_source=1`.

## Run devnet

```bash
make devnet/up
```

First start downloads ~2 GB proof parameters (cached at `~/.cache/filecoin-proof-parameters`).

Ready when:
```bash
docker exec lotus lotus chain head    # returns tipset
docker exec boost boost status        # boost running
# http://localhost:8080               # boost GUI
```

## Deploy PoRep Market contracts

See [scripts/porep-market/](scripts/porep-market/README.md).

## Cleanup

```bash
make devnet/down
```

## Upstream

[filecoin-project/boost](https://github.com/filecoin-project/boost) | [docs](https://boost.filecoin.io)

## License

Dual-licensed under [MIT](./LICENSE-MIT) + [Apache 2.0](./LICENSE-APACHE).
