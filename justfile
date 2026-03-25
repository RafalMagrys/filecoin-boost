scripts := "scripts/porep-market"

# build docker images and start devnet
up:
    make clean docker/all
    make devnet/up

# start devnet (images already built)
start:
    make devnet/up

stop:
    make devnet/down

# deploy porep-market contracts to running devnet
deploy:
    bash {{scripts}}/00_setup.sh
    bash {{scripts}}/01_extract_key.sh
    bash {{scripts}}/02_deploy.sh
    bash {{scripts}}/03_deploy_allocator_and_grant_dc.sh
    bash {{scripts}}/04_register_miner.sh
    bash {{scripts}}/05_deploy_token.sh
    bash {{scripts}}/06_setup_sli.sh

# check devnet status
status:
    @docker exec lotus lotus chain head && echo "devnet: ok" || echo "devnet: down"
    @docker exec boost boost status 2>/dev/null | head -5 || true

logs:
    docker compose -f docker/devnet/docker-compose.yaml logs -f
