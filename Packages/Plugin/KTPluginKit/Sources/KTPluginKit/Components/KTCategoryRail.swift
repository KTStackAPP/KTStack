import SwiftUI

public struct KTCategoryRailItem<ID: Hashable>: Identifiable {
    public let id: ID
    public let title: String
    public let summary: String
    public let systemImage: String
    public let tint: KTTint
    public var dot: Color?

    public init(
        id: ID,
        title: String,
        summary: String,
        systemImage: String,
        tint: KTTint,
        dot: Color? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.systemImage = systemImage
        self.tint = tint
        self.dot = dot
    }
}

public struct KTCategoryRailSection<ID: Hashable>: Identifiable {
    public let id: String
    public let items: [KTCategoryRailItem<ID>]

    public init(id: String, items: [KTCategoryRailItem<ID>]) {
        self.id = id
        self.items = items
    }
}

/// Rail danh mục cho màn nhiều category (Runtimes, tái dùng được cho Services/Database).
public struct KTCategoryRail<ID: Hashable>: View {
    private let sections: [KTCategoryRailSection<ID>]
    @Binding private var selection: ID
    private let compact: Bool

    public init(sections: [KTCategoryRailSection<ID>], selection: Binding<ID>, compact: Bool) {
        self.sections = sections
        _selection = selection
        self.compact = compact
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 14) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 4) {
                    if !compact {
                        Text(section.id)
                            .font(KTType.sectionLabel).tracking(KTType.sectionLabelTracking)
                            .foregroundStyle(KTColor.faint)
                            .padding(.leading, 10).padding(.top, 2)
                    }
                    ForEach(section.items) { item in
                        row(item)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, compact ? 0 : 10)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func row(_ item: KTCategoryRailItem<ID>) -> some View {
        let isSelected = item.id == selection
        Button {
            selection = item.id
        } label: {
            if compact {
                compactRow(item, isSelected: isSelected)
            } else {
                fullRow(item, isSelected: isSelected)
            }
        }
        .buttonStyle(.plain)
        .help(compact ? "\(item.title) · \(item.summary)" : "")
    }

    private func tile(_ item: KTCategoryRailItem<ID>) -> some View {
        KTIconTile(tint: item.tint, size: 22, radius: 7) {
            Image(systemName: item.systemImage).font(.system(size: 12, weight: .medium))
        }
    }

    private func fullRow(_ item: KTCategoryRailItem<ID>, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            tile(item)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.jbMono(12, .medium))
                    .foregroundStyle(isSelected ? KTColor.accent : KTColor.ink)
                Text(item.summary)
                    .font(KTType.caption)
                    .foregroundStyle(isSelected ? KTColor.accent : KTColor.muted)
                    .lineLimit(1).truncationMode(.tail)
            }
            Spacer(minLength: 4)
            if let dot = item.dot {
                KTDot(color: dot, size: 6)
            }
        }
        .padding(.vertical, 7).padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: KTRadius.buttonSmall, style: .continuous)
                .fill(isSelected ? KTColor.accentSoft : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private func compactRow(_ item: KTCategoryRailItem<ID>, isSelected: Bool) -> some View {
        tile(item)
            .overlay(alignment: .topTrailing) {
                if let dot = item.dot {
                    KTDot(color: dot, size: 6).offset(x: 2, y: -2)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: KTRadius.buttonSmall, style: .continuous)
                    .fill(isSelected ? KTColor.accentSoft : Color.clear)
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
    }
}

#if DEBUG
    private enum PreviewCategory: Hashable { case php, node, mysql }

    #Preview {
        struct Wrap: View {
            @State private var sel: PreviewCategory = .php
            var body: some View {
                HStack(spacing: 0) {
                    KTCategoryRail(
                        sections: [
                            KTCategoryRailSection(id: "LANGUAGES", items: [
                                KTCategoryRailItem(
                                    id: .php, title: "PHP", summary: "7 installed · 8.5 default",
                                    systemImage: "chevron.left.forwardslash.chevron.right", tint: KTIconTint.php
                                ),
                                KTCategoryRailItem(
                                    id: .node, title: "Node", summary: "2 installed · 24 default",
                                    systemImage: "shippingbox", tint: KTIconTint.cube
                                ),
                            ]),
                            KTCategoryRailSection(id: "DATABASES & CACHE", items: [
                                KTCategoryRailItem(
                                    id: .mysql, title: "MySQL", summary: "8.4 active",
                                    systemImage: "cylinder.split.1x2", tint: KTIconTint.db, dot: KTColor.runDot
                                ),
                            ]),
                        ],
                        selection: $sel,
                        compact: false
                    )
                    .frame(width: 180)
                    Divider()
                    Spacer()
                }
                .frame(width: 520, height: 360)
            }
        }
        return Wrap()
    }
#endif
