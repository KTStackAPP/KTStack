import Foundation

extension BackupPlan {
    enum CodingKeys: String, CodingKey {
        case id, name, isEnabled, enabledAt, schedule, keepLast, databases, includeSites
        case siteIDs, siteExcludes, includeSettings, destinationID, keepLocalCopy, skipOnBattery
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decodeIfPresent(String.self, forKey: .name) ?? "Backup",
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false,
            enabledAt: try container.decodeIfPresent(Date.self, forKey: .enabledAt),
            schedule: try container.decodeIfPresent(BackupSchedule.self, forKey: .schedule) ?? .nightly,
            keepLast: try container.decodeIfPresent(Int.self, forKey: .keepLast) ?? BackupPlan.defaultKeepLast,
            databases: try container.decodeIfPresent([BackupDatabaseSelection].self, forKey: .databases) ?? [],
            includeSites: try container.decodeIfPresent(Bool.self, forKey: .includeSites) ?? false,
            siteIDs: try container.decodeIfPresent([UUID].self, forKey: .siteIDs) ?? [],
            siteExcludes: try container.decodeIfPresent([String].self, forKey: .siteExcludes) ?? SiteExcludeDefaults.patterns,
            includeSettings: try container.decodeIfPresent(Bool.self, forKey: .includeSettings) ?? false,
            destinationID: try container.decodeIfPresent(UUID.self, forKey: .destinationID),
            keepLocalCopy: try container.decodeIfPresent(Bool.self, forKey: .keepLocalCopy) ?? false,
            skipOnBattery: try container.decodeIfPresent(Bool.self, forKey: .skipOnBattery) ?? false
        )
    }
}
