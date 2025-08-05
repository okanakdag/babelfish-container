#!/bin/bash
set -e

PG_HOME="/home/postgres/postgres"
PG_BIN="${PG_HOME}/bin"
PG_DATA="${PG_HOME}/data"
PG_CONF="${PG_DATA}/postgresql.conf"
PG_HBA="${PG_DATA}/pg_hba.conf"
LOGFILE="${PG_DATA}/logfile"
DB_NAME="babelfish_test"

init_db () {
  echo "Initializing data directory"
  "${PG_BIN}/initdb" -D "${PG_DATA}"
}

start_db () {
  echo "Starting Postgres (background)"
  "${PG_BIN}/pg_ctl" -D "${PG_DATA}" -l "${LOGFILE}" start
}

restart_db () {
  echo "Restarting Postgres"
  "${PG_BIN}/pg_ctl" -D "${PG_DATA}" -l "${LOGFILE}" restart
}

stop_db () {
  echo "Stopping background Postgres"
  "${PG_BIN}/pg_ctl" -D "${PG_DATA}" stop
}

configure_conf () {
  echo "Patching postgresql.conf & pg_hba.conf"
  sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/g"  "${PG_CONF}"
  sed -i "s/^#shared_preload_libraries = ''/shared_preload_libraries = 'babelfishpg_tds'/g" "${PG_CONF}"
  echo "host    all    all    0.0.0.0/0    trust" >> "${PG_HBA}"
}

provision_babelfish () {
  echo "Creating Babelfish database & extensions"
  "${PG_BIN}/psql" -U postgres -d postgres -v ON_ERROR_STOP=1 <<-SQL
    DROP DATABASE IF EXISTS ${DB_NAME};
    CREATE DATABASE ${DB_NAME} OWNER postgres ENCODING 'UTF8' TEMPLATE template0;
    \\c ${DB_NAME}
    CREATE EXTENSION IF NOT EXISTS "babelfishpg_tds" CASCADE;
    GRANT ALL ON SCHEMA sys TO postgres;
    ALTER USER postgres CREATEDB;
    \\c ${DB_NAME}
    ALTER SYSTEM SET babelfishpg_tsql.database_name = '${DB_NAME}';
    ALTER DATABASE ${DB_NAME} SET babelfishpg_tsql.migration_mode = 'multi-db';
    ALTER SYSTEM SET parallel_setup_cost = 0;
    ALTER SYSTEM SET parallel_tuple_cost = 0;
    ALTER SYSTEM SET min_parallel_index_scan_size = 0;
    ALTER SYSTEM SET min_parallel_table_scan_size = 0;
    ALTER SYSTEM SET debug_parallel_query = 1;
    ALTER SYSTEM SET max_parallel_workers_per_gather = 4;
    SELECT pg_reload_conf();
    \\c ${DB_NAME}
    SHOW babelfishpg_tsql.database_name;
    CALL sys.initialize_babelfish('postgres');
SQL
}

#---- Main -------------------------------------------------------------
if [ ! -s "${PG_DATA}/PG_VERSION" ]; then
  echo "=== First boot: running initialisation ==="
  init_db
  start_db
  configure_conf
  restart_db
  provision_babelfish
  stop_db         
else
  echo "=== Cluster already initialised; skipping initdb ==="
fi

echo "Launching Postgres in foreground"
exec "${PG_BIN}/postgres" -D "${PG_DATA}"
