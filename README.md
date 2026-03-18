# Boost (PoRep Market Fork)

Fork of [filecoin-project/boost](https://github.com/filecoin-project/boost) with devnet tooling for testing [porep-market](https://github.com/fidlabs/porep-market) contracts.

## Setup

```bash
git clone git@github.com:CodeWarriorr/filecoin-boost.git
cd filecoin-boost
git submodule update --init --recursive
```

## Quick start (with [just](https://github.com/casey/just))

```bash
just up       # build images + start devnet (first time, ~30 min)
just deploy   # deploy porep-market contracts + grant datacap + register miners
just status   # check devnet health
just stop     # tear down
```

Needs Node.js 22+, Go 1.25+, Foundry. First start downloads ~2 GB proof parameters.

If on Apple Silicon and you hit FFI issues: `make clean docker/all ffi_from_source=1`.

## Manual steps

```bash
make clean docker/all   # build
make devnet/up          # start
make devnet/down        # stop
```

See [scripts/porep-market/](scripts/porep-market/README.md) for individual deploy scripts.

## Upstream

[filecoin-project/boost](https://github.com/filecoin-project/boost) | [docs](https://boost.filecoin.io)

## License

Dual-licensed under [MIT](./LICENSE-MIT) + [Apache 2.0](./LICENSE-APACHE).
