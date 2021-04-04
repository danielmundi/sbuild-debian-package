#!/bin/bash

distro="${INPUT_DISTRO:-buster}"
arch="${INPUT_ARCH:-armhf}"

export DEBIAN_FRONTEND=noninteractive

#cd /profiler

#dpkg --add-architecture ${arch}

#apt-get update -yqq
#apt-get install -yqq build-essential crossbuild-essential-${arch}

#echo "Build dependencies"
#apt-get build-dep -y -a${arch} ./
#apt-get build-dep -y ./
#mk-build-deps --install --host-arch ${arch} --tool='apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes debian/control

#echo "Build package"
#CONFIG_SITE=/etc/dpkg-cross/cross-config.${arch}  DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -a${arch} -Pcross,nocheck

set -e
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