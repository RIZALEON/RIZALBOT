import Foundation

/// TOKENBLAST — fire crown twin (or a pasted mint) through live public pipes and report
/// what returns: perfection, peculiarity, or strangeness. NonNuclear · cite-only · no sends.
/// 0.3.3: the pipe engine moved to TokenBlastProbe (shared with TRUEBLAST + BANGЯANG); output unchanged.
enum TokenBlast {
    /// ACT: `tokenblast` · `token blast` · `blast token` [optional mint]
    static func run(mintArg: String? = nil) -> String {
        TokenBlastProbe.report(mintArg: mintArg)
    }
}
