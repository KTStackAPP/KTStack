import Foundation

extension DumpService {
    static func dumpArguments(defaultsPath: String, database: String, table: String?, isMariaDB: Bool) -> [String] {
        var args = ["--defaults-extra-file=\(defaultsPath)", "--single-transaction"]
        if table == nil { args += ["--routines", "--events"] }
        args.append("--triggers")
        if !isMariaDB { args.append("--set-gtid-purged=OFF") }
        args += ["--", database]
        if let table { args.append(table) }
        return args
    }
}
