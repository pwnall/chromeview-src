#!/bin/bash
# Builds the Chromium bits needed by ChromeView.

set -o errexit  # Stop the script on the first error.
set -o nounset  # Catch un-initialized variables.


# Build Chromium.
# https://code.google.com/p/chromium/wiki/UsingGit
if [ ! -z GCLIENT_SYNC ] ; then
  cd ~/chromium/
  # Syncing twice because of crbugs.com/237234
  gclient sync --jobs 16 --reset --delete_unversioned_trees
  gclient sync --jobs 16 --reset --delete_unversioned_trees
fi

cd ~/chromium/src
echo "Building $(git rev-parse HEAD)"

CPUS=$(grep -c 'processor' /proc/cpuinfo)

if [ -f ~/.build_arm ] ; then
  set +o nounset  # Chromium scripts are messy.
  source build/android/envsetup.sh --target-arch=arm
  set -o nounset  # Catch un-initialized variables.
  android_gyp
  ninja -C out/Release -k0 -j$CPUS libwebviewchromium android_webview_apk \
      content_shell_apk chromium_testshell
fi

if [ -f ~/.build_x86 ] ; then
  set +o nounset  # Chromium scripts are messy.
  source build/android/envsetup.sh --target-arch=x86
  set -o nounset  # Catch un-initialized variables.
  android_gyp
  ninja -C out/Release -k0 -j$CPUS libwebviewchromium android_webview_apk \
      content_shell_apk chromium_testshell
fi


# Package the build.
cd ~/chromium/src
REV=$(git rev-parse HEAD)
rm -rf ~/crbuilds/$REV
mkdir -p ~/crbuilds/$REV

# Structure.
mkdir -p ~/crbuilds/$REV/assets
mkdir -p ~/crbuilds/$REV/libs
mkdir -p ~/crbuilds/$REV/res
mkdir -p ~/crbuilds/$REV/src


# ContentShell core -- use this if android_webview doesn't work out.
#scp out/Release/content_shell/assets/* assets/
#scp -r out/Release/content_shell_apk/libs/* libs/
#scp -r content/shell/android/java/res/* ~/crbuilds/$REV/res/
#scp -r content/shell/android/java/src/* ~/crbuilds/$REV/src/
#scp -r content/shell_apk/android/java/res/* ~/crbuilds/$REV/res/

# android_webview
cp out/Release/android_webview_apk/assets/*.pak ~/crbuilds/$REV/assets/
cp -r out/Release/android_webview_apk/libs/* ~/crbuilds/$REV/libs/
rm ~/crbuilds/$REV/libs/**/gdbserver
cp -r android_webview/java/src/* ~/crbuilds/$REV/src/

## Dependencies inferred from android_webview/Android.mk

# Resources.
cp -r content/public/android/java/resource_map/* ~/crbuilds/$REV/src/
cp -r ui/android/java/resource_map/* ~/crbuilds/$REV/src/

# ContentView dependencies.
cp -r base/android/java/src/* ~/crbuilds/$REV/src/
cp -r content/public/android/java/src/* ~/crbuilds/$REV/src/
cp -r media/base/android/java/src/* ~/crbuilds/$REV/src/
cp -r net/android/java/src/* ~/crbuilds/$REV/src/
cp -r ui/android/java/src/* ~/crbuilds/$REV/src/
cp -r third_party/eyesfree/src/android/java/src/* ~/crbuilds/$REV/src/

# Strip a ContentView file that's not supposed to be here.
rm ~/crbuilds/$REV/src/org/chromium/content/common/common.aidl

# Get rid of the version control directory in eyesfree.
rm -rf ~/crbuilds/$REV/src/com/googlecode/eyesfree/braille/.svn
rm -rf ~/crbuilds/$REV/src/com/googlecode/eyesfree/braille/.git

# Browser components.
cp -r components/web_contents_delegate_android/android/java/src/* \
      ~/crbuilds/$REV/src/
cp -r components/navigation_interception/android/java/src/* \
      ~/crbuilds/$REV/src/

# Generated files.
cp -r out/Release/gen/templates/* ~/crbuilds/$REV/src/

# JARs.
cp -r out/Release/lib.java/guava_javalib.jar ~/crbuilds/$REV/libs/
cp -r out/Release/lib.java/jsr_305_javalib.jar ~/crbuilds/$REV/libs/

# android_webview generated sources. Must come after all the other sources.
cp -r android_webview/java/generated_src/* ~/crbuilds/$REV/src/

# Archive.
ARCHIVE="$REV"
if [ -f ~/.build-arm ] ; then
  ARCHIVE="$ARCHIVE-arm"
fi
if [ -f ~/.build-x86 ] ; then
  ARCHIVE="$ARCHIVE-x86"
fi
cd ~/crbuilds/$REV
tar -czvf "../$ARCHIVE.tar.gz" .
