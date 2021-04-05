#!/bin/bash

set -e

distro="${INPUT_DISTRO:-buster}"
arch="${INPUT_ARCH:-armhf}"

export DEBIAN_FRONTEND=noninteractive

# Install dependencies
sudo apt-get update -yqq
sudo apt-get install -y --no-install-recommends \
            devscripts \
            build-essential \
            sbuild \
            schroot \
            debootstrap

# Create schroot
sudo sbuild-createchroot --arch=${arch} ${distro} \
    /srv/chroot/${distro}-${arch}-sbuild http://deb.debian.org/debian

# Generate .dsc file
res=$(dpkg-source -b ./)

# Get .dsc file name
dsc_file=$(echo "$res" | grep .dsc | grep -o '[^ ]*$')

# Build inside schroot
sudo sbuild --arch=${arch} -c ${distro}-${arch}-sbuild \
    -d ${distro} ../${dsc_file}

find ../ -maxdepth 2 -name "*.deb"

#OS=debian DIST=jessie ARCH=armhf pbuilder --build --pkgname-logfile --debbuildopts -B ../${dsc_file}