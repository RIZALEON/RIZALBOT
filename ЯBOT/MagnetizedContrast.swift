import Foundation

/// Magnetized Contrast — magnetize only exact chrom:pos:allele to kit scaffolds.
/// Mid pole: Pre-Columbian Americas/Arctic/Antarctic. Far pole: archaics/hybrids.
enum MagnetizedContrast {
    struct PinKey: Hashable { let chrom: String; let pos: Int }
    /// Unordered diploid letters, e.g. "A/G" == "G/A"
    static func normalizeAlleles(_ s: String) -> String {
        let parts = s.split(separator: "/").map(String.init).sorted()
        return parts.joined(separator: "/")
    }
    static func magnetizes(kit: String, other: String) -> Bool {
        let a = kit.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let b = other.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if a.isEmpty || b.isEmpty { return false }
        if a.contains("PENDING") || b.contains("PENDING") || a == "." || b == "." { return false }
        return normalizeAlleles(a) == normalizeAlleles(b)
    }
    enum Pole: String { case midPrecolumbian, farArchaic, kit }
    static let kitBeltABO = "AB+"
    static let build = "GRCh37"
}
