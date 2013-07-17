#!/bin/bash
# Download the latest build from build bots.

set -o errexit  # Stop the script on the first error.
set -o nounset  # Catch un-initialized variables.

# Load the configuration.
if [ ! -f config/buildvms.sh ] ; then
  cp config/buildvms.sh.template config/buildvms.sh
  echo "Edit config/buildvms.sh and run this script again."
  exit 1
fi
. config/buildvms.sh

# Get the latest revision from the ARM bot.
REV=$(curl -fLsS $ARM_BUILDVM/LATEST_REV)

# Download the arm and x86 packages.
rm -rf build
mkdir -p build
echo -n "Downloading ARM build... "
curl -fLsS $ARM_BUILDVM/archives/$REV-arm.tar.gz -o build/arm-build.tar.gz
echo "done"
echo -n "Downloading X86 build... "
curl -fLsS $X86_BUILDVM/archives/$REV-x86.tar.gz -o build/x86-build.tar.gz
echo "done"

# Unpack the packages.
echo Unpacking build.
cd build
tar -xzf x86-build.tar.gz
tar -xzf arm-build.tar.gz
cd ..

# Remove the archives.
rm build/arm-build.tar.gz
rm build/x86-build.tar.gz
