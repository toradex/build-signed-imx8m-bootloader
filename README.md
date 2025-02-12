# build-signed-imx8m-bootloader

This project provides a containerized environment for building a signed bootloader image for Toradex's Verdin iMX8MM and Verdin iMX8MP System-on-Modules.

Internally, it leverages the Yocto Project/OpenEmbedded to build the bootloader, taking advantage of the existing features provided by the [meta-toradex-security](https://github.com/toradex/meta-toradex-security) layer.

By using Yocto Project/OpenEmbedded, this approach avoids reinventing the wheel (i.e., implementing everything from scratch) while benefiting from Toradex's testing and maintenance. This approach also simplifies adding new features and applying updates, ensuring a more efficient and well-supported development process.

The following sections provide a step-by-step guide for setting up the build environment and generate the signed bootloader.

## Build the container

First, clone this repository onto your development machine:

```Shell
git clone https://github.com/sergioprado/build-signed-imx8m-bootloader.git -b scarthgap-7.x.y
```

Go to the directory of the repository:

```Shell
cd build-signed-imx8m-bootloader/
```

And build the container that will be used for the bootloader compilation. Feel free to change the container image tag if necessary (`toradex/build-signed-imx8m-bootloader` in this example):

```Shell
docker build -t toradex/build-signed-imx8m-bootloader .
```

## Create the build directory

Before building the signed bootloader, create a build directory that will hold build artifacts and configuration files:

```Shell
mkdir -p build
```

## Set up the signing keys

The signing process requires two sets of cryptographic keys to be placed inside the build directory:

- **Bootloader signing keys**: must be stored inside `build/keys/cst` and are generated using the NXP Code Signing Tool (CST).
- **FIT image verification keys**: must be placed inside `build/keys/fit` and are used by the bootloader to verify the signed FIT image before execution.

Once the keys are properly set up, the `keys` directory should look like this:

```Shell
$ tree -L 2 build/keys/
build/keys/
├── cst
│   ├── ca
│   ├── code
│   ├── crts
│   ├── docs
│   ├── keys
│   ├── LICENSE.bsd3
│   ├── LICENSE.hidapi
│   ├── LICENSE.openssl
│   ├── linux32
│   ├── linux64
│   ├── mingw32
│   ├── osx
│   ├── Release_Notes.txt
│   └── Software_Content_Register_CST.txt
└── fit
    ├── dev2.crt
    ├── dev2.key
    ├── dev.crt
    └── dev.key
```

## Customize the build

By default, the bootloader is built with support for:

- OP-TEE (Trusted Execution Environment)
- fTPM (Firmware-based TPM)
- PKCS#11 (Cryptographic token standard)

If you need to change the default configuration, create a `build.conf` file inside the build directory and define a few additional OpenEmbedded (OE) variables. These variables are documented in the [meta-toradex-security](https://github.com/toradex/meta-toradex-security) repository.

- [README-secure-boot-imx.md](https://github.com/toradex/meta-toradex-security/blob/scarthgap-7.x.y/docs/README-secure-boot-imx.md#configuring-habahab-support): contains variables for customizing bootloader signing.
- [README-secure-boot.md](https://github.com/toradex/meta-toradex-security/blob/scarthgap-7.x.y/docs/README-secure-boot.md#configuring-fit-image-signing): explains how to enable/disable and configure signature checking for the FIT image.
- [README-optee.md](https://github.com/toradex/meta-toradex-security/blob/scarthgap-7.x.y/docs/README-optee.md): covers OP-TEE configuration and features.

In the example below, same additional variables were configured to enable OP-TEE debug messages and RPMB support in `development` mode:

```Shell
cat build/build.conf
```

```txt
TDX_OPTEE_DEBUG = "1"
TDX_OPTEE_FS_RPMB = "1"
TDX_OPTEE_FS_RPMB_MODE = "development"
```

## Build the signed bootloader

Once everything is set up, use Docker to run the build process inside the container.

The command below will build the signed bootloader for Verdin iMX8MP. Make sure to use the same tag used to create the container image (`toradex/build-signed-imx8m-bootloader` in this example):

```Shell
docker run --rm -it -v ./build:/build -e MACHINE=verdin-imx8mp toradex/build-signed-imx8m-bootloader build.sh
```

To build it for iMX8MM, change the `MACHINE` variable to `verdin-imx8mm`.

The first build might take some time, as a toolchain will also be built before building U-Boot, OP-TEE and all other bootloader artifacts to create the final boot container for the target platform.

## Flash the bootloader to the SoM

After the build process completes, the signed bootloader will be located in the build directory:

```Shell
$ ls build/imx-boot-*
build/imx-boot-verdin-imx8mp
```

To flash the bootloader onto the SoM, you can:

- Use [Toradex Easy Installer](https://www.toradex.com/tools-libraries/toradex-easy-installer), which provides a GUI-based way to flash the bootloader onto the module.
- Use NXP's [uuu](https://github.com/nxp-imx/mfgtools) tool, which allows flashing over USB.
- Use the `dd` command to write the bootloader directly to the eMMC storage, as in the example below:

```Shell
dd if=imx-boot-verdin-imx8mp of=/dev/mmcblk0 seek=2
```

## Integrate the Bootloader into Your System

The U-Boot bootloader supports Distro Boot, allowing you to manage the boot process through a boot script. For more details on Distro Boot, refer to the [article about Distro Boot](https://developer.toradex.com/linux-bsp/os-development/boot/distro-boot/) at the Toradex's developer website.
