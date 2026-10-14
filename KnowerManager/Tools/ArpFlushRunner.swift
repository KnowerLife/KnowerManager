import Foundation

enum ArpFlushRunner {
    static func flush(completion: @escaping (Bool, String) -> Void) {
        // macOS: arp -d flush all? but need sudo; or dscacheutil/other
        let script = """
        /usr/sbin/arp -a -d 2>/dev/null; true
        """
        PrivilegedRunner.shared.runAsAdmin(script: script) { ok, message in
            completion(ok, message)
        }
    }
}
