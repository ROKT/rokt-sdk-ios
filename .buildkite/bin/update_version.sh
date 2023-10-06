#!/bin/bash

set -eu

# $1 iOS SDK Version
# $2 Package.swift file location
# $3 README.md file location

FILE_LOCATION="https://rokt-eng-us-west-2-mobile-sdk-artefacts.s3.amazonaws.com/ios/"$1"/Rokt_Widget.xcframework.zip"
wget "${FILE_LOCATION}"
CHECKSUM=$(swift package compute-checksum Rokt_Widget.xcframework.zip)

perl -pi -e "s/(?<=amazonaws.com\/ios\/)(.*)(?=\/Rokt)/$1/g" $2
perl -pi -e "s/(?<=checksum: \")(.*)(?=\")/$CHECKSUM/g" $2
perl -pi -e "s/(?<=Select \*Up to Next Major\* with \*)(.*)(?=\*)/$1/g" $3
perl -pi -e "s/(?<=upToNextMajor\(from: \")(.*)(?=\")/$1/g" $3

rm -f Rokt_Widget.xcframework.zip