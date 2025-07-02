FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt update -y -q && apt upgrade -y -q && apt update -y -q && \
    apt install -y -q \
    nix

RUN mkdir -p /root
COPY nix /root/
COPY common.sh /root/

WORKDIR /root
