FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt update -y -q && apt upgrade -y -q && apt update -y -q && \
    apt install -y -q \
    build-essential \
    curl \
    xz-utils \
    && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root
COPY lua /root/
COPY common.sh /root/

WORKDIR /root
