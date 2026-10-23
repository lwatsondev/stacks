ARG DEBIAN_VERSION=trixie

FROM debian:${DEBIAN_VERSION}-slim

RUN apt-get update && apt-get install --no-install-recommends -y \
    oidentd \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --uid 1000 --home-dir /config --no-create-home --shell /usr/sbin/nologin znc

COPY oidentd.conf /etc/oidentd.conf

EXPOSE 113

CMD ["oidentd", "--foreground", "--nosyslog"]
