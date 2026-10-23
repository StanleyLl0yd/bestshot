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

Testing artifacts: GitHub Actions retains a debug Android APK, unsigned release AAB and unsigned macOS arm64 ZIP for 14 days after passing runs. These are **not** store releases; macOS signing, device checks and final security review remain mandatory.

## Status

**Experimental prototypes, not 1.0 releases.** Relative scores are not accuracy percentages. AI recommendations have not yet been validated against independent human choices or real-device runs.

Documentation: docs/ARCHITECTURE.md, docs/SCORING.md, docs/EVALUATION.md, docs/PRIVACY.md, docs/VERIFICATION.md.

No license has been selected. All rights reserved until approval. No GitHub release or store publication authorized.

Android signing is optional and main-only. See [Android signing instructions](docs/ANDROID_SIGNING.md).

## Verified signed Android test candidate (23 October 2026)

[GitHub Actions signed run #39924789727](https://github.com/StanleyLl0yd/bestshot/actions/runs/39924789727) built APK/AAB using encrypted owner-managed Environment Secrets and passed cryptographic signature verification, expected package `com.sl.bestshot`, no `INTERNET`, `ACCESS_NETWORK_STATE`, or `READ_MEDIA_IMAGES` permission, and SHA-256 checksum publication. The artifact expires on 30 October 2026. Use `scripts/Get-BestShotAndroidCandidate.ps1` on a trusted Windows machine with PowerShell 7 + GitHub CLI to download the latest successful candidate and check its SHA-256 values.

**Do not use the earlier signed run #39787153261 (22 October)**: the release-only network permission issue was not yet identified or fixed. It is superseded. The signed APK/AAB is strictly for testing; physical device acceptance, human ranking quality evaluation and all store approvals remain open.
