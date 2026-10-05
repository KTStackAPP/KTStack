import Foundation

enum BackupFormatting {
    static func schedule(_ schedule: BackupSchedule) -> String {
        let time = String(format: "%02d:%02d", schedule.hour, schedule.minute)
        switch schedule.frequency {
        case .daily: return "Daily at \(time)"
        case .weekly: return "\(weekdayName(schedule.weekday))s at \(time)"
        }
    }

    static func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.autoupdatingCurrent.weekdaySymbols
        return symbols[(max(1, min(7, weekday)) - 1) % symbols.count]
    }

    static func relative(_ date: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func contents(_ plan: BackupPlan) -> String {
        var parts: [String] = []
        if !plan.databases.isEmpty { parts.append(plan.databases.count == 1 ? "1 database" : "\(plan.databases.count) databases") }
        if plan.includeSites, !plan.siteIDs.isEmpty { parts.append(plan.siteIDs.count == 1 ? "1 site" : "\(plan.siteIDs.count) sites") }
        if plan.includeSettings { parts.append("settings") }
        return parts.isEmpty ? "Nothing selected" : parts.joined(separator: ", ")
    }

    static func status(_ run: BackupRun) -> String {
        let when = relative(run.finishedAt ?? run.startedAt)
        switch run.status {
        case .running: return "Running since \(when)"
        case .succeeded: return "Last backup \(when)\(run.sizeBytes.map { " · \(size($0))" } ?? "")"
        case .partial: return "Partly failed \(when)"
        case .failed: return "Failed \(when): \(run.message ?? "unknown error")"
        case .skipped: return "Skipped \(when): \(run.skipReason?.message ?? run.message ?? "")"
        }
    }

    static func phase(_ phase: BackupRunPhase) -> String {
        switch phase {
        case .staging: "Preparing backup…"
        case let .uploading(fraction): "Uploading \(Int((fraction * 100).rounded()))%…"
        case .cleaningUp: "Applying retention…"
        }
    }

    static func destinationName(_ id: UUID?, in state: BackupState) -> String {
        guard let id else { return "This Mac" }
        return state.destination(id)?.name ?? "Missing destination"
    }
}
