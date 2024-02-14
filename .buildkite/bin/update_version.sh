#!/bin/bash

set -eu

# $1 iOS SDK Version
# $2 Package.swift file location
# $3 README.md file location

FILE_LOCATION="https://apps.rokt.com/msdk/ios/"$1"/Rokt_Widget.xcframework.zip"
brew install wget
wget "${FILE_LOCATION}"
CHECKSUM=$(swift package compute-checksum Rokt_Widget.xcframework.zip)

perl -pi -e "s/(?<=msdk\/ios\/)(.*)(?=\/Rokt)/$1/g" $2
perl -pi -e "s/(?<=checksum: \")(.*)(?=\")/$CHECKSUM/g" $2
perl -pi -e "s/(?<=Select \*Up to Next Major\* with \*)(.*)(?=\*)/$1/g" $3
perl -pi -e "s/(?<=upToNextMajor\(from: \")(.*)(?=\")/$1/g" $3

rm -f Rokt_Widget.xcframework.zip