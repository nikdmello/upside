import Foundation
import Combine

enum UserRole: String, CaseIterable {
    case creator = "creator"
    case brand = "brand"
    
    var displayName: String {
        switch self {
        case .creator: return "Creator"
        case .brand: return "Brand"
        }
    }
    
    var description: String {
        switch self {
        case .creator: return "Licensed influencer looking for brand partnerships"
        case .brand: return "Business seeking authentic creator collaborations"
        }
    }
}

enum OnboardingStep: CaseIterable {
    case welcome
    case roleSelection
    case accountCreation
    case creatorProfile
    case creatorLicense
    case creatorRates
    case brandProfile
    case brandCampaign
    case brandGoals
    case confirmation
}

class OnboardingState: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var selectedRole: UserRole?
    @Published var isComplete: Bool = false
    @Published var showNotificationSheet: Bool = false
    
    func moveToNext() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex < OnboardingStep.allCases.count - 1 else { return }
        
        currentStep = OnboardingStep.allCases[currentIndex + 1]
    }
    
    func selectRole(_ role: UserRole) {
        selectedRole = role
        showNotificationSheet = true
    }
}