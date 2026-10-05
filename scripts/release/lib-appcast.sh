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

# Print the body of the "## <version>" section of a CHANGELOG-style markdown file (nothing if the
# version has no section). A file with no "## <version>" headings at all, such as hand-written
# RELEASE_NOTES, is printed whole, minus a leading title line.
changelog_section() {
    local version="$1" file="$2"
    if grep -qE '^## \[?[0-9]' "$file"; then
        awk -v v="$version" '
            /^## / {
                if (inb) exit
                h = $0; sub(/^## \[?/, "", h)
                if (index(h, v) == 1 && substr(h, length(v) + 1) ~ /^(\]|[ \t]|$)/) { inb = 1; next }
            }
            inb { print }
        ' "$file"
    else
        awk 'NR == 1 && /^##? / { next } { print }' "$file"
    fi
}

# Convert the markdown subset used in CHANGELOG.md (### headings, "- " bullets with indented
# continuation lines, **bold**, `code`, paragraphs) to the HTML Sparkle shows in its update dialog.
markdown_to_html() {
    awk '
        function inline(s,    out) {
            gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s)
            out = ""
            while (match(s, /`[^`]+`/)) {
                out = out substr(s, 1, RSTART - 1) "<code>" substr(s, RSTART + 1, RLENGTH - 2) "</code>"
                s = substr(s, RSTART + RLENGTH)
            }
            s = out s; out = ""
            while (match(s, /\*\*[^*]+\*\*/)) {
                out = out substr(s, 1, RSTART - 1) "<b>" substr(s, RSTART + 2, RLENGTH - 4) "</b>"
                s = substr(s, RSTART + RLENGTH)
            }
            return out s
        }
        function flush_item() { if (item != "") { print "<li>" inline(item) "</li>"; item = "" } }
        function close_all() {
            flush_item()
            if (inlist) { print "</ul>"; inlist = 0 }
            if (para != "") { print "<p>" inline(para) "</p>"; para = "" }
        }
        /^[ \t]*$/ { close_all(); next }
        /^#+ / {
            close_all()
            level = index($0, " ") - 1; if (level < 2) level = 2; if (level > 4) level = 4
            text = $0; sub(/^#+ +/, "", text)
            print "<h" level ">" inline(text) "</h" level ">"
            next
        }
        /^[-*] / {
            if (para != "") { print "<p>" inline(para) "</p>"; para = "" }
            flush_item()
            if (!inlist) { print "<ul>"; inlist = 1 }
            item = substr($0, 3)
            next
        }
        {
            line = $0; sub(/^[ \t]+/, "", line)
            if (inlist) item = item " " line
            else para = (para == "" ? line : para " " line)
        }
        END { close_all() }
    '
}

# Write <archive-basename>.html next to an archive named KTStack-<version>[-<arch>].(dmg|zip) so
# generate_appcast embeds it as the item's <description>. Notes come from RELEASE_NOTES if set,
# else the matching CHANGELOG.md section. An existing .html/.md/.txt beside the archive wins.
write_release_notes() {
    local archive="$1" source="$2" stem version html
    stem="${archive%.*}"
    for ext in html md markdown txt; do [[ -f "$stem.$ext" ]] && return 0; done
    version="$(basename "$stem")"; version="${version#*-}"
    version="${version%-arm64}"; version="${version%-x86_64}"; version="${version%-universal}"
    [[ -f "$source" ]] || { echo "release notes: $source not found, $(basename "$archive") ships without notes" >&2; return 0; }
    html="$(changelog_section "$version" "$source" | markdown_to_html)"
    [[ -n "$html" ]] || { echo "release notes: no '## $version' section in $source, $(basename "$archive") ships without notes" >&2; return 0; }
    printf '%s\n' "$html" > "$stem.html"
}
