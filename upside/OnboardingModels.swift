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
    case login
    case signUp
    case roleSelection
    case auth
    case accountCreation
    case creatorProfile
    case brandProfile
    case confirmation
}

class OnboardingState: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var selectedRole: UserRole?
    @Published var isComplete: Bool = false
    @Published var showNotificationSheet: Bool = false
    @Published var isLoginFlow: Bool = false
    
    var previousStep: OnboardingStep? {
        switch currentStep {
        case .roleSelection: return .welcome
        case .login: return .welcome
        case .auth: return .roleSelection
        case .accountCreation: return nil
        default: return nil
        }
    }
    
    func moveToNext() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex < OnboardingStep.allCases.count - 1 else { return }
        
        currentStep = OnboardingStep.allCases[currentIndex + 1]
    }
    
    func selectRole(_ role: UserRole) {
        selectedRole = role
        currentStep = .accountCreation
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showNotificationSheet = true
        }
    }
    
    func completeNotifications() {
        showNotificationSheet = false
    }
    
    func startSignUp() {
        currentStep = .roleSelection
    }
    
    func startLogin() {
        isLoginFlow = true
        currentStep = .login
    }
    
    func completeLoginNotifications() {
        showNotificationSheet = false
    }
    
    func goBack() {
        switch currentStep {
        case .roleSelection:
            currentStep = .welcome
        case .login:
            currentStep = .welcome
        case .auth:
            currentStep = .roleSelection
        case .accountCreation:
            if isLoginFlow {
                currentStep = .login
            } else {
                currentStep = .auth
            }
        default:
            break
        }
    }
}