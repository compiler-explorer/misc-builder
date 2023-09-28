FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt update -y -q && apt upgrade -y -q && apt update -y -q && \
    apt install -y -q \
    build-essential \
    curl \
    git

RUN mkdir -p /root
COPY nasm /root/
COPY common.sh /root/

WORKDIR /root
