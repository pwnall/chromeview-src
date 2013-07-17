#!/bin/bash
# Push the local source and downloaded build to chromeview.

set -o errexit  # Stop the script on the first error.
set -o nounset  # Catch un-initialized variables.

rm -rf ../chromeview/assets
cp -r build/assets ../chromeview/

rm -rf ../chromeview/libs
cp -r build/libs ../chromeview/libs

rm -rf ../chromeview/res
cp -r build/res ../chromeview/res
cp -r res/* ../chromeview/res/

rm -rf ../chromeview/src
cp -r build/src ../chromeview/src
cp -r src/* ../chromeview/src/
