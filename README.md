# Python 3 image for Docker

## About

A slim Python 3 image for Docker.
Currently the resulting image contains Python 3.9, compiled from source and
the `pip` and `wheel` packages are included.

This is heavily inspired from the official Python image at
https://github.com/docker-library/python/blob/master/3.9/buster/slim/Dockerfile
but has a few differences:

  - use multi-stage build in Dockerfile to ease the build step and still get
    a small image
  - build Python without the `ncurses`, `readline` and `tk` modules for image
    size, assuming a non-interactively used Python interpreter does not need
    these modules
  - the Python interpreter is installed to /python

The Dockerfile uses `debian:buster-slim` (https://hub.docker.com/_/debian/)
as base but this is configurable at build time using `BASE_IMAGE_NAME`
as build argument.
Tested with `debian:buster-slim`, `debian:buster-slim` and `ubuntu:18.04`,
the Dockerfile generally should work with most Debian based base images.

### Motivation

- Be able to specify a custom base image
- Have a Python Docker image as small as possible while still usable for most use cases


## Build

Just build the image:

    docker build --tag python3:latest .

Use a different base image:

    docker build --build-arg BASE_IMAGE_NAME=ubuntu:bionic --tag python3:bionic .


## Usage

By default, the Python interpreter is started when the image is ran:

    docker run --rm -it --name python3 python3:latest

To change this, just overwrite the `CMD` instruction in your Dockerfile.


## License

Licensed under the MIT License.


## Author

Enrico Tröger <enrico.troeger@uvena.de>
