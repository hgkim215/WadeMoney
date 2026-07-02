import XCTest

/// 핵심 루프 E2E: 앱 실행 → 빠른 입력으로 지출 저장 → 대시보드/내역 반영 확인.
/// 아이콘은 Material Symbols 리거처(Text)라 접근성 라벨에 아이콘 이름이 섞이므로
/// 라벨 매칭은 CONTAINS 프레디킷을 사용한다.
final class CoreFlowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func button(containing label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
    }

    func testQuickAddExpenseFlowUpdatesHistory() {
        let app = XCUIApplication()
        app.launch()

        // 1. 대시보드 로드
        XCTAssertTrue(app.staticTexts["한눈에"].waitForExistence(timeout: 15), "대시보드가 뜨지 않음")

        // 2. FAB로 빠른 입력 시트 열기
        let fab = app.buttons["addTransaction"]
        XCTAssertTrue(fab.waitForExistence(timeout: 5), "추가(FAB) 버튼을 찾지 못함")
        fab.tap()
        XCTAssertTrue(app.staticTexts["새 지출"].waitForExistence(timeout: 5), "빠른 입력 시트가 열리지 않음")

        // 3. 금액 입력: 47,381 (기존 데이터와 충돌하지 않는 고유한 값)
        for key in ["4", "7", "3", "8", "1"] {
            let keypadKey = app.buttons[key]
            XCTAssertTrue(keypadKey.waitForExistence(timeout: 3), "키패드 \(key) 없음")
            keypadKey.tap()
        }
        XCTAssertTrue(app.staticTexts["47,381"].waitForExistence(timeout: 3), "금액 표시가 갱신되지 않음")

        // 4. 카테고리 선택(식비) — 시드 기본 카테고리
        let foodChip = button(containing: "식비", in: app)
        XCTAssertTrue(foodChip.waitForExistence(timeout: 5), "식비 카테고리 칩 없음")
        foodChip.tap()

        // 5. 저장
        let save = button(containing: "저장하기", in: app)
        XCTAssertTrue(save.waitForExistence(timeout: 3), "저장 버튼 없음")
        XCTAssertTrue(save.isEnabled, "저장 버튼이 비활성 상태")
        save.tap()

        // 6. 시트 닫힘 + 대시보드 복귀
        XCTAssertTrue(app.staticTexts["한눈에"].waitForExistence(timeout: 5), "저장 후 대시보드로 돌아오지 않음")

        // 7. 내역 탭에서 방금 저장한 거래 확인
        button(containing: "내역", in: app).tap()
        let saved = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "47,381")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5), "내역에 저장된 거래가 보이지 않음")
    }

    func testTabNavigationAndSettings() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["한눈에"].waitForExistence(timeout: 15))

        // 설정 탭
        button(containing: "설정", in: app).tap()
        let monthStartRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "월 시작일")).firstMatch
        XCTAssertTrue(monthStartRow.waitForExistence(timeout: 5), "설정 화면 항목이 보이지 않음")

        // 내역 탭
        button(containing: "내역", in: app).tap()
        XCTAssertTrue(app.staticTexts["내역"].waitForExistence(timeout: 5), "내역 화면이 보이지 않음")

        // 대시보드 복귀
        button(containing: "한눈에", in: app).tap()
        XCTAssertTrue(app.staticTexts["한눈에"].waitForExistence(timeout: 5))
    }
}
