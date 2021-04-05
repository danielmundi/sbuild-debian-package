#!/bin/bash

set -e

distro="${INPUT_DISTRO:-buster}"
arch="${INPUT_ARCH:-armhf}"

export DEBIAN_FRONTEND=noninteractive

echo "Install dependencies"
sudo apt-get update -yqq
sudo apt-get install -yqq --no-install-recommends \
            devscripts \
            build-essential \
            sbuild \
            schroot \
            debootstrap \
            qemu-user-static

echo "Create schroot"
sudo sbuild-createchroot --arch=${arch} ${distro} \
    /srv/chroot/${distro}-${arch}-sbuild http://deb.debian.org/debian

echo "Generate .dsc file"
res=$(dpkg-source -b ./)

echo "Get .dsc file name"
dsc_file=$(echo "$res" | grep .dsc | grep -o '[^ ]*$')

echo "Build inside schroot"
sudo sbuild --arch=${arch} -c ${distro}-${arch}-sbuild \
    -d ${distro} ../${dsc_file}