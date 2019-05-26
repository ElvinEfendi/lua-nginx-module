FROM ubuntu:xenial

ARG NGINX_VERSION="1.15.8"
ARG JOBS="3"
ARG LUAJIT_PREFIX="/opt/luajit21"
ARG DRIZZLE_VER="2011.07.21"
ARG LIBDRIZZLE_PREFIX="/opt/drizzle"
ARG PCRE_VER="8.41"
ARG PCRE_PREFIX="/opt/pcre"
ARG OPENSSL_VER="1.1.0j"
ARG OPENSSL_OPT=""
ARG OPENSSL_PATCH_VER="1.1.0d"

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential \
        axel \
        cpanminus \
        libtest-base-perl \
        libtext-diff-perl \
        liburi-perl \
        libwww-perl \
        libtest-longstring-perl \
        liblist-moreutils-perl \
        libgd-dev \
        git \
        wget \

    && cpanm --notest Test::Nginx IPC::Run \

    && mkdir download-cache \
    && wget -P download-cache http://openresty.org/download/drizzle7-${DRIZZLE_VER}.tar.gz \
    && wget -P download-cache http://ftp.cs.stanford.edu/pub/exim/pcre/pcre-${PCRE_VER}.tar.gz \
    && wget -P download-cache https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz \

    && git clone https://github.com/openresty/test-nginx.git \
    && git clone https://github.com/openresty/openresty.git ../openresty \
    && git clone https://github.com/openresty/no-pool-nginx.git ../no-pool-nginx \
    && git clone https://github.com/openresty/openresty-devel-utils.git \
    && git clone https://github.com/openresty/mockeagain.git \
    && git clone https://github.com/openresty/lua-cjson.git lua-cjson \
    && git clone https://github.com/openresty/lua-upstream-nginx-module.git ../lua-upstream-nginx-module \
    && git clone https://github.com/openresty/echo-nginx-module.git ../echo-nginx-module \
    && git clone https://github.com/openresty/nginx-eval-module.git ../nginx-eval-module \
    && git clone https://github.com/simpl/ngx_devel_kit.git ../ndk-nginx-module \
    && git clone https://github.com/FRiCKLE/ngx_coolkit.git ../coolkit-nginx-module \
    && git clone https://github.com/openresty/headers-more-nginx-module.git ../headers-more-nginx-module \
    && git clone https://github.com/openresty/drizzle-nginx-module.git ../drizzle-nginx-module \
    && git clone https://github.com/openresty/set-misc-nginx-module.git ../set-misc-nginx-module \
    && git clone https://github.com/openresty/memc-nginx-module.git ../memc-nginx-module \
    && git clone https://github.com/openresty/rds-json-nginx-module.git ../rds-json-nginx-module \
    && git clone https://github.com/openresty/srcache-nginx-module.git ../srcache-nginx-module \
    && git clone https://github.com/openresty/redis2-nginx-module.git ../redis2-nginx-module \
    && git clone https://github.com/openresty/lua-resty-core.git ../lua-resty-core \
    && git clone https://github.com/openresty/lua-resty-lrucache.git ../lua-resty-lrucache \
    && git clone https://github.com/openresty/lua-resty-mysql.git ../lua-resty-mysql \
    && git clone https://github.com/openresty/stream-lua-nginx-module.git ../stream-lua-nginx-module \
    && git clone -b v2.1-agentzh https://github.com/openresty/luajit2.git luajit2 \

    #&& cd luajit2/ \
    #&& make -j${JOBS} CCDEBUG=-g Q= PREFIX=${LUAJIT_PREFIX} CC=$CC XCFLAGS='-DLUA_USE_APICHECK -DLUA_USE_ASSERT -msse4.2' \
    #&& make install PREFIX=${LUAJIT_PREFIX} \
    #&& cd .. \

    && tar xzf download-cache/drizzle7-${DRIZZLE_VER}.tar.gz && cd drizzle7-${DRIZZLE_VER} \
    && ./configure --prefix=${LIBDRIZZLE_PREFIX} --without-server \
    && make libdrizzle-1.0 -j${JOBS} \

    && cd ../mockeagain/ && make CC=$CC -j${JOBS} && cd .. \

    && cd lua-cjson/ && make -j${JOBS} && sudo make install && cd .. \

    && tar zxf download-cache/pcre-${PCRE_VER}.tar.gz && cd pcre-$PCRE_VER/ \
    && ./configure --prefix=${PCRE_PREFIX} --enable-jit --enable-utf --enable-unicode-properties \
    && make -j${JOBS} \
    && PATH=$PATH make install \
    && cd .. \

    && tar zxf download-cache/openssl-$OPENSSL_VER.tar.gz && cd openssl-$OPENSSL_VER/ \
    && patch -p1 < ../../openresty/patches/openssl-$OPENSSL_PATCH_VER-sess_set_get_cb_yield.patch \
    && ./config no-threads shared enable-ssl3 enable-ssl3-method $OPENSSL_OPT -g --prefix=$OPENSSL_PREFIX -DPURIFY \
    && make -j$JOBS \
    make PATH=$PATH install_sw \
    cd .. \

ENV PATH=/work/nginx/sbin:/openresty-devel-utils:$PATH
ENV NGX_BUILD_CC=$CC

COPY . /

RUN ./util/build.sh ${NGINX_VERSION} \
    && nginx -V \
    && ldd `which nginx`|grep -E 'luajit|ssl|pcre'

ENV LD_PRELOAD=$PWD/mockeagain/mockeagain.so
ENV LD_LIBRARY_PATH=$PWD/mockeagain:$LD_LIBRARY_PATH

#prove -Itest-nginx/lib -r t
CMD ["prove", "-I", "test-nginx/lib"]
