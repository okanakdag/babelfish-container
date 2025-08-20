############################################################################################################
# Dockerfile for Babelfish PostgreSQL 4.3                                                                  #
# https://github.com/babelfish-for-postgresql/babelfish_extensions/blob/BABEL_4_3_STABLE/contrib/README.md #
############################################################################################################

FROM ubuntu:22.04

# ---------- Constants -------------------------------------------------------
ARG PG_TAG=BABEL_4_3_STABLE__PG_16_4
ARG BABEL_TAG=BABEL_4_3_STABLE
ARG CMAKE_VER=3.20.6

ARG PG_HOME=/home/postgres
ARG PG_PREFIX=${PG_HOME}/postgres
ARG BEXT=${PG_HOME}/babelfish_extensions/contrib

ENV BEXT=${BEXT}
ENV PG_HOME=${PG_HOME}
ENV PG_PREFIX=${PG_PREFIX}

# ---------- System user setup -----------------------------------------------
RUN groupadd -r postgres && useradd --no-log-init -m -r -g postgres postgres

# ---------- Core build dependencies -----------------------------------------
RUN apt-get update && apt-get -y install uuid-dev openjdk-8-jre \
    libicu-dev libxml2-dev openssl libssl-dev python3 python3-dev \
    libossp-uuid-dev libpq-dev pkg-config g++ build-essential bison && \
    rm -rf /var/lib/apt/lists/*

# ---------- Misc build tools -------------------------------------------------
RUN apt-get update && apt-get -y install git wget flex unzip nano curl vim less htop sudo && \
    rm -rf /var/lib/apt/lists/* && \
    echo "postgres ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ---------- sqlcmd client (optional) ----------------------------------------
WORKDIR ${PG_HOME}
RUN curl https://packages.microsoft.com/keys/microsoft.asc | tee /etc/apt/trusted.gpg.d/microsoft.asc && \
    curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | \
        tee /etc/apt/sources.list.d/mssql-release.list
RUN apt-get update && ACCEPT_EULA=Y apt-get -y install mssql-tools unixodbc-dev && \
    rm -rf /var/lib/apt/lists/*

ENV PATH=/opt/mssql-tools/bin:${PATH}
ENV PATH=${PG_PREFIX}/bin:${PATH}

# ---------- Switch to unprivileged user -------------------------------------
USER postgres

# ---------- PostgreSQL clone & build & install ------------------------------
WORKDIR ${PG_HOME}
RUN git clone -b ${PG_TAG} \
      https://github.com/babelfish-for-postgresql/postgresql_modified_for_babelfish

WORKDIR ${PG_HOME}/postgresql_modified_for_babelfish
RUN ./configure --prefix=${PG_PREFIX} --without-readline --without-zlib \
        --enable-debug --enable-cassert CFLAGS="-ggdb" --with-libxml \
        --with-uuid=ossp --with-icu && \
    make -j 4 2>error.txt && \
    make install && \
    make check

WORKDIR ${PG_HOME}/postgresql_modified_for_babelfish/contrib
RUN make && make install

# ---------- Install CMake ---------------------------------------------------
WORKDIR ${PG_HOME}
RUN wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}-linux-x86_64.sh && \
    mkdir cmake && \
    sh cmake-${CMAKE_VER}-linux-x86_64.sh --skip-license --prefix=${PG_HOME}/cmake && \
    rm cmake-${CMAKE_VER}-linux-x86_64.sh
ENV PATH=${PG_HOME}/cmake/bin:${PATH}

# ---------- Babelfish extensions clone --------------------------------------
RUN git clone -b ${BABEL_TAG} \
      https://github.com/babelfish-for-postgresql/babelfish_extensions

# ---------- ANTLR JAR copy and build ----------------------------------------
WORKDIR ${BEXT}/babelfishpg_tsql/antlr/thirdparty/antlr
RUN cp antlr-4.9.3-complete.jar ${PG_PREFIX}/lib

WORKDIR ${PG_HOME}
RUN wget http://www.antlr.org/download/antlr4-cpp-runtime-4.9.3-source.zip && \
    unzip -d antlr4 antlr4-cpp-runtime-4.9.3-source.zip && \
    rm antlr4-cpp-runtime-4.9.3-source.zip

WORKDIR ${PG_HOME}/antlr4/build
RUN cmake .. \
    -DANTLR_JAR_LOCATION=${PG_PREFIX}/lib/antlr-4.9.3-complete.jar \
    -DCMAKE_INSTALL_PREFIX=${PG_PREFIX} -DWITH_DEMO=True && \
    make && make install 

# ---------- Environment variables -------------------------------------------
ENV PG_CONFIG=${PG_PREFIX}/bin/pg_config
ENV PG_SRC=${PG_HOME}/postgresql_modified_for_babelfish
ENV cmake=${PG_HOME}/cmake/bin/cmake

# ---------- Apply patches ----------------------------------------------------
COPY patch.sh /tmp/patch.sh
USER root
RUN chmod +x /tmp/patch.sh
RUN /tmp/patch.sh
USER postgres

#---------- Install postgis --------------------------------------------------
# Installation document: https://postgis.net/docs/postgis_installation.html
# Optional packages are not installed

# Install dependencies
USER root
RUN apt-get update && apt-get install -y proj-bin libproj-dev software-properties-common \
    libjson-c-dev libxml2 libjson-c5 libjson-c-dev gdal-bin libgdal-dev && \
    add-apt-repository -y ppa:ubuntugis/ppa && \
    apt-get install -y geos-bin libgeos-dev && \
    rm -rf /var/lib/apt/lists/*

# Get and build postgis source code
WORKDIR ${PG_HOME}
RUN wget https://postgis.net/stuff/postgis-3.5.4dev.tar.gz && \
    tar -xvzf postgis-3.5.4dev.tar.gz && \
    rm postgis-3.5.4dev.tar.gz

WORKDIR  ${PG_HOME}/postgis-3.5.4dev
RUN ./configure --without-wagyu --without-protobuf \
    --with-pgconfig="${PG_CONFIG}" && make && make install
    
# ---------- Build individual extensions -------------------------------------
# There are a lot of can't find errors so I added CPPFLAGS and PG_CPPFLAGS
# DENABLE_SPATIAL_TYPES flags are for postgis support, others are for errors

WORKDIR ${BEXT}/babelfishpg_money
RUN make && make install

WORKDIR ${BEXT}/babelfishpg_common
RUN make -j 4 PG_CPPFLAGS='-I/usr/include -DENABLE_SPATIAL_TYPES' \
    CPPFLAGS="-I${PG_SRC}"  && \
    make PG_CPPFLAGS='-I/usr/include -DENABLE_SPATIAL_TYPES' install

WORKDIR ${BEXT}/babelfishpg_tds
RUN make && make install

# depends on CMakeLists.txt antlr4-runtime path update
WORKDIR ${BEXT}/babelfishpg_tsql
RUN make CPPFLAGS="-I${PG_PREFIX}/include/antlr4-runtime -I${PG_SRC}" \
    PG_CPPFLAGS='-I/usr/include -DENABLE_SPATIAL_TYPES' && \
    make install PG_CPPFLAGS='-I/usr/include -DENABLE_SPATIAL_TYPES'

WORKDIR ${BEXT}/babelfishpg_unit
RUN make PG_CONFIG="${PG_PREFIX}/bin/pg_config" && \
    #! throws warning: passing argument 1 of 'PointerGetDatum' makes pointer from integer without a cast [-Wint-conversion]
    make PG_CONFIG="${PG_PREFIX}/bin/pg_config" install

# ---------- Runtime entrypoint ----------------------------------------------
COPY init.sh /init.sh
RUN chmod +x /init.sh
USER postgres
ENTRYPOINT [ "/init.sh" ]