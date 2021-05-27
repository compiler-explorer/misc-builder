FROM ubuntu:20.04
MAINTAINER Matt Godbolt <matt@godbolt.org>

ARG DEBIAN_FRONTEND=noninteractive
RUN dpkg --add-architecture i386
RUN apt update -y -q && apt upgrade -y -q && apt update -y -q && \
    apt install -y -q \
    bmake \
    curl \
    g++ \
    gcc \
    gcc-multilib \
    git \
    libc6-dev-i386 \
    libc6-dev:i386 \
    linux-libc-dev \
    make \
    s3cmd \
    xz-utils \
    texinfo \
    zliblg-dev


RUN mkdir -p /root
COPY build /root/

WORKDIR /root
