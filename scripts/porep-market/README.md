# PoRep Market Devnet Scripts

Setup and deploy [porep-market](https://github.com/fidlabs/porep-market) contracts on boost devnet.

## Prerequisites

- Foundry (`forge`, `cast`)
- Running devnet (`make devnet/up` from repo root)
- `jq`, `xxd`

## Usage

```bash
bash 00_setup.sh                         # clone repos, build contracts
bash 01_extract_key.sh                   # extract deployer key from devnet wallet
bash 02_deploy.sh                        # deploy contracts to FEVM
bash 03_deploy_allocator_and_grant_dc.sh # deploy MetaAllocator, grant datacap to Client
bash 04_register_miner.sh               # register test miners in SPRegistry
bash 05_deploy_token.sh                 # deploy MockUSDC, mint to deployer
bash 06_setup_sli.sh                    # configure SLI oracle
```

Or run all steps at once: `just deploy`

Config in `.env` (auto-created from `env.example`).

## Troubleshooting

```bash
# check devnet
docker exec lotus lotus chain head

# check deploy logs
cat deploy_output.log

# check RPC
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://127.0.0.1:1234/rpc/v1
```
