#!/bin/bash

set -e

ODIN_ROOT=$(odin root)
ODIN_ANDROID_NDK=${ANDROID_NDK_HOME}
ANDROID_OUT_DIR="$(pwd)/build/apk/lib/lib/arm64-v8a"

android_platform="android-31"

rm -rf ./build/android/apk

mkdir -p ${ANDROID_OUT_DIR}
export ODIN_ANDROID_SDK=${ANDROID_HOME}
export ODIN_ANDROID_NDK=${ANDROID_NDK_HOME}

if [ ! -f build/.keystore ]; then
	keytool -genkey -dname "CN=Android Debug, O=Android, C=US" -keystore build/.keystore -alias androiddebugkey -storepass android -keypass android -keyalg RSA -validity 30000
fi


# echo "Building shared lib..."
# odin build android -out:${ANDROID_OUT_DIR}/libandroid_odin.so \
#   -debug \
#   -collection:karl2d=$(pwd)/karl2d \
#   -target:linux_arm64 -subtarget:android -build-mode:shared \
#   -print-linker-flags=""
echo "Building object lib..."
odin build . -out:${ANDROID_OUT_DIR}/libmain.o \
  -debug \
  -collection:karl2d=../.. \
  -target:linux_arm64 -subtarget:android -build-mode=object 

# Compile native app glue
${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang \
  --target=aarch64-linux-android34 \
  -c "${ANDROID_NDK_HOME}/sources/android/native_app_glue/android_native_app_glue.c" \
  -o "/tmp/android_native_app_glue.o" \
  --sysroot "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot" \
  "-I${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/" \
  "-I${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/aarch64-linux-android/" \
  -Wno-macro-redefined
${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "${ANDROID_OUT_DIR}/android_native_app_glue.a" "/tmp/android_native_app_glue.o"

# Compile stb_truetype
${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang \
  --target=aarch64-linux-android34 \
  -c "${ODIN_ROOT}/vendor/stb/src/stb_truetype.c" \
  -o "/tmp/stb_trutype.o" \
  --sysroot "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot" "-I${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/" "-I${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/aarch64-linux-android/" \
  -Wno-macro-redefined
${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar rcs "${ANDROID_OUT_DIR}/stb_trutype.a" "/tmp/stb_trutype.o"


#Produce final object
${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang \
    --target=aarch64-linux-android34 \
    -Wno-unused-command-line-argument \
    "${ANDROID_OUT_DIR}/android_native_app_glue.a" \
    "${ANDROID_OUT_DIR}"/libmain-*.o \
    -o "${ANDROID_OUT_DIR}"/libmain.so \
    "-L${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/34/" \
    -landroid -llog \
    "--sysroot=${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/" \
    -L/ -landroid -laaudio -lEGL -l:"${ANDROID_OUT_DIR}/stb_trutype.a"  -lm -lc  -shared -Wl,-init,'main' -u ANativeActivity_onCreate
    # -L/ -landroid -lEGL -l:"${ANDROID_OUT_DIR}/stb_trutype.a"  -lm -lc  -shared -Wl,-init,'main' -Wl,-fini,'_odin_exit_point' -u ANativeActivity_onCreate
#
#
echo "Clean tempfiles..."
rm ${ANDROID_OUT_DIR}/*.{o,a}

echo "Bundle.."
cp ./AndroidManifest.xml ./build/apk/
odin bundle android ./build/apk -android-keystore:./build/.keystore -android-keystore-password:android
mv test.apk build//app.apk
mv test.apk-build build/app.apk-build
mv test.apk.idsig build/app.apk.idsig
