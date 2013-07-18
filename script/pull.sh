#!/bin/bash
# Copies the glue code from the chromeview sibling directory.

set -o errexit  # Stop the script on the first error.
set -o nounset  # Catch un-initialized variables.

rm -rf src/
mkdir -p src/
cp -r ../chromeview/src/us src/

rm -rf res/
mkdir -p res
cp -r ../chromeview/res/raw res/
mkdir -p res/values
cp -r ../chromeview/res/values/strings.xml res/values/
