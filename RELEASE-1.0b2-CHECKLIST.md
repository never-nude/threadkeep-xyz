# ThreadKeep 1.0 beta 2 — finish the release (run on the Mac with the Developer ID certificate)

Everything below is mechanical. The app code, release pipeline, and site copy are
done; this machine only signs, notarizes, and fills in the two values that depend
on the final artifact.

## 0. One-time machine setup (skip if already done)

- Confirm the signing identity exists:
  `security find-identity -v -p codesigning | grep "Developer ID Application"`
  (expects: Developer ID Application: Michael Kushman (QHUS8AZVD4))
- Store notary credentials (prompts for an app-specific password from
  account.apple.com → Sign-In and Security → App-Specific Passwords):
  `xcrun notarytool store-credentials threadkeep-notary --apple-id michael.kushman@gmail.com --team-id QHUS8AZVD4`

## 1. Build + notarize the app

```sh
git clone https://github.com/never-nude/ThreadKeep.git && cd ThreadKeep   # or: git fetch
git checkout fix/migration-content-key-hazard    # release commit: 863160e
./scripts/build-notarized-dmg.sh                 # builds, signs, notarizes, staples, verifies
```

The script ends with `spctl -a -vv` reporting `accepted · Notarized Developer ID`
and produces `dist/ThreadKeep-1.0b2.dmg`. If anything fails it exits non-zero.

## 2. Publish the DMG + finalize site copy

In this repo (threadkeep-xyz), on THIS branch (`release/1.0b2`):

```sh
cp ../ThreadKeep/dist/ThreadKeep-1.0b2.dmg downloads/
SIZE_MB=$(ls -l downloads/ThreadKeep-1.0b2.dmg | awk '{printf "%.1f", $5/1048576}')
SHA256=$(shasum -a 256 downloads/ThreadKeep-1.0b2.dmg | awk '{print $1}')
sed -i '' "s/{{DMG_SIZE_MB}}/$SIZE_MB/g; s/{{DMG_SHA256}}/$SHA256/g" index.html
grep -c "{{" index.html   # MUST print 0
```

Keep `downloads/ThreadKeep-1.0b1.dmg` in place (existing links stay valid).

## 3. Ship

```sh
git add downloads/ThreadKeep-1.0b2.dmg index.html
git rm RELEASE-1.0b2-CHECKLIST.md
git commit -m "Ship ThreadKeep 1.0 beta 2 (identity-keyed dedup + safe migrations)"
git checkout main && git merge --ff-only release/1.0b2 && git push origin main
```

## 4. Verify live (Pages deploys in ~1 minute)

```sh
curl -sI https://threadkeep.xyz/downloads/ThreadKeep-1.0b2.dmg | head -3   # expect 200
curl -s https://threadkeep.xyz/ | grep -o "1.0 beta 2"                     # expect a match
```

Optionally download the live DMG, mount, and `spctl -a -vv ThreadKeep.app`
(expect `accepted · Notarized Developer ID`).

## Context (why this release)

Beta 2 = branch `fix/migration-content-key-hazard` @ 863160e, containing:
- e971f42 — dedup by source identity only (guid → rowid → id); look-alike
  messages are never silently merged.
- d371afd — duplicate-cleanup migration made structurally safe: identity-keyed,
  per-thread, versioned inside the database (PRAGMA user_version), plus
  downgrade tombstones.
- 863160e — distribution plist metadata (CFBundleVersion 2) + this pipeline.

The site claims "signed & notarized" — do not publish this branch to main until
step 1 has actually produced a notarized DMG and step 2 has replaced both
placeholders.
