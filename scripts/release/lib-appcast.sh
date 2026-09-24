#!/usr/bin/env bash
# Sparkle only offers an item to Macs that satisfy <sparkle:hardwareRequirements>; tag every
# -arm64 enclosure so Intel Macs never receive the Apple-silicon build. Idempotent.
tag_arm64_items() {
    local appcast="$1" tmp
    tmp="$(mktemp)"
    awk '
        /<item>/ { inb = 1; blk = "" }
        inb {
            blk = blk $0 "\n"
            if ($0 ~ /<\/item>/) {
                inb = 0
                if (blk ~ /url="[^"]*-arm64\.(dmg|zip)"/ && blk !~ /hardwareRequirements/) {
                    sub(/[ \t]*<\/item>\n$/, "            <sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>\n        </item>\n", blk)
                }
                printf "%s", blk
            }
            next
        }
        { print }
    ' "$appcast" > "$tmp"
    mv "$tmp" "$appcast"
}
