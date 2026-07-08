import Testing
@testable import WadeMoney

struct OnboardingGateTests {
    @Test func showsForFreshInstallWithNoCompletionAndNoData() {
        #expect(OnboardingGate.shouldShow(didCompleteOnboarding: false, hasExistingData: false) == true)
    }

    @Test func hidesWhenAlreadyCompleted() {
        #expect(OnboardingGate.shouldShow(didCompleteOnboarding: true, hasExistingData: false) == false)
    }

    @Test func hidesForExistingUsersEvenIfFlagDefaultsFalse() {
        #expect(OnboardingGate.shouldShow(didCompleteOnboarding: false, hasExistingData: true) == false)
    }

    @Test func hidesWhenBothCompletedAndHasData() {
        #expect(OnboardingGate.shouldShow(didCompleteOnboarding: true, hasExistingData: true) == false)
    }
}
