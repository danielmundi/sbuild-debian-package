#!/bin/bash

set -e

distro="${INPUTS_DISTRO:-bullseye}"
arch="${INPUTS_ARCH:-armhf}"
run_lintian="${INPUTS_RUN_LINTIAN:-true}"

if [ "${run_lintian}" == "true" ]; then
    run_lintian="--run-lintian"
else
    run_lintian="--no-run-lintian"
fi

export DEBIAN_FRONTEND=noninteractive

echo "Install dependencies"
sudo apt-get update -yqq
sudo apt-get install -yqq --no-install-recommends \
            devscripts \
            build-essential \
            sbuild \
            schroot \
            debootstrap

# Hacky install of qemu-user-static from bullseye-backports if we're doing a build for bullseye/arm64
# Ref: https://www.mail-archive.com/ubuntu-bugs@lists.ubuntu.com/msg5979049.html
if [ "${distro}" == "bullseye" ] && [ "${arch}" == "arm64" ]; then
    echo 'BUILD.SH CI: implementing bullseye/arm64 workaround'
    echo "deb [trusted=yes] http://deb.debian.org/debian bullseye-backports main" | sudo tee -a "/etc/apt/sources.list.d/backports.list"
    sudo apt-get update -yqq
    sudo apt-get install -yqq --no-install-recommends qemu-user-static -t bullseye-backports
else
    sudo apt-get install -yqq --no-install-recommends qemu-user-static \
            binfmt-support
fi


set +e
schroot_name="${distro}-${arch}-sbuild"
schroot_exists=$(sudo schroot -l | grep -o "chroot:${schroot_name}")
set -e

schroot_target="/srv/chroot/${schroot_name}"
if [ "${schroot_exists}" != "chroot:${schroot_name}" ]; then
    echo "Create schroot"
    sudo sbuild-createchroot --arch=${arch} ${distro} \
        "${schroot_target}" http://deb.debian.org/debian
fi

# There is an issue on Ubuntu 20.04 and qemu 4.2 when entering fakeroot
# References:
# https://github.com/M-Reimer/repo-make/blob/master/repo-make-ci.sh#L252-L274
# https://github.com/osrf/multiarch-docker-image-generation/issues/36
# Start workaround
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

cat <<EOF > "/tmp/pre-build.sh"
#!/bin/bash
gcc -fPIC -shared -Q -o /opt/libpreload-semop.so /tmp/wrap_semop.c
chmod 777 /opt/libpreload-semop.so
echo '/opt/libpreload-semop.so' >> /etc/ld.so.preload
EOF

sudo cp "/tmp/wrap_semop.c" "${schroot_target}/tmp/wrap_semop.c"
sudo cp "/tmp/pre-build.sh" "${schroot_target}/tmp/pre-build.sh"
# End workaround

# More workaround for qemu >5.2
sudo mkdir -p "${schroot_target}"/usr/libexec/qemu-binfmt

echo "Generate .dsc file"
res=$(dpkg-source -b ./)

echo "Get .dsc file name"
dsc_file=$(echo "$res" | grep .dsc | grep -o '[^ ]*$')

echo "Build inside schroot"
sudo sbuild --arch=${arch} -c ${schroot_name} ${run_lintian} \
    --chroot-setup-commands="chmod +x /tmp/pre-build.sh; /tmp/pre-build.sh" \
    -d ${distro} ../${dsc_file} --verbose

echo "Generated files:"
DEB_PACKAGE=$(find ./ -name "*.deb" | grep -v "dbgsym")
echo "Package: ${DEB_PACKAGE}"

# Set output
echo "::set-output name=deb-package::${DEB_PACKAGE}"
