FROM nginx AS build

ENV TZ=Europe/Berlin

WORKDIR /src

RUN apt-get update && \
    apt-get install -y git gcc make g++ cmake perl libunwind-dev golang && \
    git clone https://boringssl.googlesource.com/boringssl && \
    mkdir boringssl/build && \
    cd boringssl/build && \
    cmake .. && \
    make

RUN apt-get install -y mercurial libperl-dev libpcre3-dev zlib1g-dev libxslt1-dev libgd-ocaml-dev libgeoip-dev && \
    hg clone https://hg.nginx.org/nginx-quic && \
    hg clone http://hg.nginx.org/njs && \
    git clone --recursive https://github.com/google/ngx_brotli.git && \
    cd nginx-quic && \
    hg update quic && \
    auto/configure `nginx -V 2>&1 | sed "s/ \-\-/ \\\ \n\t--/g" | grep "\-\-" | grep -ve opt= -e param= -e build=` \
                   --build=nginx-quic --with-debug --add-module=../njs/nginx \
                   --with-http_v3_module --with-http_quic_module --with-stream_quic_module \
                   --with-cc-opt="-I/src/boringssl/include" --add-module=/src/ngx_brotli --with-ld-opt="-L/src/boringssl/build/ssl -L/src/boringssl/build/crypto" && \
    make

FROM nginx
COPY --from=build /src/nginx-quic/objs/nginx /usr/sbin

#RUN groupadd -g 1000 nginx \
 # && useradd -m -u 1000 -d /var/cache/nginx -s /sbin/nologin -g nginx nginx \
  # forward request and error logs to docker log collector
RUN mkdir -p /var/log/nginx \
  && touch /var/log/nginx/access.log /var/log/nginx/error.log \
  && chown nginx: /var/log/nginx/access.log /var/log/nginx/error.log \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log


EXPOSE 80 443

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
