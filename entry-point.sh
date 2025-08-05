#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
# INIT_SCRIPT="/home/postgres/taurus/postgresql_modified_for_babelfish/src/babelfish_extensions/test/JDBC/init.sh"
init_user()
{
echo "============================== CREATING USER AND DATABASE =============================="
psql -U "$USER" -d postgres -a << EOF
CREATE USER jdbc_user WITH SUPERUSER CREATEDB CREATEROLE PASSWORD '12345678' INHERIT;
DROP DATABASE IF EXISTS jdbc_testdb;
CREATE DATABASE jdbc_testdb OWNER jdbc_user;
\c jdbc_testdb
CREATE EXTENSION IF NOT EXISTS "babelfishpg_tds" CASCADE;
GRANT ALL ON SCHEMA sys to jdbc_user;
ALTER USER jdbc_user CREATEDB;
\c jdbc_testdb
ALTER SYSTEM SET babelfishpg_tsql.database_name = 'jdbc_testdb';
ALTER DATABASE jdbc_testdb SET babelfishpg_tsql.migration_mode = 'multi-db';
ALTER SYSTEM SET parallel_setup_cost = 0;
ALTER SYSTEM SET parallel_tuple_cost = 0;
ALTER SYSTEM SET min_parallel_index_scan_size = 0;
ALTER SYSTEM SET min_parallel_table_scan_size = 0;
ALTER SYSTEM SET debug_parallel_query = 1;
ALTER SYSTEM SET max_parallel_workers_per_gather = 4;
SELECT pg_reload_conf();
\c jdbc_testdb
show babelfishpg_tsql.database_name;
CALL sys.initialize_babelfish('jdbc_user');
EOF
echo "============================= BUILDING JDBC TEST FRAMEWORK ============================="
}

init_db() {
    echo "Initializing PostgreSQL data directory at $PG_DATA..."
    initdb -D "$PG_DATA"
}

configure_postgres() {
    echo "Configuring postgresql.conf..."
    echo "listen_addresses = '*'" >> "$PG_DATA/postgresql.conf"
    echo "shared_preload_libraries = 'babelfishpg_tds'" >> "$PG_DATA/postgresql.conf"
}

configure_pg_hba() {
    echo "Configuring pg_hba.conf..."
    echo 'host    all             all             0.0.0.0/32              scram-sha-256' >> $PG_DATA/pg_hba.conf
    echo 'host    all             all             192.108.60.158/32       trust'  >> $PG_DATA/pg_hba.conf
    
}

symlink_epilogue() {
    echo "Creating epilogue symlink..."
    rm -f /home/postgres/taurus/postgresql_modified_for_babelfish/src/babelfish_extensions/contrib/babelfishpg_tsql/gram-tsql-epilogue.y.c
    ln -s /home/postgres/taurus/postgresql_modified_for_babelfish/src/babelfish_extensions/contrib/babelfishpg_tsql/src/backend_parser/gram-tsql-epilogue.y.c /home/postgres/taurus/postgresql_modified_for_babelfish/src/babelfish_extensions/contrib/babelfishpg_tsql/gram-tsql-epilogue.y.c
    
    rm -f /home/postgres/taurus/postgresql_modified_for_babelfish/src/babelfish_extensions/contrib/babelfishpg_tsql/gram.y
    ln -s /home/postgres/taurus/postgresql_modified_for_babelfish/src/postgresql/src/backend/parser/gram.y /home/postgres/taurus/postgresql_modified_for_babelfish/src/babelfish_extensions/contrib/babelfishpg_tsql/gram.y
}

main() {
    init_db
    pg_ctl -D "$PG_DATA" -l "$PG_LOGFILE" start
    configure_postgres
    configure_pg_hba
    pg_ctl -D "$PG_DATA" -l "$PG_LOGFILE" restart
    init_user
    symlink_epilogue
    echo "✅ All steps completed successfully."
}

main