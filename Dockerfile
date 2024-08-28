# Build Stage
FROM alpine:3.20 AS build

ENV NGINX_VERSION 1.27.1

# Install build dependencies
RUN apk add --no-cache --virtual .build-deps \
        gcc \
        g++ \
        libc-dev \
        make \
        openssl-dev \
        pcre2-dev \
        zlib-dev \
        cmake \
        git \
        linux-headers \
        curl \
        perl \
        ninja \
    && apk add --no-cache \
        libmaxminddb-dev \
        wget

RUN mkdir -p /var/log/nginx \
    && mkdir -p /var/cache/nginx \
    && mkdir -p /var/run/nginx

# Fetch NGINX source code
WORKDIR /usr/src
RUN wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar -xzvf nginx-${NGINX_VERSION}.tar.gz \
    && mv nginx-${NGINX_VERSION} nginx \
    && rm nginx-${NGINX_VERSION}.tar.gz

WORKDIR /usr/src/nginx

# Fetch additional modules
RUN git clone --depth 1 --recursive https://github.com/google/ngx_brotli \
    && git clone --depth 1 --recursive https://github.com/leev/ngx_http_geoip2_module \
    && git clone --depth 1 --recursive https://github.com/openresty/headers-more-nginx-module

# Build Brotli
WORKDIR /usr/src/nginx/ngx_brotli/deps/brotli
RUN mkdir out \
    && cd out \
    && cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=installed .. \
    && cmake --build . --config Release --target brotlienc

# Download boringssl
WORKDIR /usr/src/nginx
RUN git clone --depth 1 --recursive https://github.com/google/boringssl \
    && mkdir boringssl/build \
    && cd boringssl/build \
    && cmake -GNinja -B build -DCMAKE_BUILD_TYPE=Release .. \
    && ninja -j$(nproc) -C build

# Configure and build NGINX
WORKDIR /usr/src/nginx
RUN ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --user=nginx \
    --group=nginx \
    --with-http_sub_module \
    --with-http_realip_module \
    --with-http_ssl_module \
    --with-pcre-jit \
    --with-threads \
    --with-file-aio \
    --add-module=./ngx_brotli \
    --add-module=./ngx_http_geoip2_module \
    --add-module=./headers-more-nginx-module \
    --with-cc-opt="-I../modules/boringssl/include $(CFLAGS)" \
    --with-ld-opt="-L../modules/boringssl/build/ssl -L../modules/boringssl/build/crypto $(LDFLAGS)" \
    --with-http_v3_module \
    --with-http_v2_module \
    --without-select_module \
    --without-poll_module \
    --without-http_access_module \
    --without-http_autoindex_module \
    --without-http_browser_module \
    --without-http_charset_module \
    --without-http_empty_gif_module \
    --without-http_limit_conn_module \
    --without-http_memcached_module \
    --without-http_mirror_module \
    --without-http_referer_module \
    --without-http_split_clients_module \
    --without-http_scgi_module \
    --without-http_ssi_module \
    --without-http_upstream_hash_module \
    --without-http_upstream_ip_hash_module \
    --without-http_upstream_keepalive_module \
    --without-http_upstream_least_conn_module \
    --without-http_upstream_random_module \
    --without-http_upstream_zone_module

RUN make && make install

# Cleanup
RUN apk del .build-deps \
    && rm -rf /var/cache/apk/* /usr/src/nginx

# Runtime Stage
FROM alpine:3.20

# Install runtime dependencies
RUN apk add --no-cache \
        libmaxminddb \
    && apk add --no-cache --virtual .runtime-deps \
        perl \
        pcre2

# Copy NGINX binaries and configuration from the build stage
COPY --from=build /etc/nginx /etc/nginx
COPY --from=build /usr/sbin/nginx /usr/sbin/nginx
COPY --from=build /var/cache/nginx /var/cache/nginx
COPY --from=build /var/run/nginx /var/run/nginx
COPY --from=build /var/log/nginx /var/log/nginx

# Setup NGINX user and directories
RUN addgroup -g 101 -S nginx \
    && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx

CMD ["nginx", "-g", "daemon off;"]
