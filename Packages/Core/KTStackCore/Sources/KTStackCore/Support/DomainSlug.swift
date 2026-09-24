import Foundation

// Chuẩn hóa tên folder thành slug domain; shared vì SiteInspector + *SiteSource cùng dùng.
public enum DomainSlug {
    public static func make(_ raw: String) -> String {
        let lowered = ascii(raw).lowercased()
        var out = ""
        var lastHyphen = false
        for ch in lowered {
            if ch.isASCII, ch.isLetter || ch.isNumber {
                out.append(ch); lastHyphen = false
            } else if !lastHyphen {
                out.append("-"); lastHyphen = true
            }
        }
        let trimmed = out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "site" : trimmed
    }

    static func ascii(_ raw: String) -> String {
        let latin = raw.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "D")
        let transliterated = latin.applyingTransform(.toLatin, reverse: false) ?? latin
        return transliterated.applyingTransform(.stripDiacritics, reverse: false) ?? transliterated
    }
}
