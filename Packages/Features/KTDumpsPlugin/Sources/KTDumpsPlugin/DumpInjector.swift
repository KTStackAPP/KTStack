import Foundation
import KTPlatformContracts
import KTStackCore

// Ghi prepend file trong app-support và bật/tắt auto_prepend qua platform (PHPRuntimeConfiguring).
final class DumpInjector: Sendable {
    private let paths: AppSupportPaths
    private let php: any PHPRuntimeConfiguring

    init(paths: AppSupportPaths = AppSupportPaths(), php: any PHPRuntimeConfiguring) {
        self.paths = paths
        self.php = php
    }

    func enable(version: String, port: UInt16) throws {
        try writePrependFile(port: port)
        try php.setAutoPrepend(file: paths.dumpsPrependFile.path, version: version)
    }

    func disable(version: String) throws {
        try php.removeAutoPrepend(file: paths.dumpsPrependFile.path, version: version)
    }

    func isEnabled(version: String) -> Bool {
        php.isAutoPrependSet(file: paths.dumpsPrependFile.path, version: version)
    }

    func cleanupPrependFile() {
        try? FileManager.default.removeItem(at: paths.dumpsPrependFile)
    }

    private func writePrependFile(port: UInt16) throws {
        let dir = paths.dumpsPrependFile.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let php = Self.prependTemplate.replacingOccurrences(of: "KTSTACK_PORT", with: String(port))
        try php.write(to: paths.dumpsPrependFile, atomically: true, encoding: .utf8)
    }

    private static let prependTemplate = #"""
    <?php
    if (!function_exists('__ktstack_serialize')) {
        function __ktstack_serialize($v, $d = 0) {
            if ($d > 6) return ['type' => 'truncated'];
            if (is_null($v))   return ['type' => 'null'];
            if (is_bool($v))   return ['type' => 'bool',  'value' => $v];
            if (is_int($v))    return ['type' => 'int',   'value' => $v];
            if (is_float($v))  return ['type' => 'float', 'value' => $v];
            if (is_string($v)) return ['type' => 'string','value' => $v,'length' => strlen($v)];
            if (is_array($v)) {
                $items = [];
                foreach (array_slice($v, 0, 50, true) as $k => $i)
                    $items[] = ['key' => (string)$k, 'value' => __ktstack_serialize($i, $d + 1)];
                return ['type' => 'array', 'count' => count($v), 'items' => $items];
            }
            if (is_object($v)) {
                $props = [];
                foreach ((array)$v as $k => $i) {
                    $clean = preg_replace('/^\x00[^\x00]*\x00/', '', $k);
                    $props[] = ['key' => $clean, 'value' => __ktstack_serialize($i, $d + 1)];
                }
                return ['type' => 'object', 'class' => get_class($v), 'properties' => $props];
            }
            return ['type' => 'resource'];
        }
    }
    if (!function_exists('__ktstack_send')) {
        function __ktstack_send($var) {
            $self = __FILE__;
            $bt = debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS, 10);
            $caller = ['file' => '', 'line' => 0];
            foreach ($bt as $f) {
                if (isset($f['file']) && $f['file'] !== $self) {
                    $caller = $f; break;
                }
            }
            $payload = json_encode([
                'timestamp' => microtime(true),
                'file'      => $caller['file'] ?? '',
                'line'      => $caller['line'] ?? 0,
                'value'     => __ktstack_serialize($var),
            ], JSON_UNESCAPED_UNICODE);
            $fp = @fsockopen('127.0.0.1', KTSTACK_PORT, $errno, $errstr, 1);
            if ($fp) { fwrite($fp, $payload . "\n"); fclose($fp); }
        }
    }
    if (!function_exists('dump')) {
        function dump() {
            $vars = func_get_args();
            foreach ($vars as $var) { __ktstack_send($var); }
            return count($vars) === 1 ? reset($vars) : $vars;
        }
    }
    if (!function_exists('dd')) {
        function dd() {
            foreach (func_get_args() as $var) { __ktstack_send($var); }
            exit(1);
        }
    }
    """#
}
