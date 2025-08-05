#!/usr/bin/env bash
set -e

# ---------- Path variables ---------------------------------------------------
PG_HOME="/home/postgres"
PG_PREFIX="${PG_HOME}/postgres"
BEXT="${PG_HOME}/babelfish_extensions/contrib"

echo "Patching Babelfish sources under $BEXT"

# ---------- Patch CMakeLists for antlr path ----------------------------------
sed -i "s|SET (MYDIR /usr/local/include/antlr4-runtime/)|SET (MYDIR ${PG_PREFIX}/include/antlr4-runtime/)|" \
    "$BEXT/babelfishpg_tsql/antlr/CMakeLists.txt"

# ---------- Patches for babelfishpg_tsql ubuntu 22.04 compile errors  --------
# pl_exec.c  — implicit 'strcasestr'
sed -i '1i#define _GNU_SOURCE\n#include <string.h>' \
    "$BEXT/babelfishpg_tsql/src/pl_exec.c"

# Remove duplicate pgtsql_base_yydebug symbol
sed -i '/^[[:space:]]*int[[:space:]]*pgtsql_base_yydebug[[:space:]]*;/d' \
    "$BEXT/babelfishpg_tsql/src/backend_parser/parser.c"
sed -i '/^[[:space:]]*extern[[:space:]]*int[[:space:]]pgtsql_base_yydebug[[:space:]]*;/d' \
    "$BEXT/babelfishpg_tsql/src/backend_parser/gramparse.h"

# Remove duplicate pltsql_curr_compile_body_lineno
sed -i '65,67d' \
    "$BEXT/babelfishpg_tsql/src/pl_comp.c"

echo "All Babelfish patches applied."