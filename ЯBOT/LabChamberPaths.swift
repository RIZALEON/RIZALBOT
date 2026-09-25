import Foundation

/// CEMENTED — Lab of Genetic and Technological Creations.
/// Same root-tree place on every OS: `lab/rooms/LAB-LANDING.jpg` (alias LAB-OF-CREATIONS.jpg)`
enum LabChamberPaths {
    static let roomId = "lab.of.creations"
    static let title = "Lab of Genetic and Technological Creations"
    /// Relative to ЯBOT root — NEVER fork per platform.
    static let canonRelpath = "lab/rooms/LAB-LANDING.jpg"
    static let canonAliasRelpath = "lab/rooms/LAB-OF-CREATIONS.jpg"
    static let bundleAsset = "LabOfCreations"
    static let hotAsset = "LabOfCreations"
    static let deepLink = "yabot://lab/chamber"
    static let deepLinkAliases = [
        "yabot://lab/room", "yabot://lab/void", "yabot://lab/rbits", "yabot://lab/creations"
    ]

    /// Resolved file seats (Documents first, then absolute Mac seat, then bundle via ClayImage).
    static func candidateFilePaths() -> [String] {
        let home = NSHomeDirectory()
        return [
            home + "/Documents/ЯBOT/" + canonRelpath,
            home + "/Documents/ЯBOT/" + canonAliasRelpath,
            home + "/Documents/ЯBOT/hot-assets/LabLanding.png",
            home + "/Documents/ЯBOT/hot-assets/LabOfCreations.png",
            home + "/Documents/ЯBOT/hot-assets/LabChamber.png",
            "/Users/rizal/Documents/ЯBOT/" + canonRelpath,
            "/Users/rizal/Documents/ЯBOT/" + canonAliasRelpath,
            "/Users/rizal/Documents/ЯBOT/hot-assets/LabLanding.png",
        ]
    }
}
