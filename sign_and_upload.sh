#!/bin/bash

set -o errexit

# [[ $BUILD_STYLE = Release ]] || { echo Distribution target requires "'Release'" build style exit 0; }

VERSION=$(defaults read "$BUILT_PRODUCTS_DIR/$PROJECT_NAME.app/Contents/Info" CFBundleVersion)
DOWNLOAD_BASE_URL="http:/www.syxra.cz/osx/download"
RELEASENOTES_URL="http://www.syxra.cz/osx/release-notes.html#version-$VERSION"

ARCHIVE_FILENAME="$PROJECT_NAME$VERSION.zip"
DOWNLOAD_URL="$DOWNLOAD_BASE_URL/$ARCHIVE_FILENAME"
KEYCHAIN_PRIVKEY_NAME="/Users/sychram/Desktop/Dropbox/Developer/_Sparkle_DSA_Keys/dsa_priv.pem"
WD=$PWD
cd "$BUILT_PRODUCTS_DIR"
rm -f "$PROJECT_NAME"*.zip
ditto -ck --keepParent "$PROJECT_NAME.app" "$ARCHIVE_FILENAME"

SIZE=$(stat -f %z "$ARCHIVE_FILENAME")
PUBDATE=$(date +"%a, %d %b %G %T %z")
SIGNATURE=$(
    openssl dgst -sha1 -binary < "$ARCHIVE_FILENAME" \
    | openssl dgst -dss1 -sign <(security find-generic-password -g -s "$KEYCHAIN_PRIVKEY_NAME" 2>&1 1>/dev/null | perl -pe '($_) = /"(.+)"/; s/\\012/\n/g' | perl -MXML::LibXML -e 'print XML::LibXML->new()->parse_file("-")->findvalue(q(//string[preceding-sibling::key[1] = "NOTE"]))') \
    | openssl enc -base64
)

[ $SIGNATURE ] || { echo Unable to load signing private key with name "'$KEYCHAIN_PRIVKEY_NAME'" from keychain; false; }

cat <<EOF
<item>
<title>Version $VERSION</title>
<sparkle:releaseNotesLink>$RELEASENOTES_URL</sparkle:releaseNotesLink>
<pubDate>$PUBDATE</pubDate>
<enclosure
url="$DOWNLOAD_URL"
sparkle:version="$VERSION"
type="application/octet-stream"
length="$SIZE"
sparkle:dsaSignature="$SIGNATURE"
/>
</item>
EOF

echo $HOME
echo scp "'$HOME/code/Shady/build/Release/$ARCHIVE_FILENAME'" www.syxra.cz:osx/
echo scp "'$WD/appcast.xml'" www.syxra.cz:osx/dbrdlzr.xml