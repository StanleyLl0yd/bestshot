# Verification register - BestShot (2026-10-22)

## Confirmed on exact-head b7f4f979b8fda24ed889eef938141882a49eea40

- macOS GitHub Actions 39775941358: Swift tests, Xcode 27.1 Release build and arm64 architecture, external-package/no-network-entitlement checks PASS.
- Android GitHub Actions 39775941289: Gradle build, unit tests, lint, debug APK, release AAB and manifest permission checks PASS.
- All CI builds use unsigned artifacts and are not distributable production releases.

## Still unverified

- Real macOS SwiftUI drag-and-drop, photo selection and export on Apple Silicon.
- macOS 14 compatibility and sandbox-scoped access on physical hardware.
- Android 10 device fallback Photo Picker and original-quality SAF export on devices with/without Play Services.
- UI accessibility, rotation, large fonts, cancellation during face analysis, and large-image memory under actual workload.
- AI ranking accuracy on >=50 private, independent human-rated real series. None has been measured yet; see EVALUATION.md.
- Official Gradle 9.6.0 wrapper scripts/JAR SHA matched upstream; wrapper validation and Android compilation PASS on CI run 39778007802. Future runs use exact PR-head checkout; review each final run separately.
- Main branch rulesets, push protection, Dependabot and security settings are not administratively verified by the connector.

Do not publish or merge as final release on the strength of compilation alone.

## Confirmed integrated main 7928400a291556be610e1725a6162f2b5ce67a9b (2026-10-22)

- macOS push CI 39787153161: PASS.
- Android push CI 39787153175: PASS, including disposable temporary keystore signing smoke test with no real signing key.
- Android signed candidates 39787153261: PASS. Used main-only encrypted GitHub Environment Secrets supplied locally by repository owner; real-key APK and AAB signatures verified, signed APK/AAB and SHA checksums retained in Actions artifact 12429452915 (7 days). This is a test artifact, NOT a store submission, notarization or public release.
- Signing credentials and keystore were never added to source control. Secrets cannot be read back by the GitHub connector. There is no assertion of successful device installation or human ranking accuracy from these CI results.
