# Privacy and data retention

BestShot 1.0 is offline, requires no sign-in, backend, analytics or advertising, and does not transfer images to servers. Android declares no INTERNET permission; macOS requests no network entitlement.

Only user-selected photos are analyzed. Image pixels are downsampled in memory for scoring; no face identity is determined or stored. Sessions are ephemeral; no image history database. Exports are byte-for-byte filesystem copies to user-selected destinations and never modify/delete originals.

Do not add user photos, image paths, face data, signing certificates or secrets to logs, public fixtures or CI. Real-human evaluation photos must be privately stored with consent.

Android's bundled ML Kit/other merged release dependencies were observed to contribute `android.permission.INTERNET` and `android.permission.ACCESS_NETWORK_STATE` on 2026-10-23, even though the debug variant did not. The app manifest explicitly removes both via manifest merger rules. Both disposable-key release APK and real-key signed candidate APK are checked after packaging to reject either network permission, plus READ_MEDIA_IMAGES. Real-device offline ML Kit operation is still an acceptance test, not yet proven by CI.
