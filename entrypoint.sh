#!/bin/bash

set -e

distro="${INPUT_DISTRO:-buster}"
arch="${INPUT_ARCH:-armhf}"

export DEBIAN_FRONTEND=noninteractive

#cd /profiler

dpkg --add-architecture ${arch}

apt-get update -yqq
apt-get install -yqq build-essential crossbuild-essential-${arch}

#echo "Build dependencies"
#apt-get build-dep -y -a${arch} ./
mk-build-deps --install --host-arch ${arch} --tool='apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes debian/control

#echo "Build package"
CONFIG_SITE=/etc/dpkg-cross/cross-config.${arch}  DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -a${arch} -Pcross,nocheck

