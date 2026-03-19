# 🐟 Babelfish-for-PostgreSQL 4.3 container

A Docker-based development environment for building and testing Babelfish for PostgreSQL with PostGIS support.

This setup is intended for development only and is not safe for production use.

## Objectives
- Reduce the time and manual effort needed to set up Babelfish for PostgreSQL from source
- Create a consistent development environment across different machines
- Help teams avoid environment-specific issues during development and testing

## Key Features
- Builds PostgreSQL and Babelfish from source in Docker
- Adds PostGIS support for spatial database features
- Applies custom patches for Ubuntu 22.04 build compatibility
- Automates database setup and Babelfish configuration on startup
- Exposes PostgreSQL (`5432`) and SQL Server-compatible (`1433`) ports
- Includes `psql` and `sqlcmd` for testing inside the container
- Supports VS Code Dev Containers for easier development

## Sources
- [Babelfish for PostgreSQL extensions](https://github.com/babelfish-for-postgresql/babelfish_extensions)
- [PostgreSQL modified for Babelfish](https://github.com/babelfish-for-postgresql/postgresql_modified_for_babelfish)
- [Babelfish build instructions](https://github.com/babelfish-for-postgresql/babelfish_extensions/blob/BABEL_4_3_STABLE/contrib/README.md)
- [PostGIS installation documentation](https://postgis.net/docs/postgis_installation.html)

## Quickstart
1. Build the container with `docker compose up --build -d`
2. Open a terminal in the container with `docker exec -it babelfish-container /bin/bash` or open devcontainer in vs code **F1 → “Dev Containers: Reopen in Container”**

## 📂 Project Structure
- `Dockerfile` – builds PostgreSQL with Babelfish patches, PostGIS, and dev tools
- `init.sh` – Entrypoint script that initializes the Postgres cluster, configures Babelfish, creates the default database, and launches Postgres.
- `patch.sh` – Applies source code patches to Babelfish (fixing Ubuntu 22.04 build issues and adjusting paths).  
- `docker-compose.yml` – defines the container service, ports, and volume mounts
- `.devcontainer/devcontainer.json` – VS Code Dev Container configuration
- `README.md` – this documentation

## Requirements
- Docker
- (Optional) VS Code with **Dev Containers** extension

## Usage

### VS Code Dev Container
1. Install the **Dev Containers** extension.
2. Open this repo in VS Code.
3. Build the container using ```docker compose up --build -d```
4. Press **F1 → “Dev Containers: Reopen in Container”**.

### Ports
- **5432** → PostgreSQL  
- **1433** → Babelfish (SQL Server compatibility)

### Paths
- Default user is system user `postgres` (with passwordless `sudo`).
- Home folder for the user group: /home/postgres
- Home folder of the `postgres` user: /home/postgres/postgres
- Babelfish source path: `/home/postgres/babelfish_extensions`.

### Enviroment variables
| Name                | Default                                            | Purpose                                    |
| ------------------- | -------------------------------------------------- | ------------------------------------------ |
| `PG_HOME`           | `/home/postgres`                                   | Base home for sources & installs           |
| `PG_PREFIX`         | `/home/postgres/postgres`                          | PostgreSQL install prefix (bin/lib/share)  |
| `PG_CONFIG`         | `$PG_PREFIX/bin/pg_config`                         | Tells PostGIS/Babelfish which PG to target |
| `BEXT`              | `/home/postgres/babelfish_extensions/contrib`      | Extensions workspace                       |
| `PG_SRC`            | `/home/postgres/postgresql_modified_for_babelfish` | PostgreSQL source tree                     |
| `PGDATA`            | `$PG_PREFIX/data`                                  | Database cluster initialized here          |
| `POSTGRES_USER`     | `postgres`                                         | Superuser name                             |
| `POSTGRES_PASSWORD` | `12345678`                                         | Superuser password                         |


### Commands

```bash
#----------FROM HOST---------------------------------------------------
# build the image (first time) and start the container
# first build may take 10+ minutes
docker compose up --build -d

# Stop the container
docker compose down
# Run the container in detached mode
docker compose up -d

# Rebuild the container from scratch (no cache, full rebuild)
docker compose build --no-cache
# Rebuild the container with cache (faster, good for small scrpt or Dockerfile edits)
docker compose build

# Open a terminal inside the container 
docker exec -it babelfish-container /bin/bash

# Open a terminal as root
docker exec -it --user root babelfish-container /bin/bash

#----------IN CONTAINER--------------------------------------------------
# Connect to T-SQL port  with sqlcmd 
sqlcmd -S localhost -U postgres -P 12345678

# Connect to posgresql port with psql
psql -h localhost -U postgres -d babelfish_test
```

## Custom PG/Babelfish Source Build

⚠️ May break the build or runtime.

1. For postgresql look for the section marked **# --- PostgreSQL clone & build & install ---** and replace the source.
2. And for babelfish look for the section  **# --- Babelfish extensions clone ---**.
3. Rebuild the container using ```docker compose build --no-cache```
4. Run the container ```docker compose up -d```

If the build succeeds, you can run babelfish unit test extension to verify build
1. Connect to psql from terminal
    ```psql -h localhost -U postgres -d babelfish_test```
2. Create unit test extension
    ```CREATE EXTENSION babelfishpg_unit;```
3. Run unit tests
    ```SELECT * FROM babelfishpg_unit.babelfishpg_unit_run_tests();```

You can also verify postgis by,
1. Connect to psql from terminal
    ```psql -h localhost -U postgres -d babelfish_test```
2. Enable postgis
    ```CREATE EXTENSION postgis;```
3. Check version
    ```SELECT PostGIS_Full_Version();```