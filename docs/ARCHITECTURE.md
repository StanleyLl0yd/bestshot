# Architecture

BestShot selects 2-30 user-picked photos locally, independently on macOS and Android.

macOS: SwiftUI + Vision face-capture quality, CoreGraphics grayscale gradient sharpness, clipping-based exposure penalty, shared-in-source Swift RankingCore.

Android: Jetpack Compose + bundled ML Kit face detection, image metrics and independent Kotlin ranker.

No account, network feature, remote model, database, or biometric matching. Photos are only read. Exports always create copies and never remove originals.

Scoring within each series is relative, not calibrated quality percentage. For groups, face-capture quality does not directly compare different people. Different face counts across photos trigger uncertainty rather than rewarding a lower face count.

Initial code is not evidence that real-world ranking quality is acceptable. See docs/SCORING.md and tests.
