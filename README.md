# 🐟 Babelfish-for-PostgreSQL 4.3 container

A Docker-based development environment for building and testing Babelfish for PostgreSQL.

This setup is intended for development only and is not safe for production use.

## Objectives
- Reduce the time and manual effort needed to set up Babelfish for PostgreSQL from source
- Create a consistent development environment across different machines
- Help teams avoid environment-specific issues during development and testing

## Key Features
- Builds PostgreSQL and Babelfish from source in Docker
- Applies custom patches for Ubuntu 22.04 build compatibility
- Automates database setup and Babelfish configuration on startup
- Exposes PostgreSQL (`5432`) and SQL Server-compatible (`1433`) ports
- Includes `psql` and `sqlcmd` for testing inside the container
- Supports VS Code Dev Containers for easier development

## Sources
- [Babelfish for PostgreSQL extensions](https://github.com/babelfish-for-postgresql/babelfish_extensions)
- [PostgreSQL modified for Babelfish](https://github.com/babelfish-for-postgresql/postgresql_modified_for_babelfish)
- [Babelfish build instructions](https://github.com/babelfish-for-postgresql/babelfish_extensions/blob/BABEL_4_3_STABLE/contrib/README.md)

## Quickstart
1. Build the container with `docker compose up --build -d`
2. Open a terminal in the container with `docker exec -it babel-container /bin/bash` or open the devcontainer in VS Code with **F1 -> "Dev Containers: Reopen in Container"**

## Project Structure
- `Dockerfile` - builds PostgreSQL with Babelfish patches and development tools
- `init.sh` - entrypoint script that initializes the Postgres cluster, configures Babelfish, creates the default database, and launches Postgres
- `patch.sh` - applies source code patches to Babelfish for Ubuntu 22.04 compatibility and path fixes
- `docker-compose.yml` - defines the container service, ports, and environment variables
- `.devcontainer/devcontainer.json` - VS Code Dev Container configuration
- `README.md` - project documentation

## Requirements
- Docker
- (Optional) VS Code with the **Dev Containers** extension

## Usage

### VS Code Dev Container
1. Install the **Dev Containers** extension.
2. Open this repo in VS Code.
3. Build the container using `docker compose up --build -d`.
4. Press **F1 -> "Dev Containers: Reopen in Container"**.

### Ports
- **5432** -> PostgreSQL
- **1433** -> Babelfish (SQL Server compatibility)

### Paths
- The Babelfish source path is `/home/postgres/babelfish_extensions`.
- The Dev Container workspace folder is `/workspace`.

### Environment Variables
| Name                | Default                                            | Purpose                                    |
| ------------------- | -------------------------------------------------- | ------------------------------------------ |
| `PG_HOME`           | `/home/postgres`                                   | Base home for sources and installs         |
| `PG_PREFIX`         | `/home/postgres/postgres`                          | PostgreSQL install prefix                  |
| `PG_CONFIG`         | `$PG_PREFIX/bin/pg_config`                         | Tells Babelfish which PostgreSQL to target |
| `BEXT`              | `/home/postgres/babelfish_extensions/contrib`      | Extensions workspace                       |
| `PG_SRC`            | `/home/postgres/postgresql_modified_for_babelfish` | PostgreSQL source tree                     |
| `POSTGRES_USER`     | `postgres`                                         | Superuser name                             |
| `POSTGRES_PASSWORD` | `12345678`                                         | Superuser password                         |

### Commands

```bash
# ---------- FROM HOST ----------
# Build the image (first time) and start the container
# First build may take 10+ minutes
docker compose up --build -d

# Stop the container
docker compose down

# Run the container in detached mode
docker compose up -d

# Rebuild the container from scratch (no cache, full rebuild)
docker compose build --no-cache

# Rebuild the container with cache (faster, good for small Dockerfile edits)
docker compose build

# Open a terminal inside the container
docker exec -it babel-container /bin/bash

# Open a terminal as root
docker exec -it --user root babel-container /bin/bash

# ---------- IN CONTAINER ----------
# Connect to the T-SQL port with sqlcmd
sqlcmd -S localhost -U postgres -P 12345678

# Connect to the PostgreSQL port with psql
psql -h localhost -U postgres -d babelfish_test
```

## Custom PG/Babelfish Source Build

Warning: May break the build or runtime.

1. For PostgreSQL, look for the section marked `# --- PostgreSQL clone & build & install ---` and replace the source.
2. For Babelfish, look for the section marked `# --- Babelfish extensions clone ---`.
3. Rebuild the container using `docker compose build --no-cache`.
4. Run the container with `docker compose up -d`.

If the build succeeds, you can run the Babelfish unit test extension to verify it:

1. Connect to psql from the terminal:
   `psql -h localhost -U postgres -d babelfish_test`
2. Create the unit test extension:
   `CREATE EXTENSION babelfishpg_unit;`
3. Run the unit tests:
   `SELECT * FROM babelfishpg_unit.babelfishpg_unit_run_tests();`
