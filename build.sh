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

schroot_exists=$(schroot -l | grep "chroot:${distro}-${arch}-sbuild")
if [ -z "${schroot}" ]; then
    echo "Create schroot"
    sudo sbuild-createchroot --arch=${arch} ${distro} \
        /srv/chroot/${distro}-${arch}-sbuild http://deb.debian.org/debian
fi

echo "Generate .dsc file"
res=$(dpkg-source -b ./)

echo "Get .dsc file name"
dsc_file=$(echo "$res" | grep .dsc | grep -o '[^ ]*$')

echo "Build inside schroot"
sudo sbuild --arch=${arch} -c ${distro}-${arch}-sbuild \
    -d ${distro} ../${dsc_file}

echo "Generated files:"
DEB_PACKAGE=$(find ./ -name "*.deb" | grep -v "dbgsym")
echo "Package: ${DEB_PACKAGE}"

# Set output
echo "::set-output name=deb-package::${DEB_PACKAGE}"
