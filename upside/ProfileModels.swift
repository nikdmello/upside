import Foundation
import Combine

struct CreatorProfile {
    var fullName: String = ""
    var username: String = ""
    var bio: String = ""
    var location: String = ""
    var categories: [String] = []
    var followerCount: String = ""
    var engagementRate: String = ""
    var licenseNumber: String = ""
    var licenseExpiry: Date?
    var baseRate: String = ""
    var storyRate: String = ""
    var reelRate: String = ""
}

enum CreatorProfileStep: CaseIterable {
    case name
    case audience
    case rate
    case finish
    
    var title: String {
        switch self {
        case .name: return "What's your name?"
        case .audience: return "How big is your audience?"
        case .rate: return "What's your rate?"
        case .finish: return "You're all set!"
        }
    }
    
    var stepNumber: Int {
        return CreatorProfileStep.allCases.firstIndex(of: self)! + 1
    }
    
    var totalSteps: Int {
        return CreatorProfileStep.allCases.count
    }
}

class CreatorProfileState: ObservableObject {
    @Published var profile = CreatorProfile()
    @Published var currentStep: CreatorProfileStep = .name
    @Published var isComplete = false
    
    var canGoNext: Bool {
        switch currentStep {
        case .name:
            return !profile.fullName.isEmpty
        case .audience:
            return !profile.followerCount.isEmpty
        case .rate:
            return !profile.baseRate.isEmpty
        case .finish:
            return false
        }
    }
    
    var canGoBack: Bool {
        return currentStep != .name && currentStep != .finish
    }
    
    func nextStep() {
        guard canGoNext else { return }
        
        switch currentStep {
        case .name:
            currentStep = .audience
        case .audience:
            currentStep = .rate
        case .rate:
            currentStep = .finish
            isComplete = true
        case .finish:
            break
        }
    }
    
    func previousStep() {
        guard canGoBack else { return }
        
        switch currentStep {
        case .audience:
            currentStep = .name
        case .rate:
            currentStep = .audience
        case .name, .finish:
            break
        }
    }
}

struct BrandProfile {
    var companyName: String = ""
    var industry: String = ""
    var description: String = ""
    var website: String = ""
    var location: String = ""
    var campaignBudget: String = ""
    var targetAudience: String = ""
    var campaignGoals: [String] = []
}

enum BrandProfileStep: CaseIterable {
    case company
    case budget
    case goals
    case finish
    
    var title: String {
        switch self {
        case .company: return "What's your company?"
        case .budget: return "What's your budget?"
        case .goals: return "What's your goal?"
        case .finish: return "Ready to launch!"
        }
    }
    
    var stepNumber: Int {
        return BrandProfileStep.allCases.firstIndex(of: self)! + 1
    }
    
    var totalSteps: Int {
        return BrandProfileStep.allCases.count
    }
}

class BrandProfileState: ObservableObject {
    @Published var profile = BrandProfile()
    @Published var currentStep: BrandProfileStep = .company
    @Published var isComplete = false
    
    var canGoNext: Bool {
        switch currentStep {
        case .company:
            return !profile.companyName.isEmpty
        case .budget:
            return !profile.campaignBudget.isEmpty
        case .goals:
            return !profile.targetAudience.isEmpty
        case .finish:
            return false
        }
    }
    
    var canGoBack: Bool {
        return currentStep != .company && currentStep != .finish
    }
    
    func nextStep() {
        guard canGoNext else { return }
        
        switch currentStep {
        case .company:
            currentStep = .budget
        case .budget:
            currentStep = .goals
        case .goals:
            currentStep = .finish
            isComplete = true
        case .finish:
            break
        }
    }
    
    func previousStep() {
        guard canGoBack else { return }
        
        switch currentStep {
        case .budget:
            currentStep = .company
        case .goals:
            currentStep = .budget
        case .company, .finish:
            break
        }
    }
}