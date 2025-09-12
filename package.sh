#!/bin/sh

# Check if the variable $tintedmacbuildfolder is set and not empty
if [ -z "$tintedmacbuildfolder" ]; then
    # Check if build directory exists in the current directory
    if [ -d "./build/" ]; then
        # Set $tintedmacbuildfolder to the current directory
        tintedmacbuildfolder=$(pwd)
    else
        # Ask the user to enter the build directory's path
        echo "Please enter the build directory's path:"
        read tintedmacbuildfolder
    fi
fi

# Create a temporary directory and copy TintedMacInject.bundle into it
mkdir $tintedmacbuildfolder/temp
cp $tintedmacbuildfolder/build/Debug/TintedMacInject.bundle/Contents/MacOS/TintedMacInject $tintedmacbuildfolder/temp/TintedMacInject.dylib
cp $tintedmacbuildfolder/Resources/TintedMacInject.dylib.blacklist $tintedmacbuildfolder/temp/ 2>/dev/null || echo "No blacklist file found, skipping..."

# Build the package
sudo pkgbuild --install-location /usr/local/bin/ammonia/tweaks/ --root $tintedmacbuildfolder/temp --identifier net.tintedmac.injection "$tintedmacbuildfolder/tintedmac.pkg"

# Clean up
rm -rf $tintedmacbuildfolder/temp

echo "Package created: $tintedmacbuildfolder/tintedmac.pkg"
