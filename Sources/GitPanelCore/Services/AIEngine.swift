import Foundation
import SwiftUI

@MainActor
@Observable
public final class AIEngine {
    public static let shared = AIEngine()
    
    // Registry of all providers
    public let providers: [any AIProviderProtocol]
    
    // Exposed observable properties
    public var activeProviderName: String? = nil
    public var activeProviderIcon: String? = nil
    public var isRunning: Bool = false
    public var currentSessionDuration: TimeInterval? = nil
    public var currentTokenUsage: TokenUsage? = nil
    
    private var pollTimer: Timer?
    private var lastRecordedUsage: [String: TokenUsage] = [:]
    
    private init() {
        self.providers = [
            ClaudeProvider(),
            CodexProvider(),
            GeminiProvider(),
            AiderProvider(),
            OpenCodeProvider()
        ]
    }
    
    public func start() async {
        for provider in providers {
            await provider.startMonitoring()
        }
        
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateState()
            }
        }
    }
    
    public func stop() async {
        pollTimer?.invalidate()
        pollTimer = nil
        
        for provider in providers {
            await provider.stopMonitoring()
        }
    }
    
    private func updateState() {
        if let active = providers.first(where: { $0.isRunning }) {
            self.activeProviderName = active.name
            self.activeProviderIcon = active.icon
            self.isRunning = true
            self.currentSessionDuration = active.sessionDuration
            self.currentTokenUsage = active.tokenUsage
        } else {
            self.activeProviderName = nil
            self.activeProviderIcon = nil
            self.isRunning = false
            self.currentSessionDuration = nil
            self.currentTokenUsage = nil
        }
        
        // Track spending increments
        for provider in providers {
            guard provider.isRunning, let currentUsage = provider.tokenUsage else {
                if !provider.isRunning { lastRecordedUsage[provider.name] = nil }
                continue
            }
            
            let previousUsage = lastRecordedUsage[provider.name] ?? TokenUsage()
            
            let diffInput = max(0, currentUsage.input - previousUsage.input)
            let diffOutput = max(0, currentUsage.output - previousUsage.output)
            let diffCacheRead = max(0, currentUsage.cacheRead - previousUsage.cacheRead)
            let diffCacheCreation = max(0, currentUsage.cacheCreation - previousUsage.cacheCreation)
            
            if diffInput > 0 || diffOutput > 0 || diffCacheRead > 0 || diffCacheCreation > 0 {
                let diffUsage = TokenUsage(input: diffInput, output: diffOutput, cacheRead: diffCacheRead, cacheCreation: diffCacheCreation)
                let cost = CostEngine.shared.estimateCost(providerName: provider.name, usage: diffUsage)
                CostEngine.shared.addCost(cost)
            }
            
            lastRecordedUsage[provider.name] = currentUsage
        }
    }
}
