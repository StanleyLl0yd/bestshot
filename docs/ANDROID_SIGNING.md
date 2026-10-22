# BestShot Android signing

Never attach the keystore or its passwords in a chat, Git commit, issue, pull request, Google Drive exchange folder or CI artifact.

## Upload from your own computer

1. Keep an encrypted backup of the original keystore and credentials.
2. On Windows with PowerShell 7+ and GitHub CLI, review the public script at scripts/Upload-BestShotSigningSecrets.ps1 and execute it locally from the checked-out repository.
3. The script prompts for the path to the local key, alias, keystore password, and key password. It passes each value via standard input to gh secret set, without showing values in shell command arguments or logs.
4. GitHub CLI encrypts secrets locally before sending them. Base64 is just a transfer encoding, not encryption.

GitHub Actions Environment Secrets (environment: bestshot-android-signing, only main allowed):
- BESTSHOT_ANDROID_KEYSTORE_BASE64
- BESTSHOT_ANDROID_STORE_PASSWORD
- BESTSHOT_ANDROID_KEY_ALIAS
- BESTSHOT_ANDROID_KEY_PASSWORD

Check secret names under Settings -> Environments -> bestshot-android-signing -> Environment secrets. The script enforces main-only access and removes older repository-scoped copies with the same names.

## Signed candidate build

After this workflow is reviewed and merged into main, use Actions -> Android signed candidates -> Run workflow -> main.

Only manual dispatch on main uses Environment Secrets. The workflow temporarily writes the signing keystore with permissions 0600, signs release APK and AAB, verifies their signatures and calculates SHA-256 checksums, then deletes the temporary keystore on the runner.

Signed output is a GitHub Actions artifact retained for seven days, not a published GitHub Release or store submission. Public repository workflow artifacts may be downloadable: the artifact contains only APK/AAB and checksums, never private keys/passwords.

Ordinary pull-request CI never accesses signing Secrets and remains unsigned. Incomplete signing configuration fails closed.

## Protection and continuity

Protect main against force-push, deletion and unreviewed changes; approve changes to the signing workflow before merging. Anyone able to modify and run trusted main workflows could otherwise misuse signing Secrets. Consider requiring approvals via GitHub Environments as additional hardening.

Using one existing keystore across several apps increases the impact of compromise. A dedicated BestShot key is preferable if it has not been published yet. Preserve its signing fingerprint (keytool -list -v -keystore PATH) and credentials securely for future app updates.

For Google Play App Signing, an upload certificate may differ from the certificate Google uses to sign store-distributed APKs.

No app publication or GitHub Release is authorized by this configuration. Real-device and AI-quality testing remain mandatory.
