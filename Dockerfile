FROM ubuntu:20.04
MAINTAINER Matt Godbolt <matt@godbolt.org>

ARG DEBIAN_FRONTEND=noninteractive
RUN dpkg --add-architecture i386
RUN apt update -y -q && apt upgrade -y -q && apt update -y -q && \
    apt install -y -q \
    bmake \
    build-essential \
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
    python3.9 \
    python3.9-venv \
    python3-pip \
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
    file \
    perl \
    xxd \
    mesa-common-dev \
    zlib1g-dev \
    libelf-dev \
    libdrm-dev \
    libudev-dev \
    libkrb5-dev \
    libssl-dev \
    libicu-dev \
    liblttng-ust-dev \
    libnuma-dev \
    libunwind8 \
    libunwind8-dev \
    language-pack-en-base \
    language-pack-en \
    autotools-dev \
    autoconf \
    ragel \
    wget \
    dos2unix \
    pkg-config \
    libglib2.0-dev \
    libpixman-1-dev \
    libsdl-dev \
    patchelf \
    libxml2-dev \
    bison \
    re2c \
    perl \
    cpanminus


RUN echo "LC_ALL=en_US.UTF-8" >> /etc/environment && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf && \
    locale-gen en_US.UTF-8

RUN cd /tmp && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws*

RUN pip3 install conan

RUN mkdir -p /opt/compiler-explorer
RUN git clone https://github.com/compiler-explorer/infra /opt/compiler-explorer/infra
RUN cd /opt/compiler-explorer/infra && make ce
RUN /opt/compiler-explorer/infra/bin/ce_install install 'x86/gcc 12.1.0'
RUN /opt/compiler-explorer/infra/bin/ce_install install 'clang-rocm 4.5.2'
RUN /opt/compiler-explorer/infra/bin/ce_install install 'clang-rocm 5.0.2'
RUN /opt/compiler-explorer/infra/bin/ce_install install 'clang-rocm 5.1.3'
RUN /opt/compiler-explorer/infra/bin/ce_install install 'clang-rocm 5.2.3'


RUN cpanm Modern::Perl

RUN cpanm App::Prove CPU::Z80::Assembler Data::Dump File::Path List::Uniq Object::Tiny::RW Regexp::Common Text::Diff YAML::Tiny

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

RUN mkdir /cmake && \
    cd /cmake && \
    wget https://github.com/Kitware/CMake/releases/download/v3.24.0-rc5/cmake-3.24.0-rc5-linux-x86_64.sh && \
    chmod +x cmake-3.24.0-rc5-linux-x86_64.sh && \
    ./cmake-3.24.0-rc5-linux-x86_64.sh --skip-license && \
    ls -l /cmake

RUN mkdir -p /root
COPY build /root/

WORKDIR /root
