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

## 23 October 2026 - offline Android release permission incident and resolution

- Signed candidate #39920978148: FAILED CLOSED after successful real-key Gradle APK/AAB signing because packaged release APK unexpectedly declared `android.permission.INTERNET` and `android.permission.ACCESS_NETWORK_STATE`. No artifact published from this failed attempt.
- Disposable CI-only release-signing run #39922962806 confirmed both permission names, while debug CI alone had previously missed the release variant. No owner keystore was used in the diagnosis.
- PR #4 stripped both network permissions from merged app manifests and added release APK privacy verification in ordinary CI. Exact-head macOS/Android CI passed; Android signed-release log included only `com.sl.bestshot.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` among declared permissions.
- PR #5 requested a new candidate after main-only CI. Main `a2963eb8ccb406690f49b5c1f807cf9d5335723a`: Android #39924789787 PASS; macOS #39924789790 PASS; Android signed candidate #39924789727 SUCCESS. The job checked APK/AAB signatures, package `com.sl.bestshot`, absence of INTERNET/ACCESS_NETWORK_STATE/READ_MEDIA_IMAGES, and uploaded signed APK/AAB, SHA256SUMS and public certificate fingerprint to artifact `12489695383` (expires 2026-10-30).
- The **earlier signed artifact #39787153261 is superseded and MUST NOT be used for offline-privacy testing**, since it predates the release permission fix. Its prior CI 'success' applied to signing, not the stronger release permission gate.
- Real Android devices, Google Play Services-free offline model behavior, large photo batches and >=50 independently human-rated real photo bursts remain unverified. No publication authorized.
