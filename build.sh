#!/bin/bash

# exits if a command fails
set -e

run() {
    echo && echo RUNNING: "$@"
    eval "$*"
}

# check if machine is set
if [ -z "$MACHINE" ]
then
    echo "Please set MACHINE variable"
    exit 1
fi

# set working directory
WORKDIR=$(pwd)

# setup image
if [ -z "$IMAGE" ]
then
    IMAGE="virtual/bootloader"
fi

# extra configuration file
if [ -z "$OECONF" ]
then
    OECONF="/build/build.conf"
fi

# setup repo manifest file
if [ -z "$MANIFEST" ]
then
    MANIFEST=tdxref/default.xml
fi

# setup repo manifest branch
if [ -z "$BRANCH" ]
then
    BRANCH=scarthgap-7.x.y
fi

# setup repo manifest tag
if [ -z "$TAG" ]
then
    TAG=7.1.0
fi

# keys directory
if [ -z "$KEYSDIR" ]
then
    KEYSDIR="$WORKDIR/keys"
fi

# print build information
echo "Build configuration:"
echo "  MACHINE=$MACHINE"
echo "  IMAGE=$IMAGE"
echo "  OECONF=$OECONF"
echo "  MANIFEST=$MANIFEST"
echo "  BRANCH=$BRANCH"
echo "  TAG=$TAG"
echo "  KEYSDIR=$KEYSDIR"

# configure Git if not configured
if ! git config --global --get user.email; then
    run git config --global user.email "you@example.com"
    run git config --global user.name "Your Name"
    run git config --global color.ui false
fi

# initialize repo
run repo init -u https://git.toradex.com/toradex-manifest.git -b refs/tags/"$TAG" -m "$MANIFEST"
run repo sync

# change name of build directory
sed -i "s/^BUILDDIR=.*/BUILDDIR=..\/..\/$MACHINE/g" export

# Initialize build environment
run source export

# setup meta-toradex-security
run rm -rf ../layers/meta-toradex-security
run git clone https://github.com/toradex/meta-toradex-security.git -b "$BRANCH" ../layers/meta-toradex-security
if ! grep -q meta-toradex-security conf/bblayers.conf; then
    echo 'BBLAYERS += "${TOPDIR}/../layers/meta-toradex-security"' >> conf/bblayers.conf
    echo 'BBLAYERS += "${TOPDIR}/../layers/meta-security"' >> conf/bblayers.conf
    echo 'BBLAYERS += "${TOPDIR}/../layers/meta-openembedded/meta-perl"' >> conf/bblayers.conf
fi

# setup meta-secure-boot-imx8m
run rm -rf ../layers/meta-secure-boot-imx8m
run git clone https://github.com/toradex/meta-secure-boot-imx8m.git -b "$BRANCH" ../layers/meta-secure-boot-imx8m
if ! grep -q meta-secure-boot-imx8m conf/bblayers.conf; then
    echo 'BBLAYERS += "${TOPDIR}/../layers/meta-secure-boot-imx8m"' >> conf/bblayers.conf
fi

# setup auto.conf
echo -e "MACHINE=\"$MACHINE\"\n" > conf/auto.conf
cat ../layers/meta-secure-boot-imx8m/conf/template/auto.conf.sample >> conf/auto.conf
if [ -e "$OECONF" ]; then
    echo >> conf/auto.conf && cat "$OECONF" >> conf/auto.conf
fi

# use /sstate-cache-hotstart for cache if present and non-empty
if [ "$(ls -A /sstate-cache-hotstart)" ]; then
    echo 'SSTATE_DIR = "/sstate-cache-hotstart"' >> conf/auto.conf
fi

# setup keys directory
rm -rf keys
ln -s "$KEYSDIR" keys

# build
run bitbake "$IMAGE"

# success
echo -e "\nSuccessfully finish building a signed boot container for [$MACHINE]"

# copy generated boot container
BOOTIMAGE="imx-boot-$MACHINE"
cp "deploy/images/$MACHINE/imx-boot" "$WORKDIR/$BOOTIMAGE"
echo "Boot container image is available in $WORKDIR/$BOOTIMAGE"
