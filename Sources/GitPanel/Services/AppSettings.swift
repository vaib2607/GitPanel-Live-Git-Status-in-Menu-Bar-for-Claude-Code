import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    @Published var usageEnabled: Bool {
        didSet { UserDefaults.standard.set(usageEnabled, forKey: "usageEnabled") }
    }
    @Published var usageRemaining: String {
        didSet { UserDefaults.standard.set(usageRemaining, forKey: "usageRemaining") }
    }

    init() {
        self.usageEnabled = UserDefaults.standard.bool(forKey: "usageEnabled")
        self.usageRemaining = UserDefaults.standard.string(forKey: "usageRemaining") ?? ""
    }
}
