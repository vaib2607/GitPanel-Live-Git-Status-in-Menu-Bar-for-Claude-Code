import Foundation
import Observation

public struct ModelPricing: Sendable {
    public var inputPer1M: Double
    public var outputPer1M: Double
    public var cacheReadPer1M: Double
    public var cacheCreationPer1M: Double
    
    public init(inputPer1M: Double, outputPer1M: Double, cacheReadPer1M: Double = 0, cacheCreationPer1M: Double = 0) {
        self.inputPer1M = inputPer1M
        self.outputPer1M = outputPer1M
        self.cacheReadPer1M = cacheReadPer1M
        self.cacheCreationPer1M = cacheCreationPer1M
    }
}

@Observable
public final class CostEngine {
    public static let shared = CostEngine()
    
    // Total accumulated cost since installation
    private let totalKey = "GitPanel_TotalCost"
    private let dailyCostKeyPrefix = "GitPanel_DailyCost_"
    private let monthlyCostKeyPrefix = "GitPanel_MonthlyCost_"
    
    public var todayCost: Double {
        UserDefaults.standard.double(forKey: dailyCostKeyPrefix + currentDayString)
    }
    
    public var thisMonthCost: Double {
        UserDefaults.standard.double(forKey: monthlyCostKeyPrefix + currentMonthString)
    }
    
    private var currentDayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private var currentMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
    
    // Default pricing as a fallback
    public var pricingTable: [String: ModelPricing] = [
        "Claude Code": ModelPricing(inputPer1M: 3.0, outputPer1M: 15.0, cacheReadPer1M: 0.3, cacheCreationPer1M: 3.75),
        "OpenAI Codex": ModelPricing(inputPer1M: 5.0, outputPer1M: 15.0),
        "Google Gemini": ModelPricing(inputPer1M: 3.5, outputPer1M: 10.5),
        "Aider": ModelPricing(inputPer1M: 5.0, outputPer1M: 15.0),
        "OpenCode": ModelPricing(inputPer1M: 3.0, outputPer1M: 15.0)
    ]
    
    private init() {
        Task {
            await fetchPricing()
        }
    }
    
    public func fetchPricing() async {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)
            
            var newTable = self.pricingTable
            
            for model in response.data {
                guard let promptDouble = Double(model.pricing.prompt),
                      let completionDouble = Double(model.pricing.completion) else { continue }
                
                let promptPer1M = promptDouble * 1_000_000
                let completionPer1M = completionDouble * 1_000_000
                
                // Map OpenRouter models to our providers
                if model.id == "anthropic/claude-3.5-sonnet:beta" || model.id == "anthropic/claude-3.5-sonnet" {
                    newTable["Claude Code"] = ModelPricing(inputPer1M: promptPer1M, outputPer1M: completionPer1M, cacheReadPer1M: promptPer1M * 0.1, cacheCreationPer1M: promptPer1M * 1.25)
                    newTable["OpenCode"] = ModelPricing(inputPer1M: promptPer1M, outputPer1M: completionPer1M)
                } else if model.id == "openai/gpt-4o" {
                    newTable["OpenAI Codex"] = ModelPricing(inputPer1M: promptPer1M, outputPer1M: completionPer1M)
                    newTable["Aider"] = ModelPricing(inputPer1M: promptPer1M, outputPer1M: completionPer1M)
                } else if model.id == "google/gemini-1.5-pro-exp" || model.id == "google/gemini-pro-1.5" {
                    newTable["Google Gemini"] = ModelPricing(inputPer1M: promptPer1M, outputPer1M: completionPer1M)
                }
            }
            
            Task { @MainActor in
                self.pricingTable = newTable
            }
        } catch {
            print("Failed to fetch OpenRouter pricing: \(error)")
        }
    }
    
    public func estimateCost(providerName: String, usage: TokenUsage) -> Double {
        guard let pricing = pricingTable[providerName] else { return 0.0 }
        
        let inputCost = (Double(usage.input) / 1_000_000.0) * pricing.inputPer1M
        let outputCost = (Double(usage.output) / 1_000_000.0) * pricing.outputPer1M
        let cacheReadCost = (Double(usage.cacheRead) / 1_000_000.0) * pricing.cacheReadPer1M
        let cacheCreationCost = (Double(usage.cacheCreation) / 1_000_000.0) * pricing.cacheCreationPer1M
        
        return inputCost + outputCost + cacheReadCost + cacheCreationCost
    }
    
    public func addCost(_ incrementalCost: Double) {
        guard incrementalCost > 0 else { return }
        
        let defaults = UserDefaults.standard
        let dayKey = dailyCostKeyPrefix + currentDayString
        let monthKey = monthlyCostKeyPrefix + currentMonthString
        
        let currentDayCost = defaults.double(forKey: dayKey)
        let currentMonthCost = defaults.double(forKey: monthKey)
        let currentTotalCost = defaults.double(forKey: totalKey)
        
        defaults.set(currentDayCost + incrementalCost, forKey: dayKey)
        defaults.set(currentMonthCost + incrementalCost, forKey: monthKey)
        defaults.set(currentTotalCost + incrementalCost, forKey: totalKey)
    }
}

// MARK: - OpenRouter API Models
private struct OpenRouterModelsResponse: Codable {
    let data: [OpenRouterModel]
}

private struct OpenRouterModel: Codable {
    let id: String
    let pricing: OpenRouterPricing
}

private struct OpenRouterPricing: Codable {
    let prompt: String
    let completion: String
}
