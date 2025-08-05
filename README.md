# 🐟 Babelfish-for-PostgreSQL 4.3 container

```bash
#build the image (first time) and start the container
docker compose up --build -d

# open a terminal inside the container
docker exec -it babel-container /bin/bash

# use sqlcmd
sqlcmd -S localhost -U postgres -P 12345678
```