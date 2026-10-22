# Scoring specification v0 (provisional)

For a *single selected series*, calculate grayscale Laplacian-square mean on consistently downsampled, EXIF-oriented image pixels. Let S be log(1+sharpness), normalized across valid frames to [0,1], or 0.5 for equal S. Exposure penalty P is 0.80 * fraction of extremely dark/bright pixels + 0.20 * penalty for an extreme global mean, clamped [0,1].

Technical score T = 0.70 * normalized-sharpness + 0.30 * (1-P).
When one face is found and Vision faceCaptureQuality exists: score = 0.80*T + 0.20*quality. Otherwise score=T. Different group members' capture quality is *not* compared. A varying number of detected faces across a burst triggers an uncertainty warning. A score gap under 0.055 between top two means the ranking is ambiguous. Stable ties use the original selection order.

Known limits:
- Global Laplacian scores texture as well as focus, and downsizing changes results.
- Clipped pixels cannot distinguish deliberate black/white backgrounds or high-key scenes.
- ML Kit and Vision supply different AI signals. Future evaluation must calibrate separate platform weights.
- The algorithm does not determine beauty, identity, smile quality, or guaranteed open eyes.
- Need a private, independently human-rated holdout of >=50 real bursts; target top-3 inclusion >=85%, not measured yet.
- Do not tune on evaluation series. For two-photo sets measure top-1 agreement separately.
