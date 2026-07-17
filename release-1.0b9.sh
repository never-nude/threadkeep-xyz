#!/bin/bash
# One-shot release of ThreadKeep 1.0b9 to threadkeep.xyz.
# Run from anywhere on the cert machine: bash release-1.0b9.sh
set -euo pipefail

SITE="$HOME/threadkeep-xyz"
DMG_SRC="$HOME/ThreadKeep/dist/ThreadKeep-1.0b2.dmg"
SIGN_TOOL="$HOME/Library/Caches/ThreadKeepBuild/swiftpm-notarized/artifacts/sparkle/Sparkle/bin/sign_update"

cd "$SITE"
git pull

if grep -q "ThreadKeep-1.0b9.dmg" appcast.xml; then
  echo "appcast already lists 1.0b9 — nothing to do. (Is it already released?)"
  exit 0
fi

echo "==> Copying DMG into the site"
cp "$DMG_SRC" downloads/ThreadKeep-1.0b9.dmg

echo "==> Signing for Sparkle"
SIGLINE=$("$SIGN_TOOL" downloads/ThreadKeep-1.0b9.dmg)

echo "==> Updating appcast.xml"
python3 - "$SIGLINE" <<'PY'
import re, sys, os, email.utils
sig = re.search(r'sparkle:edSignature="([^"]+)"', sys.argv[1]).group(1)
length = os.path.getsize("downloads/ThreadKeep-1.0b9.dmg")
item = f'''    <item>
      <title>ThreadKeep 1.0b9</title>
      <pubDate>{email.utils.formatdate(localtime=True)}</pubDate>
      <sparkle:version>9</sparkle:version>
      <sparkle:shortVersionString>1.0b9</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
        <h2>What's new in 1.0b9</h2>
        <ul>
          <li>Send your entire library — or a single conversation — to ThreadKeep for iPhone over Wi-Fi: pair with a 4-digit code, watch live progress, done.</li>
          <li>New welcome screen with clearer choices, and a QR code to grab the iPhone app.</li>
        </ul>
      ]]></description>
      <enclosure
        url="https://threadkeep.xyz/downloads/ThreadKeep-1.0b9.dmg"
        length="{length}"
        type="application/octet-stream"
        sparkle:edSignature="{sig}" />
    </item>

'''
s = open("appcast.xml").read()
open("appcast.xml", "w").write(s.replace("    <item>", item + "    <item>", 1))
print("appcast: 1.0b9 entry added")
PY

echo "==> Pointing the download button at 1.0b9"
sed -i '' 's/ThreadKeep-1.0b8.dmg/ThreadKeep-1.0b9.dmg/g' index.html

echo "==> Publishing"
git add -A
git commit -m "Release ThreadKeep 1.0b9 (iPhone Wi-Fi sync)"
git push origin main

echo "==> Recording 1.0b9 as shipped in the app repo"
cd "$HOME/ThreadKeep"
sed -i '' 's/:-8}/:-9}/' scripts/build-notarized-dmg.sh
git add scripts/build-notarized-dmg.sh
git commit -m "Record 1.0b9 as last shipped (bundle version 9)"
git push origin claude/iphone-wifi-sync

echo ""
echo "DONE — 1.0b9 is live: https://threadkeep.xyz/downloads/ThreadKeep-1.0b9.dmg"
