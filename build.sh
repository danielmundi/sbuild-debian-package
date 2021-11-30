#!/bin/bash

set -e

distro="${INPUTS_DISTRO:-bullseye}"
arch="${INPUTS_ARCH:-armhf}"

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

set +e
schroot_name="${distro}-${arch}-sbuild"
schroot_exists=$(sudo schroot -l | grep -o "chroot:${schroot_name}")
set -e

if [ "${schroot_exists}" != "chroot:${schroot_name}" ]; then
    echo "Create schroot"
    sudo sbuild-createchroot --arch=${arch} ${distro} \
        /srv/chroot/${schroot_name} http://deb.debian.org/debian
fi

schroot_target="/srv/chroot/${schroot_name}"

# There is an issue on Ubuntu 20.04 and qemu 4.2 when entering fakeroot
# References:
# https://github.com/M-Reimer/repo-make/blob/master/repo-make-ci.sh#L252-L274
# https://github.com/osrf/multiarch-docker-image-generation/issues/36
# Start workaround
if [ -x "${schroot_target}/usr/bin/qemu-arm-static" ]; then
  echo 'BUILD.SH CI: qemu-arm-static build --- implementing semtimedop workaround'
  cat <<EOF > "/tmp/wrap_semop.c"
#include <unistd.h>
#include <asm/unistd.h>
#include <sys/syscall.h>
#include <linux/sem.h>
/* glibc 2.31 wraps semop() as a call to semtimedop() with the timespec set to NULL
 * qemu 3.1 doesn't support semtimedop(), so this wrapper syscalls the real semop()
 */
int semop(int semid, struct sembuf *sops, unsigned nsops)
{
  return syscall(__NR_semop, semid, sops, nsops);
}
EOF

  sudo cp "/tmp/wrap_semop.c" "${schroot_target}/tmp/wrap_semop.c"
  sudo schroot --chroot "${schroot_name}" --directory / gcc -fPIC -shared -o /opt/libpreload-semop.so /tmp/wrap_semop.c
  echo '/opt/libpreload-semop.so' | sudo tee -a "${schroot_target}/etc/ld.so.preload"
  exit
fi
# End workaround

echo "Generate .dsc file"
res=$(dpkg-source -b ./)

echo "Get .dsc file name"
dsc_file=$(echo "$res" | grep .dsc | grep -o '[^ ]*$')

echo "Build inside schroot"
sudo sbuild --arch=${arch} -c ${schroot_name} \
    -d ${distro} ../${dsc_file} --verbose

echo "Generated files:"
DEB_PACKAGE=$(find ./ -name "*.deb" | grep -v "dbgsym")
echo "Package: ${DEB_PACKAGE}"

# Set output
echo "::set-output name=deb-package::${DEB_PACKAGE}"
