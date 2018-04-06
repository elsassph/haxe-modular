#!/bin/sh
set -e

VERSION=$1

# Validate version
if [ -z "$VERSION" ]; then
    echo "No version specified"
    exit 1
fi
if [ $(git tag -l "$VERSION") ]; then
    echo "Tag $VERSION already exists"
    exit 1
fi

# Change version in haxelib.json and package.json
echo "Update version to $VERSION"
PATTERN="s/\"version\": \"[0-9]+.[0-9]+.[0-9]+\"/\"version\": \"$VERSION\"/g"

case "$(uname -s)" in
   Darwin)
     sed -E -i "" "$PATTERN" ./haxelib.json
     sed -E -i "" "$PATTERN" ./package.json
     ;;
   *)
     sed -E -i "$PATTERN" ./haxelib.json
     sed -E -i "$PATTERN" ./package.json
     ;;
esac

# Tag, commit and push to trigger a new CI release
git tag $VERSION
git commit -am "Release version $VERSION"
git push --follow-tags
