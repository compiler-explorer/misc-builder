FROM ubuntu:22.04

# Enable source repositories so we can use `apt build-dep` to get all the
# build dependencies for Perl
RUN sed -i -- 's/#deb-src/deb-src/g' /etc/apt/sources.list && \
    sed -i -- 's/# deb-src/deb-src/g' /etc/apt/sources.list

ARG DEBIAN_FRONTEND=noninteractive
RUN apt update -y -q && apt upgrade -y -q && apt update -y -q && \
    apt -q build-dep -y perl && \
    apt -q install -y \
    curl \
    git \
    perl \
    xz-utils \
    && \
    cpan Devel::PatchPerl \
    && \
    # clean up CPAN cache/build \
    rm -rf ~/.cpan \
    && \
    # Remove apt's lists to make the image smaller.
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root
COPY perl /root/
COPY common.sh /root/

WORKDIR /root
