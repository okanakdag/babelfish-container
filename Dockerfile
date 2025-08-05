# Dockerfile for Babelfish PostgreSQL 4.3
# https://github.com/babelfish-for-postgresql/babelfish_extensions/blob/BABEL_4_3_STABLE/contrib/README.md
FROM ubuntu:jammy
 
# Create postgres user and group
RUN groupadd -r postgres && useradd --no-log-init -m -r -g postgres postgres

# Install Postgres dependencies
# Installation documentation specifies python2, but it is deprecated
RUN apt-get update && apt-get -y install uuid-dev openjdk-8-jre \
    libicu-dev libxml2-dev openssl libssl-dev python3 python3-dev \
    libossp-uuid-dev libpq-dev pkg-config g++ build-essential bison

# Install other dependencies and tools
RUN apt-get -y install git wget flex unzip nano curl sudo

# add postgres user to sudo group !!remove
RUN usermod -aG sudo postgres

# Switch user
USER postgres

# Clone PostgreSQL for Babelfish 16.4
WORKDIR /home/postgres
RUN git clone -b BABEL_4_3_STABLE__PG_16_4 https://github.com/babelfish-for-postgresql/postgresql_modified_for_babelfish

# Install and build PostgreSQL
WORKDIR /home/postgres/postgresql_modified_for_babelfish

RUN ./configure --prefix=$HOME/postgres/ --without-readline --without-zlib --enable-debug --enable-cassert CFLAGS="-ggdb" --with-libxml --with-uuid=ossp --with-icu &&\
    make -j 4 2>error.txt &&\
    make install &&\
    make check
WORKDIR /home/postgres/postgresql_modified_for_babelfish/contrib
RUN make && make install

# Install & build dependencies
# Install CMake at /home/postgres/cmake
WORKDIR /home/postgres
RUN wget https://github.com/Kitware/CMake/releases/download/v3.20.6/cmake-3.20.6-linux-x86_64.sh &&\
    mkdir cmake &&\
    sh cmake-3.20.6-linux-x86_64.sh --skip-license --prefix=/home/postgres/cmake &&\
    rm cmake-3.20.6-linux-x86_64.sh
ENV PATH=/home/postgres/cmake/bin:$PATH

# Clone Babelfish extensions
RUN git clone -b BABEL_4_3_STABLE https://github.com/babelfish-for-postgresql/babelfish_extensions

# Move antlr jar to local lib
WORKDIR /home/postgres/babelfish_extensions/contrib/babelfishpg_tsql/antlr/thirdparty/antlr
RUN cp antlr-4.9.3-complete.jar /home/postgres/postgres/lib

# Download and compile antlr with cmake
WORKDIR /home/postgres
RUN wget http://www.antlr.org/download/antlr4-cpp-runtime-4.9.3-source.zip &&\
    unzip -d antlr4 antlr4-cpp-runtime-4.9.3-source.zip &&\
    rm antlr4-cpp-runtime-4.9.3-source.zip

WORKDIR /home/postgres/antlr4/build
RUN cmake .. \
    -DANTLR_JAR_LOCATION=/home/postgres/postgres/lib/antlr-4.9.3-complete.jar \
    -DCMAKE_INSTALL_PREFIX=/home/postgres/postgres -DWITH_DEMO=True &&\
    make && make install 

# Set environment variables
ENV PG_CONFIG=/home/postgres/postgres/bin/pg_config
ENV PG_SRC=/home/postgres/postgresql_modified_for_babelfish
ENV cmake=/home/postgres/cmake/bin/cmake

#Update the file contrib/babelfishpg_tsql/antlr/CMakeLists.txt with the correct antlr4-runtime path
RUN sed -i 's|SET (MYDIR /usr/local/include/antlr4-runtime/)|\
    SET (MYDIR /home/postgres/postgres/include/antlr4-runtime/)|' \
    /home/postgres/babelfish_extensions/contrib/babelfishpg_tsql/antlr/CMakeLists.txt

#Build the extensions
WORKDIR /home/postgres/babelfish_extensions/contrib/babelfishpg_money
RUN make && make install

WORKDIR /home/postgres/babelfish_extensions/contrib/babelfishpg_common
RUN make && make install

WORKDIR /home/postgres/babelfish_extensions/contrib/babelfishpg_tds
RUN make && make install

# depends on CMakeLists.txt antlr4-runtime path update
WORKDIR /home/postgres/babelfish_extensions/contrib/babelfishpg_tsql

# Fixes for babelfishpg_tsql compile errors, check issues
    # implicit declaration of function 'strcasestr'
RUN sed -i '1i#define _GNU_SOURCE\n#include <string.h>' \
    /home/postgres/babelfish_extensions/contrib/babelfishpg_tsql/src/pl_exec.c &&\
    sed -i '/^[[:space:]]*int[[:space:]]*pgtsql_base_yydebug[[:space:]]*;/d' \
    /home/postgres/babelfish_extensions/contrib/babelfishpg_tsql/src/backend_parser/parser.c &&\
    # fix for multiple definition of 'pgtsql_base_yydebug'
    sed -i '/^[[:space:]]*extern[[:space:]]*int[[:space:]]pgtsql_base_yydebug[[:space:]]*;/d' \
    /home/postgres/babelfish_extensions/contrib/babelfishpg_tsql/src/backend_parser/gramparse.h &&\
    #fix for multiple definition of 'pltsql_curr_compile_body_lineno'
    sed -i '65,67d' /home/postgres/babelfish_extensions/contrib/babelfishpg_tsql/src/pl_comp.c 

# antlr4 path update worked for some files but few files such as src/tsqlUnsupportedFeatureHandler.cpp
#   cant find the antlr4-runtime path so I added CPPFLAGS. Some paths might be hardcoded? 
RUN make CPPFLAGS="-I/home/postgres/postgres/include/antlr4-runtime" && make install


WORKDIR /home/postgres/babelfish_extensions/contrib/babelfishpg_unit
# Added PG_CONFIG path because of hardcoded path
RUN make PG_CONFIG=/home/postgres/postgres/bin/pg_config &&\
    #! throws warning: passing argument 1 of 'PointerGetDatum' makes pointer from integer without a cast [-Wint-conversion]
    make PG_CONFIG=/home/postgres/postgres/bin/pg_config install

# fix place, add comments
USER root
RUN apt-get update && apt-get install -y passwd
RUN echo "postgres:postgres" | chpasswd
RUN echo "root:root" | chpasswd

# Install sqlcmd
WORKDIR /home/postgres 
RUN curl https://packages.microsoft.com/keys/microsoft.asc | tee /etc/apt/trusted.gpg.d/microsoft.asc &&\
    curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
RUN apt-get update && ACCEPT_EULA=Y apt-get -y install mssql-tools18 unixodbc-dev

ENV PATH=/opt/mssql-tools18/bin:${PATH}
ENV PATH=~/postgres/bin:$PATH

# initdb - carry to a separate script
USER postgres
RUN /home/postgres/postgres/bin/initdb -D /home/postgres/postgres/data &&\
    /home/postgres/postgres/bin/pg_ctl -D /home/postgres/postgres/data -l logfile start

# Update postgresql.conf to allow external connections
RUN sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/g" /home/postgres/postgres/data/postgresql.conf &&\
    sed -i "s/^#shared_preload_libraries = ''/shared_preload_libraries = 'babelfishpg_tds'/g" /home/postgres/postgres/data/postgresql.conf &&\
    # Allow all for development environment
    sed -i '$a host    all    all    0.0.0.0/0    trust' /home/postgres/postgres/data/pg_hba.conf &&\
    # Restart to apply changes
    ~/postgres/bin/pg_ctl -D ~/postgres/data/ -l logfile restart

# Skipped SSL


