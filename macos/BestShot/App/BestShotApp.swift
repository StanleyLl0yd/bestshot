import SwiftUI

@main
struct BestShotApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 750, minHeight: 500)
        }
    }
}

enum L {
    static var ru: Bool { Locale.current.language.languageCode?.identifier == "ru" }
    static func text(_ russian: String, _ english: String) -> String { ru ? russian : english }
}
