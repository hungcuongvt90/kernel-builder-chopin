#/bin/bash

sudo sudo apt update
sudo apt-get install -y curl git ftp lftp wget libarchive-tools ccache python2 python2-dev python3
sudo apt-get install -y pngcrush schedtool dpkg-dev liblz4-tool make optipng maven dwarves device-tree-compiler 
sudo apt-get install -y libc6-dev-i386 libelf-dev lib32ncurses5-dev libx11-dev lib32z-dev libgl1-mesa-dev xsltproc
sudo apt-get install -y libxml2-utils libbz2-dev libbz2-1.0 libghc-bzlib-dev squashfs-tools lzop flex tree
sudo apt-get install -y build-essential bc gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi libssl-dev libfl-dev
sudo apt-get install -y pwgen libswitch-perl policycoreutils minicom libxml-sax-base-perl libxml-simple-perl 
sudo apt-get install -y zip unzip tar gzip bzip2 rar unrar llvm g++-multilib bison gperf zlib1g-dev automake lld
sudo sudo apt autoremove -y

export WORKSPACE=$HOME/work/kernel-builder-chopin/kernel-builder-chopin
export BUILD_DATE=20102025

# Kernel source configuration
export KERNEL_NAME=ishtar
export KERNEL_REPO=https://github.com/hungcuongvt90/android_gki_kernel_5.15_common
export KERNEL_BRANCH=android13-5.15-2025-05
export KERNEL_DEVICE="gki"
export KERNEL_DEFCONFIG_PATH="gki_defconfig"

export KERNEL_PATCH_REPO_URL=https://github.com/SukiSU-Ultra/SukiSU_patch
export HOOK_VARIANT=tracepoint
export SUSFS_BRANCH=gki-android13-5.15
export USE_ZRAM=false
export ZRAM_PATCH_VERSION=5.15
export USE_KPM=true

# Whether to use ccache to speed up compilation
export ENABLE_CCACHE=true

# Whether to use ANYKERNEL3 packaged flash package
export USE_ANYKERNEL3=true

# Whether to publish
export CONFIRM_RELEASE=true

# Whether to enable KernelSU
export ENABLE_KERNELSU=true

# Whether to enable KernelSU SFS
export ENABLE_KERNELSU_SFS=true

# Set output & ccache directory
export OUT_DIR="${WORKSPACE}/out"
export CCACHE_DIR="${WORKSPACE}/ccache"
export ARCH="arm64"
export CONFIG_FILE="${WORKSPACE}/${KERNEL_NAME}/arch/$ARCH/configs/gki_defconfig"
export kernel_version=5.15

# Create output directory
mkdir -p $OUT_DIR
mkdir -p $WORKSPACE

# Initialize ccache
ccache -o compression=false -o cache_dir=$CCACHE_DIR

cd $WORKSPACE

# Generate configuration's hash
HASH=0866e153dfcc6bd976c2117b14bbaec292d57f78

git clone --recursive --depth=1 -j $(nproc) --branch $KERNEL_BRANCH $KERNEL_REPO $KERNEL_NAME

# Clone repositories using the branch names
git clone https://github.com/ShirkNeko/susfs4ksu.git -b "$SUSFS_BRANCH"
git clone https://github.com/SukiSU-Ultra/SukiSU_patch.git

echo "🤔 PATH Variable: $PATH"

ARCH="arm64"
CC="/home/runner/clang/bin/clang"

args="-j$(nproc --all) O=$OUT_DIR ARCH=$ARCH"
if [ -n "$CC" ]; then

    if [[ "$CC" == *"/"* ]]; then
        CC=/home/runner/$CC
    fi

    if [ $ENABLE_CCACHE == "true" ]; then
        args="$args CC=\\"ccache $CC\\""
    else
        args="$args CC=$CC"
    fi
fi

args="$args BUILD_SHARED_LIBS=ON"

export ARCH=$ARCH
export ARGS=$args

echo "🤔 $args"

export kernelsu_branch=Stable
export kernelsu_variant=SukiSU

echo "Determine the branch for SukiSU KernelSU"

if [[ "$kernelsu_branch" == "Stable" && ( "$kernelsu_variant" == "SukiSU" ) ]]; then
    export KSU_BRANCH="-s susfs-main"
elif [[ "$kernelsu_branch" == "Dev" && ( "$kernelsu_variant" == "SukiSU" ) ]]; then
    export KSU_BRANCH="-s susfs-test"
fi

echo "Setup KernelSU"
# Delete old KernelSU
if [ -d "./KernelSU" ]; then
    rm -rf "./KernelSU"
fi

if [ -d "./drivers/kernelsu" ]; then
    rm -rf "./drivers/kernelsu"
fi

if [ "$kernelsu_variant" == "Official" ]; then
    echo "Adding KernelSU Official..."
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash $KSU_BRANCH
elif [ "$kernelsu_variant" == "Next" ]; then
    echo "Adding KernelSU Next..."
    curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next-susfs/kernel/setup.sh" | bash $KSU_BRANCH
elif [ "$kernelsu_variant" == "MKSU" ]; then
    echo "Adding KernelSU MKSU..."
    curl -LSs "https://raw.githubusercontent.com/5ec1cff/KernelSU/main/kernel/setup.sh" | bash $KSU_BRANCH
else
    echo "Adding KernelSU SukiSU..."
    curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash $KSU_BRANCH
fi

echo "Setup KSU SUSFS"

cd "$WORKSPACE/$KERNEL_NAME"

if [[ "$ENABLE_KERNELSU" == "true" && "$ENABLE_KERNELSU_SFS" == "true" ]]; then
    if [ "$kernelsu_variant" == "Official" ]; then
        echo "Applying SUSFS patches for Official KernelSU..."
        cp ../susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./
        patch -p1 --forward --fuzz=3 < 10_enable_susfs_for_ksu.patch
    elif [ "$kernelsu_variant" == "Next" ]; then
        echo "Applying SUSFS patches for KernelSU-Next..."
        cp ../kernel_patches/next/scope_min_manual_hooks_v1.5.patch ./
        patch -p1 -F 3 < scope_min_manual_hooks_v1.5.patch
    elif [ "$kernelsu_variant" == "MKSU" ]; then
        echo "Applying SUSFS patches for MKSU..."
        cp ../susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./
        patch -p1 --forward --fuzz=3 < 10_enable_susfs_for_ksu.patch || true

        echo "Applying MKSU specific SUSFS patch..."
        cp ../kernel_patches/mksu/mksu_susfs.patch ./
        patch -p1 < mksu_susfs.patch || true
        cp ../kernel_patches/mksu/fix.patch ./
        patch -p1 < fix.patch || true
    elif [ "$kernelsu_variant" == "SukiSU" ]; then
        echo "Applying SUSFS patches for SukiSU..."
        cp ../susfs4ksu/kernel_patches/50_add_susfs_in_$SUSFS_BRANCH.patch ./
        cp ../susfs4ksu/kernel_patches/fs/* ./fs/
        cp ../susfs4ksu/kernel_patches/include/linux/* ./include/linux/

        patch -p1 < 50_add_susfs_in_$SUSFS_BRANCH.patch || true

        if [ "$HOOK_VARIANT" == "tracepoint" ]; then
            cp ../SukiSU_patch/hooks/sukisu_tracepoint_hooks_v1.1.patch ./
            patch -p1 -F 3 < sukisu_tracepoint_hooks_v1.1.patch
        else
            cp ../SukiSU_patch/hooks/syscall_hooks.patch ./
            patch -p1 -F 3 < syscall_hooks.patch
        fi
    else
        echo "Invalid KernelSU variant selected!"
        exit 1
    fi
fi

export ANYKERNEL3_FILE="$kernelsu_variant-NO-KPM-$HOOK_VARIANT-$KERNEL_NAME-$BUILD_DATE"
export RELEASE_TAG_NAME="$kernelsu_variant-NO-KPM-$HOOK_VARIANT-$KERNEL_NAME-$BUILD_DATE"


echo "Apply Hide Stuff Patches"

# Apply additional patch

if [ "$kernelsu_variant" == "SukiSU" ]; then
    cp ../SukiSU_patch/69_hide_stuff.patch ./
    patch -p1 -F 3 < 69_hide_stuff.patch
else
    cp ../kernel_patches/69_hide_stuff.patch ./
    patch -p1 -F 3 < 69_hide_stuff.patch
fi

# Apply Mountify configuration settings
echo "Adding configuration settings to gki_defconfig..."

# Add KSU configuration settings
echo "CONFIG_OVERLAY_FS=y" >> $CONFIG_FILE

# name: Add SUSFS configuration settings
echo "Adding configuration settings to gki_defconfig..."

# Add KSU configuration settings
echo "CONFIG_KSU=y" >> $CONFIG_FILE

if [ "$kernelsu_variant" == "Next" ]; then
    echo "CONFIG_KSU_KPROBES_HOOK=n" >> $CONFIG_FILE
    echo "CONFIG_KSU_SUSFS_SUS_SU=n" >> $CONFIG_FILE
elif [ "$kernelsu_variant" == "SukiSU" ]; then
    echo "CONFIG_KPM=y" >> $CONFIG_FILE
    echo "CONFIG_KSU_SUSFS_SUS_SU=n" >> $CONFIG_FILE
elif [ "kernelsu_variant" == "MKSU" ]; then
    echo "CONFIG_KSU_SUSFS_SUS_SU=n" >> $CONFIG_FILE
fi

if [ "$HOOK_VARIANT" == "tracepoint" ]; then
    echo "CONFIG_KSU_TRACEPOINT_HOOK=y" >>  $CONFIG_FILE
else
    echo "CONFIG_KSU_MANUAL_HOOK=y" >> $CONFIG_FILE
fi

# Add additional tmpfs config setting
echo "CONFIG_TMPFS_XATTR=y" >> $CONFIG_FILE
echo "CONFIG_TMPFS_POSIX_ACL=y" >> $CONFIG_FILE

# Add additional config setting
echo "CONFIG_IP_NF_TARGET_TTL=y" >> $CONFIG_FILE
echo "CONFIG_IP6_NF_TARGET_HL=y" >> $CONFIG_FILE
echo "CONFIG_IP6_NF_MATCH_HL=y" >> $CONFIG_FILE

# Add BBR Config
echo "CONFIG_TCP_CONG_ADVANCED=y" >> $CONFIG_FILE
echo "CONFIG_TCP_CONG_BBR=y" >> $CONFIG_FILE
echo "CONFIG_NET_SCH_FQ=y" >> $CONFIG_FILE
echo "CONFIG_TCP_CONG_BIC=n" >> $CONFIG_FILE
echo "CONFIG_TCP_CONG_WESTWOOD=n" >> $CONFIG_FILE
echo "CONFIG_TCP_CONG_HTCP=n" >> $CONFIG_FILE

# Add SUSFS configuration settings
echo "CONFIG_KSU_SUSFS=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y" >> $CONFIG_FILE
if [ "$kernel_version" != "6.6" ]; then
    echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> $CONFIG_FILE
else
    echo "CONFIG_KSU_SUSFS_SUS_PATH=n" >> $CONFIG_FILE
fi
echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_SUS_OVERLAYFS=n" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> $CONFIG_FILE
echo "CONFIG_KSU_MANUAL_SU=n" >> $CONFIG_FILE

# Remove check_defconfig
sed -i 's/check_defconfig//' ./build.config.gki

sed -i '$s|echo "\$res"|echo "\$res-ab11001737"|' ./scripts/setlocalversion

# 👍 Start building the kernel
cd $WORKSPACE/$KERNEL_NAME

echo "🤔 PATH Variable: $PATH"
export KBUILD_BUILD_TIMESTAMP="Wed Oct 25 05:41:09 UTC 2023"
export KBUILD_BUILD_USER=cuongnguyen

echo "Start to build kernel with following args:\n $ARGS\nDeconfig path:\n$KERNEL_DEFCONFIG_PATH"

CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- AS=clang/bin/llvm-as AR=/home/runner/clang/bin/llvm-ar NM=/home/runner/clang/bin/lvm-nm OBJCOPY=/home/runner/clang/bin/llvm-objcopy OBJDUMP=/home/runner/clang/bin/llvm-objdump STRIP=/home/runner/clang/bin/llvm-strip LD=/home/runner/clang/bin/ld.lld LTO=thin make $ARGS $KERNEL_DEFCONFIG_PATH
CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- AS=clang/bin/llvm-as AR=/home/runner/clang/bin/llvm-ar NM=/home/runner/clang/bin/lvm-nm OBJCOPY=/home/runner/clang/bin/llvm-objcopy OBJDUMP=/home/runner/clang/bin/llvm-objdump STRIP=/home/runner/clang/bin/llvm-strip LD=/home/runner/clang/bin/ld.lld LTO=thin make $ARGS

# name: Apply KPM
cd $OUT_DIR/arch/$ARCH/boot/
if [[ "$use_kpm" == "true" && "$kernelsu_variant" == "SukiSU" && "$android_version" != "6.6" ]]; then
    echo "Start to patch KPM" 
    pwd
    ls -la .
    curl -LSs "https://raw.githubusercontent.com/ShirkNeko/SukiSU_patch/refs/heads/main/kpm/patch_linux" -o patch_linux
    chmod +x patch_linux
    ./patch_linux
    rm -f Image
    mv oImage Image
    export ANYKERNEL3_FILE="$kernelsu_variant-KPM-$HOOK_VARIANT-$KERNEL_NAME-$BUILD_DATE"
    export RELEASE_TAG_NAME="$kernelsu_variant-KPM-$HOOK_VARIANT-$KERNEL_NAME-$BUILD_DATE"
fi

# ⏰ Pack Anykernel3
if [ "$USE_ANYKERNEL3" == "true" ]; then
    git clone --recursive --depth=1 -j $(nproc) https://github.com/WildPlusKernel/AnyKernel3 AnyKernel3
    echo "🤔 Use WildPlus Anykernel3 => (https://github.com/WildPlusKernel/AnyKernel3)"

    if [ -e "$OUT_DIR/arch/$ARCH/boot/Image.gz-dtb" ]; then
        cp -f $OUT_DIR/arch/$ARCH/boot/Image.gz-dtb ./AnyKernel3/
    fi

    if [ -e "$OUT_DIR/arch/$ARCH/boot/Image" ]; then
        cp -f $OUT_DIR/arch/$ARCH/boot/Image ./AnyKernel3/
    fi
    
    if [ -e "$OUT_DIR/arch/$ARCH/boot/dtbo" ]; then
        cp -f $OUT_DIR/arch/$ARCH/boot/dtbo ./AnyKernel3/
    fi

    if [ -e "$OUT_DIR/arch/$ARCH/boot/dtbo.img" ]; then
        cp -f $OUT_DIR/arch/$ARCH/boot/dtbo.img ./AnyKernel3/
    fi

    cd AnyKernel3/
    zip -q -r "$ANYKERNEL3_FILE.zip" *
    echo "Pack anykernel success. \nls -la"
fi#/bin/bash

sudo sudo apt update
sudo apt-get install -y curl git ftp lftp wget libarchive-tools ccache python2 python2-dev python3
sudo apt-get install -y pngcrush schedtool dpkg-dev liblz4-tool make optipng maven dwarves device-tree-compiler 
sudo apt-get install -y libc6-dev-i386 libelf-dev lib32ncurses5-dev libx11-dev lib32z-dev libgl1-mesa-dev xsltproc
sudo apt-get install -y libxml2-utils libbz2-dev libbz2-1.0 libghc-bzlib-dev squashfs-tools lzop flex tree
sudo apt-get install -y build-essential bc gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi libssl-dev libfl-dev
sudo apt-get install -y pwgen libswitch-perl policycoreutils minicom libxml-sax-base-perl libxml-simple-perl 
sudo apt-get install -y zip unzip tar gzip bzip2 rar unrar llvm g++-multilib bison gperf zlib1g-dev automake lld
sudo sudo apt autoremove -y

export WORKSPACE=$HOME/work/kernel-builder-chopin/kernel-builder-chopin
export BUILD_DATE=20102025

# Kernel source configuration
export KERNEL_NAME=ishtar
export KERNEL_REPO=https://github.com/hungcuongvt90/android_gki_kernel_5.15_common
export KERNEL_BRANCH=android13-5.15-2025-05
export KERNEL_DEVICE="gki"
export KERNEL_DEFCONFIG_PATH="gki_defconfig"

export KERNEL_PATCH_REPO_URL=https://github.com/SukiSU-Ultra/SukiSU_patch
export HOOK_VARIANT=tracepoint
export SUSFS_BRANCH=gki-android13-5.15
export USE_ZRAM=false
export ZRAM_PATCH_VERSION=5.15
export USE_KPM=true

# Whether to use ccache to speed up compilation
export ENABLE_CCACHE=true

# Whether to use ANYKERNEL3 packaged flash package
export USE_ANYKERNEL3=true

# Whether to publish
export CONFIRM_RELEASE=true

# Whether to enable KernelSU
export ENABLE_KERNELSU=true

# Whether to enable KernelSU SFS
export ENABLE_KERNELSU_SFS=true

# Set output & ccache directory
export OUT_DIR="${WORKSPACE}/out"
export CCACHE_DIR="${WORKSPACE}/ccache"
export ARCH="arm64"
export CONFIG_FILE="${WORKSPACE}/${KERNEL_NAME}/arch/$ARCH/configs/gki_defconfig"
export kernel_version=5.15

# Create output directory
mkdir -p $OUT_DIR
mkdir -p $WORKSPACE

# Initialize ccache
ccache -o compression=false -o cache_dir=$CCACHE_DIR

cd $WORKSPACE

# Generate configuration's hash
HASH=0866e153dfcc6bd976c2117b14bbaec292d57f78

git clone --recursive --depth=1 -j $(nproc) --branch $KERNEL_BRANCH $KERNEL_REPO $KERNEL_NAME

# Clone repositories using the branch names
git clone https://github.com/ShirkNeko/susfs4ksu.git -b "$SUSFS_BRANCH"
git clone https://github.com/SukiSU-Ultra/SukiSU_patch.git

echo "🤔 PATH Variable: $PATH"

ARCH="arm64"
CC="/home/runner/clang/bin/clang"

args="-j$(nproc --all) O=$OUT_DIR ARCH=$ARCH"
if [ -n "$CC" ]; then

    if [[ "$CC" == *"/"* ]]; then
        CC=/home/runner/$CC
    fi

    if [ $ENABLE_CCACHE == "true" ]; then
        args="$args CC=\\"ccache $CC\\""
    else
        args="$args CC=$CC"
    fi
fi

args="$args BUILD_SHARED_LIBS=ON"

export ARCH=$ARCH
export ARGS=$args

echo "🤔 $args"

export kernelsu_branch=Stable
export kernelsu_variant=SukiSU

echo "Determine the branch for SukiSU KernelSU"

if [[ "$kernelsu_branch" == "Stable" && ( "$kernelsu_variant" == "SukiSU" ) ]]; then
    export KSU_BRANCH="-s susfs-main"
elif [[ "$kernelsu_branch" == "Dev" && ( "$kernelsu_variant" == "SukiSU" ) ]]; then
    export KSU_BRANCH="-s susfs-test"
fi

echo "Setup KernelSU"
# Delete old KernelSU
if [ -d "./KernelSU" ]; then
    rm -rf "./KernelSU"
fi

if [ -d "./drivers/kernelsu" ]; then
    rm -rf "./drivers/kernelsu"
fi

if [ "$kernelsu_variant" == "Official" ]; then
    echo "Adding KernelSU Official..."
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash $KSU_BRANCH
elif [ "$kernelsu_variant" == "Next" ]; then
    echo "Adding KernelSU Next..."
    curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next-susfs/kernel/setup.sh" | bash $KSU_BRANCH
elif [ "$kernelsu_variant" == "MKSU" ]; then
    echo "Adding KernelSU MKSU..."
    curl -LSs "https://raw.githubusercontent.com/5ec1cff/KernelSU/main/kernel/setup.sh" | bash $KSU_BRANCH
else
    echo "Adding KernelSU SukiSU..."
    curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash $KSU_BRANCH
fi

echo "Setup KSU SUSFS"

cd "$WORKSPACE/$KERNEL_NAME"

if [[ "$ENABLE_KERNELSU" == "true" && "$ENABLE_KERNELSU_SFS" == "true" ]]; then
    if [ "$kernelsu_variant" == "Official" ]; then
        echo "Applying SUSFS patches for Official KernelSU..."
        cp ../susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./
        patch -p1 --forward --fuzz=3 < 10_enable_susfs_for_ksu.patch
    elif [ "$kernelsu_variant" == "Next" ]; then
        echo "Applying SUSFS patches for KernelSU-Next..."
        cp ../kernel_patches/next/scope_min_manual_hooks_v1.5.patch ./
        patch -p1 -F 3 < scope_min_manual_hooks_v1.5.patch
    elif [ "$kernelsu_variant" == "MKSU" ]; then
        echo "Applying SUSFS patches for MKSU..."
        cp ../susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./
        patch -p1 --forward --fuzz=3 < 10_enable_susfs_for_ksu.patch || true

        echo "Applying MKSU specific SUSFS patch..."
        cp ../kernel_patches/mksu/mksu_susfs.patch ./
        patch -p1 < mksu_susfs.patch || true
        cp ../kernel_patches/mksu/fix.patch ./
        patch -p1 < fix.patch || true
    elif [ "$kernelsu_variant" == "SukiSU" ]; then
        echo "Applying SUSFS patches for SukiSU..."
        cp ../susfs4ksu/kernel_patches/50_add_susfs_in_$SUSFS_BRANCH.patch ./
        cp ../susfs4ksu/kernel_patches/fs/* ./fs/
        cp ../susfs4ksu/kernel_patches/include/linux/* ./include/linux/

        patch -p1 < 50_add_susfs_in_$SUSFS_BRANCH.patch || true

        if [ "$HOOK_VARIANT" == "tracepoint" ]; then
            cp ../SukiSU_patch/hooks/sukisu_tracepoint_hooks_v1.1.patch ./
            patch -p1 -F 3 < sukisu_tracepoint_hooks_v1.1.patch
        else
            cp ../SukiSU_patch/hooks/syscall_hooks.patch ./
            patch -p1 -F 3 < syscall_hooks.patch
        fi
    else
        echo "Invalid KernelSU variant selected!"
        exit 1
    fi
fi

export ANYKERNEL3_FILE="$kernelsu_variant-NO-KPM-$HOOK_VARIANT-$KERNEL_NAME-$BUILD_DATE"
export RELEASE_TAG_NAME="$kernelsu_variant-NO-KPM-$HOOK_VARIANT-$KERNEL_NAME-$BUILD_DATE"


echo "Apply Hide Stuff Patches"

# Apply additional patch

if [ "$kernelsu_variant" == "SukiSU" ]; then
    cp ../SukiSU_patch/69_hide_stuff.patch ./
    patch -p1 -F 3 < 69_hide_stuff.patch
else
    cp ../kernel_patches/69_hide_stuff.patch ./
    patch -p1 -F 3 < 69_hide_stuff.patch
fi

# Apply Mountify configuration settings
echo "Adding configuration settings to gki_defconfig..."

# Add KSU configuration settings
echo "CONFIG_OVERLAY_FS=y" >> $CONFIG_FILE

# name: Add SUSFS configuration settings
echo "Adding configuration settings to gki_defconfig..."

# Add KSU configuration settings
echo "CONFIG_KSU=y" >> $CONFIG_FILE

if [ "$kernelsu_variant" == "Next" ]; then
    echo "CONFIG_KSU_KPROBES_HOOK=n" >> $CONFIG_FILE
    echo "CONFIG_KSU_SUSFS_SUS_SU=n" >> $CONFIG_FILE
elif [ "$kernelsu_variant" == "SukiSU" ]; then
    echo "CONFIG_KPM=y" >> $CONFIG_FILE
    echo "CONFIG_KSU_SUSFS_SUS_SU=n" >> $CONFIG_FILE
elif [ "kernelsu_variant" == "MKSU" ]; then
    echo "CONFIG_KSU_SUSFS_SUS_SU=n" >> $CONFIG_FILE
fi

if [ "$HOOK_VARIANT" == "tracepoint" ]; then
    echo "CONFIG_KSU_TRACEPOINT_HOOK=y" >>  $CONFIG_FILE
else
    echo "CONFIG_KSU_MANUAL_HOOK=y" >> $CONFIG_FILE
fi

# Add additional tmpfs config setting
echo "CONFIG_TMPFS_XATTR=y" >> $CONFIG_FILE
echo "CONFIG_TMPFS_POSIX_ACL=y" >> $CONFIG_FILE

# Add additional config setting
echo "CONFIG_IP_NF_TARGET_TTL=y" >> $CONFIG_FILE
echo "CONFIG_IP6_NF_TARGET_HL=y" >> $CONFIG_FILE
echo "CONFIG_IP6_NF_MATCH_HL=y" >> $CONFIG_FILE

# Add BBR Config
echo "CONFIG_TCP_CONG_ADVANCED=y" >> $CONFIG_FILE
echo "CONFIG_TCP_CONG_BBR=y" >> $CONFIG_FILE
echo "CONFIG_NET_SCH_FQ=y" >> $CONFIG_FILE
echo "CONFIG_TCP_CONG_BIC=n" >> $CONFIG_FILE
echo "CONFIG_TCP_CONG_WESTWOOD=n" >> $CONFIG_FILE
echo "CONFIG_TCP_CONG_HTCP=n" >> $CONFIG_FILE

# Add SUSFS configuration settings
echo "CONFIG_KSU_SUSFS=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y" >> $CONFIG_FILE
if [ "$kernel_version" != "6.6" ]; then
    echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> $CONFIG_FILE
else
    echo "CONFIG_KSU_SUSFS_SUS_PATH=n" >> $CONFIG_FILE
fi
echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_SUS_OVERLAYFS=n" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> $CONFIG_FILE
echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> $CONFIG_FILE
echo "CONFIG_KSU_MANUAL_SU=n" >> $CONFIG_FILE

# Remove check_defconfig
sed -i 's/check_defconfig//' ./build.config.gki

sed -i '$s|echo "\$res"|echo "\$res-ab11001737"|' ./scripts/setlocalversion

# 👍 Start building the kernel
cd $WORKSPACE/$KERNEL_NAME

echo "🤔 PATH Variable: $PATH"
export KBUILD_BUILD_TIMESTAMP="Wed Oct 25 05:41:09 UTC 2023"
export KBUILD_BUILD_USER=cuongnguyen

echo "Start to build kernel with following args:\n $ARGS\nDeconfig path:\n$KERNEL_DEFCONFIG_PATH"

CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- AS=clang/bin/llvm-as AR=/home/runner/clang/bin/llvm-ar NM=/home/runner/clang/bin/lvm-nm OBJCOPY=/home/runner/clang/bin/llvm-objcopy OBJDUMP=/home/runner/clang/bin/llvm-objdump STRIP=/home/runner/clang/bin/llvm-strip LD=/home/runner/clang/bin/ld.lld LTO=thin make $ARGS $KERNEL_DEFCONFIG_PATH
CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- AS=clang/bin/llvm-as AR=/home/runner/clang/bin/llvm-ar NM=/home/runner/clang/bin/lvm-nm OBJCOPY=/home/runner/clang/bin/llvm-objcopy OBJDUMP=/home/runner/clang/bin/llvm-objdump STRIP=/home/runner/clang/bin/llvm-strip LD=/home/runner/clang/bin/ld.lld LTO=thin make $ARGS

# name: Apply KPM
cd $OUT_DIR/arch/$ARCH/boot/
if [[ "$use_kpm" == "true" && "$kernelsu_variant" == "SukiSU" && "$android_version" != "6.6" ]]; then
    echo "Start to patch KPM" 
    pwd
    ls -la .
    curl -LSs "https://raw.githubusercontent.com/ShirkNeko/SukiSU_patch/refs/heads/main/kpm/patch_linux" -o patch_linux
    chmod +x patch_linux
    ./patch_linux
    rm -f Image
    mv oImage Image
    export ANYKERNEL3_FILE="$kernelsu_variant-KPM-$HOOK_VARIANT-$KERNEL_NAME-$BUILD_DATE"
    export RELEASE_TAG_NAME="$kernelsu_variant-KPM-$HOOK_VARIANT-$KERNEL_NAME-$BUILD_DATE"
fi

# ⏰ Pack Anykernel3
if [ "$USE_ANYKERNEL3" == "true" ]; then
    git clone --recursive --depth=1 -j $(nproc) https://github.com/WildPlusKernel/AnyKernel3 AnyKernel3
    echo "🤔 Use WildPlus Anykernel3 => (https://github.com/WildPlusKernel/AnyKernel3)"

    if [ -e "$OUT_DIR/arch/$ARCH/boot/Image.gz-dtb" ]; then
        cp -f $OUT_DIR/arch/$ARCH/boot/Image.gz-dtb ./AnyKernel3/
    fi

    if [ -e "$OUT_DIR/arch/$ARCH/boot/Image" ]; then
        cp -f $OUT_DIR/arch/$ARCH/boot/Image ./AnyKernel3/
    fi
    
    if [ -e "$OUT_DIR/arch/$ARCH/boot/dtbo" ]; then
        cp -f $OUT_DIR/arch/$ARCH/boot/dtbo ./AnyKernel3/
    fi

    if [ -e "$OUT_DIR/arch/$ARCH/boot/dtbo.img" ]; then
        cp -f $OUT_DIR/arch/$ARCH/boot/dtbo.img ./AnyKernel3/
    fi

    cd AnyKernel3/
    zip -q -r "$ANYKERNEL3_FILE.zip" *
    echo "Pack anykernel success. \nls -la"
fi