# Privacy and data retention

BestShot 1.0 is offline, requires no sign-in, backend, analytics or advertising, and does not transfer images to servers. Android declares no INTERNET permission; macOS requests no network entitlement.

Only user-selected photos are analyzed. Image pixels are downsampled in memory for scoring; no face identity is determined or stored. Sessions are ephemeral; no image history database. Exports are byte-for-byte filesystem copies to user-selected destinations and never modify/delete originals.

Do not add user photos, image paths, face data, signing certificates or secrets to logs, public fixtures or CI. Real-human evaluation photos must be privately stored with consent.
