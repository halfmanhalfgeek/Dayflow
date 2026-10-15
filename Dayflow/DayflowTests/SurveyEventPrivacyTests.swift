import XCTest

@testable import Dayflow

final class SurveyEventPrivacyTests: XCTestCase {
  func testPassiveSurveyEventsRequireAnalyticsOptIn() {
    XCTAssertFalse(makeEvent("eligible").shouldSend(analyticsEnabled: false))
    XCTAssertFalse(makeEvent("shown").shouldSend(analyticsEnabled: false))
    XCTAssertTrue(makeEvent("eligible").shouldSend(analyticsEnabled: true))
    XCTAssertTrue(makeEvent("shown").shouldSend(analyticsEnabled: true))
  }

  func testExplicitSurveyResponsesCanBeSentWithoutAnalyticsOptIn() {
    for event in ["answered", "completed", "dismissed"] {
      XCTAssertTrue(makeEvent(event).shouldSend(analyticsEnabled: false))
    }
  }

  private func makeEvent(_ name: String) -> SurveyEvent {
    SurveyEvent(
      clientEventId: "test-event",
      surveyId: "test-survey",
      event: name,
      questionId: nil,
      answer: nil,
      context: [:],
      occurredAt: Date(timeIntervalSince1970: 0))
  }
}