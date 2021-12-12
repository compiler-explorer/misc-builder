FROM ubuntu:20.04
MAINTAINER Matt Godbolt <matt@godbolt.org>

ARG DEBIAN_FRONTEND=noninteractive
RUN dpkg --add-architecture i386
RUN apt update -y -q && apt upgrade -y -q && apt update -y -q && \
    apt install -y -q \
    bmake \
    build-essential \
    cmake \
    curl \
    g++ \
    gcc \
    gcc-multilib \
    git \
    flex \
    libc6-dev-i386 \
    libc6-dev:i386 \
    linux-libc-dev \
    make \
    python3 \
    s3cmd \
    xz-utils \
    unzip \
    subversion \
    texinfo \
    zlib1g-dev \
    clang \
    llvm \
    lldb \
    gettext \
    ninja-build \
    libkrb5-dev \
    libssl-dev \
    libicu-dev \
    liblttng-ust-dev \
    libnuma-dev \
    libunwind8 \
    libunwind8-dev \
    language-pack-en-base \
    language-pack-en

RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf && \
    locale-gen en_US.UTF-8

RUN cd /tmp && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws*

RUN mkdir -p /root
COPY build /root/

WORKDIR /root
