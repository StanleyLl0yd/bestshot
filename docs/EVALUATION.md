# Independent evaluation protocol

**Status: not measured.** The existence of code, detector output or synthetic fixtures does NOT demonstrate that BestShot recommends the best photograph.

## Privacy and dataset

Collect at least 50 private, real, consented photo series; prioritize sets of 4-30 images for the primary top-3 metric. Keep image files and identifiable metadata **out of public GitHub**, CI logs and issue attachments. A separate private dataset has disjoint calibration and holdout partitions. Reviewers independently mark one or more preferred photos without seeing algorithm ranking; record at least two independent assessors per qualifying series.

Include portraits, selfies, groups, low light, sharp/blurred pairs, closed eyes, non-face scenes and varied camera orientation/HEIF formats. Report category coverage and failures, not only total score.

## Local result manifest (metadata only)

Save JSON with a top-level \`series\` array. Each record contains:
- \`id\`: non-identifying unique series code.
- \`split\`: \`calibration\` or \`holdout\`.
- \`category\`: e.g. \`group\` or \`portrait\`.
- \`sourceKind\`: \`real\` or \`synthetic\`.
- \`independentRaters\`: count of independent assessors.
- \`ranking\`: BestShot output as permutation of zero-based source indices.
- \`humanBest\`: zero-based indices independently judged to be among the best.

Manifest sample: \`shared/test-cases/example.json\` (synthetic, NOT eligible for real quality claims).

## Run on macOS

\`\`\`bash
swift shared/test-cases/evaluate.swift shared/test-cases/example.json
swift shared/test-cases/evaluate.swift /private/path/to/holdout-results.json --strict
\`\`\`

The script validates index completeness, uniqueness, class tags and source count (2-30). It reports top-1 agreement for 2-photo and 3-photo series separately. Primary top-3 overlap is reported only for 4-30 photo series (otherwise the inclusion metric would be trivially 100%). A strict pass requires at least 50 eligible held-out **4-30** real series and >=85% overlap. Metadata claims such as \`sourceKind=real\` or independent raters cannot be verified automatically; real evaluation still requires human QA.

For future upgrades also report processing time, memory, failures, wrong face counts, false positives for blur, and cases where uncertainty should have been shown. Keep calibration and final holdout disjoint.
