# -*- coding: utf-8 -*-
#
# This software may be modified and distributed under the terms
# of the MIT license.  See the LICENSE file for details.
#
# Multistage Dockerfile to build a Python 3.9 image based on Debian Buster.
# Inspired by https://github.com/docker-library/python/blob/master/3.8/buster/slim/Dockerfile
# Notable changes:
# - adapted to multistage build
# - removed cleanup steps in builder image for readibility
# - build without tk, ncurses and readline

ARG BASE_IMAGE_NAME=debian:buster-slim

# Intermediate build container
FROM $BASE_IMAGE_NAME AS builder

ENV PYTHON_VERSION 3.9.6
ENV PYTHON_PIP_VERSION 21.1.3

ARG BASE_IMAGE_NAME
RUN echo "Using base image \"${BASE_IMAGE_NAME}\" to build Python ${PYTHON_VERSION}"

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

ENV GPG_KEY E3FF2839C048B25C084DEBE9B26995E310250568
# https://github.com/pypa/get-pip
ENV PYTHON_GET_PIP_URL https://bootstrap.pypa.io/get-pip.py
ENV PYTHON_GET_PIP_SHA256 6665659241292b2147b58922b9ffe11dda66b39d52d8a6f3aa310bc1d60ea6f7

RUN set -ex && \
	apt-get update && apt-get install --assume-yes --no-install-recommends \
		ca-certificates \
		dirmngr \
		dpkg-dev \
		gcc \
		gnupg \
		libbz2-dev \
		libc6-dev \
		libexpat1-dev \
		libffi-dev \
		liblzma-dev \
		libsqlite3-dev \
		libssl-dev \
		make \
		netbase \
		uuid-dev \
		wget \
		xz-utils \
		zlib1g-dev

RUN wget --no-verbose --output-document=python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
	&& wget --no-verbose --output-document=python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --batch --keyserver keys.openpgp.org --recv-keys "$GPG_KEY" \
	&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& { command -v gpgconf > /dev/null && gpgconf --kill all || :; } \
	&& rm -rf "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz

RUN cd /usr/src/python \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure --help \
	&& ./configure \
		--build="$gnuArch" \
		--prefix="/python" \
		--enable-loadable-sqlite-extensions \
		--enable-optimizations \
		--enable-ipv6 \
		--disable-shared \
		--with-system-expat \
		--without-ensurepip \
	&& make -j "$(nproc)" \
	&& make install

RUN strip /python/bin/python3.9 && \
	strip --strip-unneeded /python/lib/python3.9/config-3.9-x86_64-linux-gnu/libpython3.9.a && \
	strip --strip-unneeded /python/lib/python3.9/lib-dynload/*.so && \
	rm /python/lib/libpython3.9.a && \
	ln /python/lib/python3.9/config-3.9-x86_64-linux-gnu/libpython3.9.a /python/lib/libpython3.9.a

# install pip
RUN set -ex; \
	\
	wget --no-verbose --output-document=get-pip.py "$PYTHON_GET_PIP_URL"; \
	echo "$PYTHON_GET_PIP_SHA256 *get-pip.py" | sha256sum --check --strict -; \
	\
	/python/bin/python3 get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" "wheel"

# cleanup
RUN find /python/lib -type d -a \( \
		-name test -o \
		-name tests -o \
		-name idlelib -o \
		-name turtledemo -o \
		-name pydoc_data -o \
		-name tkinter \) -exec rm -rf {} +


# App container
FROM $BASE_IMAGE_NAME AS app

ENV LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=true

# make some useful symlinks that are expected to exist
RUN ln -s /python/bin/python3-config /usr/local/bin/python-config && \
	ln -s /python/bin/python3 /usr/local/bin/python && \
	ln -s /python/bin/python3 /usr/local/bin/python3 && \
	ln -s /python/bin/pip3 /usr/local/bin/pip && \
	ln -s /python/bin/pip3 /usr/local/bin/pip3 && \
	# install depedencies
	apt-get update && \
	apt-get install --assume-yes --no-install-recommends ca-certificates libexpat1 libsqlite3-0 libssl1.1 && \
	apt-get purge --assume-yes --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
	rm -rf /var/lib/apt/lists/*

# copy in Python environment
COPY --from=builder /python /python

CMD ["python3"]
