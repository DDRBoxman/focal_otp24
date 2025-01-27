FROM ubuntu:focal as base

ADD ./apt.conf /etc/apt/apt.conf

RUN apt-get update && \
    apt-get install sudo bash vim curl && \
    apt-get clean && \
    rm -fr /var/cache/apt/archives/* && \
    rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/bin/bash"]


FROM base as builder

## Build Erlang from Source
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC \
    apt-get install -y --no-install-recommends make gcc ncurses-dev sed libssl-dev curl g++ xsltproc lbzip2 pkg-config unzip

RUN curl -L https://github.com/erlang/otp/releases/download/OTP-24.3.4.17/otp_src_24.3.4.17.tar.gz > otp.tar.gz

RUN tar -xf otp.tar.gz

WORKDIR /otp_src_24.3.4.17

ENV ERL_TOP /otp_src_24.3.4.17
ENV PATH "/usr/local/bin:$PATH"

RUN cd $ERL_TOP && ./configure && make -j$(nproc) && mkdir /tmp/erlang-build && make DESTDIR=/tmp/erlang-build install

## Download Elixir
RUN curl -L https://github.com/elixir-lang/elixir/releases/download/v1.12.3/Precompiled.zip > elixir-otp-24.zip
RUN unzip -d /opt/elixir elixir-otp-24.zip

FROM base

# Copy Erlang from the builder
COPY --from=builder /tmp/erlang-build/ /
COPY --from=builder /opt/elixir /opt/elixir/

ENV PATH "/opt/elixir/bin:${PATH}"

RUN apt-get update && \
    apt-get install make git libtool autoconf libexpat1-dev gcc && \
    # install hex and rebar
    mix local.hex --force && \
    mix local.rebar --force && \
    apt-get clean && \
    apt-get purge make libtool autoconf libexpat1-dev gcc && \
    apt-get autoremove && \
    rm -fr /var/cache/apt/archives/*

ENTRYPOINT ["/usr/local/bin/iex"]
