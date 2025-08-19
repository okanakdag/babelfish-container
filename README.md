# 🐟 Babelfish-for-PostgreSQL 4.3 container

```bash
# build the image (first time) and start the container
docker compose up --build -d
# after composing the container, you can open it in devcontainer 
# Press F1 → Dev Containers: Reopen in Container

# open a terminal inside the container
docker exec -it babel-container /bin/bash
# open a terminal as root user
docker exec -it --user root babel-container /bin/bash

# use sqlcmd
sqlcmd -S localhost -U postgres -P 12345678

# use psql
psql -U postgres -d babelfish_test
```