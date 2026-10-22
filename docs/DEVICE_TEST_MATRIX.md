# BestShot physical-device acceptance matrix

This is a **manual verification plan**, not a claim of completed testing. Do not enter personal photo filenames, image contents, keystores, signing passwords, biometric details or full personal paths in public CI logs or GitHub issues.

## macOS Apple Silicon

Use a real Apple Silicon Mac (primary: MacBook Air M4) running macOS 14+; first build and launch via Xcode's native macOS target. Do not treat an unsigned CI ZIP as an installer or a notarized release.

1. With networking disabled, choose a burst of exactly 2 images, then 30 images. Confirm count, true progress, recommended 1-3 frames and ranked remainder.
2. Attempt 1 and 31 images, cancel file dialog, include a duplicate path, unreadable file, unsupported file, nonexistent source and corrupt image. UI must not crash. Failed items and reasons remain visible even if fewer than two can be ranked.
3. Drag and drop 2, 10, 30 files in a single drop. Check no truncated, duplicate or split selection; repeat with a prohibited location while sandbox is enforced.
4. Use JPEG, PNG and HEIC/HEIF where supported, different EXIF orientations, portraits and landscapes, non-ASCII filenames and both wide-gamut and ordinary JPEG.
5. Process a batch of 30 large real smartphone photos. Watch Activity Monitor memory and UI responsiveness; cancel during Vision processing, then immediately start a different batch.
6. Compare arbitrary two frames, switch left and right indices and zoom from 100% to 300%; verify neither source file changes during preview.
7. Export two distinct photos sharing the same filename into an existing directory already containing the name. Confirm unique filenames, **byte-identical** copies and unchanged originals. Repeat with an inaccessible output folder and insufficient disk space.
8. Check system Light/Dark appearance, VoiceOver, keyboard focus/selection, enlarged UI text and both Russian and English system locale.
9. Compare with networking disabled; verify no internet is required and app has no network entitlements after code signing.
10. Record OS, Mac model, device type, test date, test case ID and PASS/FAIL, never private paths or images.

For file integrity, use `shasum -a 256 <source-file> <exported-copy>` and compare the two hashes. The test harness also has byte-preservation unit tests, but GUI export still needs device verification.

## Android 10 and current Android

Test at least one **real Android 10/API29** device and one current Android device. Add a no-Google-Play-Services device if available. Install the CI **debug APK**; unsigned AAB is not directly installable. This APK is for testing only and not a store build.

1. Launch in airplane mode without first downloading any AI models. Select 2, then 30 photos. Confirm ML Kit bundled face detection functions, or explicitly record missing models/permissions.
2. Use Android Photo Picker on a current device and `ACTION_OPEN_DOCUMENT` fallback on Android 10/no-Play-Services device. Ensure no broad gallery permission and no `INTERNET` manifest permission.
3. Confirm invalid selections and unavailable document URI do not crash. Try photo revoke/access failure, 1 and 31 candidate files where Picker allows, corrupted JPEG, PNG, HEIC/HEIF and rotated EXIF.
4. Exercise single face frontal/rotated, eyes open/closed when reliably detected, group with varied detected-face counts, no human faces, blurred and uneven exposure scenes. Ensure missing eye signal is **not** reported as closed eyes, and serious uncertainty is displayed.
5. Process 30 high-resolution photos while monitoring memory and UI; cancel mid-series, immediately begin new analysis, rotate screen and background/foreground the app. Check stale results never overwrite newer ones.
6. Switch arbitrary two photo indices in comparison, zoom 100%-300% and inspect EXIF orientation. Observe OOM crashes or truncated display.
7. Export through Android Storage Access Framework to a user-selected folder with existing duplicate names. Verify byte-identical copies, existing destination files remain unchanged, and originals are intact. Test SD card/external provider if available, revoke URI grant and try insufficient space.
8. Test Russian and English, Material You dark/light themes, Android large font and TalkBack, rotation and foreground recovery.
9. Record device model, Android API level, Play Services yes/no, test identifier and PASS/FAIL. No identifying photo metadata.

For integrity on a connected debug device, copy files to a local workstation and compare SHA-256 hashes, or compute the hashes using a trustworthy local file tool. Do not upload personal photos to public issue attachments.

## AI quality holdout (both platforms)

- Independently collect and label >=50 real **4-30-shot** bursts, split calibration vs holdout *before* tuning. Two or more human raters per eligible held-out burst.
- Test primary top-3 inclusion >=85%, as described in `EVALUATION.md`; evaluate 2- and 3-shot top-1 separately. Record per-category results and abstention/uncertainty.
- Do not fabricate numerical quality guarantees when the independent corpus is absent.

## Acceptance gates

All platform CI checks pass on the exact head; real-device scenarios above PASS or have documented limitations; byte-for-byte source integrity confirmed, no internet dependency; human evaluation threshold actually measured. Before distribution, finish code signing, permission review, supply-chain review and final release acceptance. No publication is authorized by this checklist.
