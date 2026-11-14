import Foundation

enum MachOInspector {
    /// True if LC_ENCRYPTION_INFO(_64) has cryptid != 0 (thin or fat arm64 binaries).
    static func isEncrypted(_ url: URL) -> Bool {
        guard let d = try? Data(contentsOf: url, options: .mappedIfSafe), d.count > 32 else { return true }
        var base = 0
        let magic = d.withUnsafeBytes { $0.load(as: UInt32.self) }
        if magic == 0xBEBAFECA { // fat: big-endian header, find arm64 (cputype 0x0100000C)
            let n = Int(UInt32(bigEndian: d.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }))
            for i in 0..<n {
                let o = 8 + i * 20
                let cpu = UInt32(bigEndian: d.withUnsafeBytes { $0.load(fromByteOffset: o, as: UInt32.self) })
                if cpu == 0x0100000C {
                    base = Int(UInt32(bigEndian: d.withUnsafeBytes { $0.load(fromByteOffset: o + 8, as: UInt32.self) }))
                }
            }
        }
        let ncmds = Int(d.withUnsafeBytes { $0.load(fromByteOffset: base + 16, as: UInt32.self) })
        var off = base + 32
        for _ in 0..<ncmds {
            let cmd = d.withUnsafeBytes { $0.load(fromByteOffset: off, as: UInt32.self) }
            let size = Int(d.withUnsafeBytes { $0.load(fromByteOffset: off + 4, as: UInt32.self) })
            if cmd == 0x2C { // LC_ENCRYPTION_INFO_64
                return d.withUnsafeBytes { $0.load(fromByteOffset: off + 16, as: UInt32.self) } != 0
            }
            off += size
        }
        return false
    }
}
