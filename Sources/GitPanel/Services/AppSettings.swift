import Foundation
import SwiftUI

@Observable final class AppSettings {
    static let shared = AppSettings()
    var usageEnabled: Bool {
        didSet { UserDefaults.standard.set(usageEnabled, forKey: "usageEnabled") }
    }
    var usageRemaining: String {
        didSet { UserDefaults.standard.set(usageRemaining, forKey: "usageRemaining") }
    }

    init() {
        self.usageEnabled = UserDefaults.standard.bool(forKey: "usageEnabled")
        self.usageRemaining = UserDefaults.standard.string(forKey: "usageRemaining") ?? ""
    }
}
