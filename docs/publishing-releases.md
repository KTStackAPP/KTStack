# Release Process

Every release follows these rules. They are mandatory: Sparkle auto-update reads the appcast this process produces, and a wrong appcast reaches every installed copy.

## Rules

1. **Every release has a full CHANGELOG section.** `CHANGELOG.md` must carry `## <version> - <date>` with every user-visible change since the previous tag, grouped under `### Added`, `### Changed`, `### Fixed`. Check `git log --first-parent v<previous>..main` so no merged PR is missing.
2. **The appcast embeds that section as release notes.** `scripts/release/update-appcast.sh` converts the matching CHANGELOG section to HTML and writes it into each `<item>` as `<description>`, which is what the Sparkle update dialog shows. If a DMG has no matching section, the script fails and writes no appcast. Never ship an appcast without notes, and never bypass the check.
3. **Version bump in one commit.** Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` (+1) in `project.yml` and rename `## Unreleased` to the version heading in the same commit: `chore(release): bump version to <ver> (build <n>)`.
4. **Two per-arch DMGs, one appcast.** Build `DMG_ARCH=arm64` and `DMG_ARCH=x86_64` with `scripts/release/build-signed-dmg-complete.sh` (signs, notarizes, staples, smoke tests). Put both `KTStack-<ver>-<arch>.dmg` in one directory and run `DOWNLOAD_URL_PREFIX="https://github.com/KTStackAPP/KTStack/releases/download/v<ver>/" scripts/release/update-appcast.sh <dir>`.
5. **Publish both DMGs and `appcast.xml` on the `v<ver>` GitHub Release**, with the same CHANGELOG section as the release body. The app reads `releases/latest/download/appcast.xml`, so the release must be marked latest.
6. **Verify before announcing.** Download the published `appcast.xml` and confirm it has two items, each with a `<description>`, the arm64 item tagged `sparkle:hardwareRequirements`, and both enclosure URLs resolving.

## Steps

```bash
# 1. bump (rule 3), commit, push to main
xcodegen generate

# 2. build both DMGs
DMG_ARCH=arm64  scripts/release/build-signed-dmg-complete.sh
DMG_ARCH=x86_64 scripts/release/build-signed-dmg-complete.sh

# 3. appcast with release notes (fails without a CHANGELOG section)
mkdir -p dist/v0.3.6 && mv KTStack-0.3.6-*.dmg dist/v0.3.6/
DOWNLOAD_URL_PREFIX="https://github.com/KTStackAPP/KTStack/releases/download/v0.3.6/" \
  scripts/release/update-appcast.sh dist/v0.3.6

# 4. publish
gh release create v0.3.6 dist/v0.3.6/*.dmg dist/v0.3.6/appcast.xml \
  --title "KTStack 0.3.6" --notes-file <changelog section> --latest
```

`scripts/release/tests/test-update-appcast.sh` runs in the local gate and covers rule 2.
