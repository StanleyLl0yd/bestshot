import Foundation

// Local QA only: this reads metadata indices and never opens user photos.
struct EvaluationFile: Decodable {
    let series: [Series]
}

struct Series: Decodable {
    let id: String
    let split: String
    let category: String
    let sourceKind: String
    let independentRaters: Int
    let ranking: [Int]
    let humanBest: [Int]
}

struct Metric {
    var matched = 0
    var total = 0
    mutating func add(_ hit: Bool) {
        total += 1
        if hit { matched += 1 }
    }
    var description: String {
        guard total > 0 else { return "N/A (0 series)" }
        return String(format: "%.1f%% (%d/%d)",
                      Double(matched) / Double(total) * 100, matched, total)
    }
}

func evaluate() throws {
    let args = Array(CommandLine.arguments.dropFirst())
    guard let filename = args.first, args.count <= 2,
          args.count == 1 || args[1] == "--strict" else {
        throw NSError(domain: "BestShot", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "Usage: swift evaluate.swift manifest.json [--strict]"])
    }
    let manifest = try JSONDecoder().decode(EvaluationFile.self,
        from: Data(contentsOf: URL(fileURLWithPath: filename)))
    var ids = Set<String>()
    var eligible = 0
    var pairs = Metric()
    var triples = Metric()
    var top3 = Metric()
    var categories: [String: Metric] = [:]
    for series in manifest.series {
        guard !series.id.isEmpty && ids.insert(series.id).inserted else {
            throw NSError(domain: "BestShot", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Duplicate or blank series id"])
        }
        let n = series.ranking.count
        guard (2...30).contains(n),
              series.ranking.sorted() == Array(0..<n),
              !series.humanBest.isEmpty,
              Set(series.humanBest).count == series.humanBest.count,
              series.humanBest.allSatisfy({ (0..<n).contains($0) }),
              ["holdout", "calibration"].contains(series.split),
              ["real", "synthetic"].contains(series.sourceKind),
              !series.category.isEmpty,
              series.independentRaters >= 0 else {
            throw NSError(domain: "BestShot", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid series record: \(series.id)"])
        }
        // This eligibility claim comes from researcher-supplied metadata; no external verification.
        guard series.split == "holdout" && series.sourceKind == "real" &&
              series.independentRaters >= 2 else { continue }
        eligible += 1
        let best = Set(series.humanBest)
        let top1Hit = best.contains(series.ranking[0])
        if n == 2 { pairs.add(top1Hit) }
        else if n == 3 { triples.add(top1Hit) }
        else {
            let hit = !best.isDisjoint(with: series.ranking.prefix(3))
            top3.add(hit)
            var categoryScore = categories[series.category] ?? Metric()
            categoryScore.add(hit)
            categories[series.category] = categoryScore
        }
    }
    print("BestShot human-rated held-out evaluation")
    print("Eligible real series (>=2 independent raters): \(eligible)")
    print("Two-photo top-1 agreement: \(pairs.description)")
    print("Three-photo top-1 agreement: \(triples.description)")
    print("4-30 photo top-3 overlap: \(top3.description)")
    for category in categories.keys.sorted() {
        print("  \(category): \(categories[category]!.description)")
    }
    let accepted = top3.total >= 50 &&
        Double(top3.matched) / Double(top3.total) >= 0.85
    print(accepted ? "Target met on submitted metadata (not independently audited)." :
          "Target NOT established: need >=50 eligible 4-30 photo series and >=85% overlap.")
    if args.contains("--strict") && !accepted { exit(1) }
}

do {
    try evaluate()
} catch {
    fputs("BestShot evaluation error: \(error.localizedDescription)\n", stderr)
    exit(2)
}
