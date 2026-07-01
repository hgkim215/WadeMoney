import SwiftUI

/// Task 7에서 실제 빠른 입력 시트로 교체될 스텁.
struct QuickAddSheet: View {
    let onSaved: () -> Void
    var body: some View {
        Text("빠른 입력")
    }
}
