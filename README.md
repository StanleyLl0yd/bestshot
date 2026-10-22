# BestShot

Two independent, native offline photo-series selectors in one repository.

- macOS 14+ (Apple Silicon arm64): Swift 6, SwiftUI, Apple Vision, CoreGraphics.
- Android 10+ (API 29): Kotlin, Compose Material 3, bundled ML Kit Face Detection.
- Choose 2-30 similar photos; rank, compare, and export unmodified copies.
- Russian primary, English fallback.
- No backend, analytics, ads, internet permission, accounts or biometric identification.

## Build and test

macOS: open macos/BestShot.xcodeproj in Xcode 27.1. Swift ranking tests: run swift test from macos directory.
Android: JDK 25 / AGP 9.4 / Gradle 9.6.0. From android/, run ./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug :app:bundleRelease (or gradlew.bat on Windows). Official Gradle 9.6.0 wrapper scripts and JAR are committed, the distribution is pinned by SHA-256. These Gradle files retain their own Apache-2.0 licensing notices; this project still has no selected license.

## Status

**Experimental prototypes, not 1.0 releases.** Relative scores are not accuracy percentages. AI recommendations have not yet been validated against independent human choices or real-device runs.

Documentation: docs/ARCHITECTURE.md, docs/SCORING.md, docs/EVALUATION.md, docs/PRIVACY.md, docs/VERIFICATION.md.

No license has been selected. All rights reserved until approval. No GitHub release or store publication authorized.
