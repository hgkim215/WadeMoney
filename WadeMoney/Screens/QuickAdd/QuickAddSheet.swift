import SwiftUI
import SwiftData
import WadeMoneyCore

struct QuickAddSheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var vm: QuickAddViewModel?
    @State private var showingCategorySearch = false
    @State private var categoryQuery = ""
    let onSaved: () -> Void
    var editing: TransactionRecord? = nil
    var preselectedCategoryID: UUID? = nil

    var body: some View {
        Group {
            if let vm { content(vm) }
        }
        .onAppear {
            if vm == nil {
                vm = QuickAddViewModel(repository: LedgerRepository(context: modelContext), editing: editing, preselectedCategoryID: preselectedCategoryID)
            }
        }
        .presentationDetents([.large])
        .background(WadeColors.sheet(scheme))
    }

    private func content(_ vm: QuickAddViewModel) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Button { dismiss() } label: {
                        Icon("close", size: 20).foregroundStyle(WadeColors.ink2(scheme))
                    }.buttonStyle(.plain)
                    Text(vm.isEditing
                         ? (vm.type == .income ? "수입 수정" : "지출 수정")
                         : (vm.type == .income ? "새 수입" : "새 지출"))
                        .font(WadeFont.pretendard(20, weight: .heavy))
                    Spacer()
                    typeToggle(vm)
                }
                .padding(.top, 16)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("₩").font(WadeFont.pretendard(26, weight: .bold))
                    Text(vm.amountDigits.isEmpty ? "0" : Won.string(vm.amountDecimal))
                        .font(WadeFont.pretendard(52, weight: .heavy))
                }
                .foregroundStyle(vm.amountDecimal > 0
                    ? (vm.type == .income ? WadeColors.good(scheme) : WadeColors.ink(scheme))
                    : WadeColors.ink3(scheme))

                dateRow(vm)

                if !vm.isEditing { stepChips(vm) }

                if vm.type == .expense { categorySelector(vm) }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TextField("메모 (선택)", text: Binding(get: { vm.memo }, set: { vm.memo = $0 }))
                            .font(WadeFont.pretendard(14.5))
                        if vm.showsPolishButton || vm.hasPolished {
                            Button {
                                Task { await vm.polishMemo() }
                            } label: {
                                HStack(spacing: 4) {
                                    if vm.isPolishing {
                                        ProgressView().controlSize(.mini)
                                    } else {
                                        Icon("auto_awesome", size: 14)
                                    }
                                    Text(vm.hasPolished ? "정리됨" : "AI 다듬기").font(WadeFont.pretendard(11.5, weight: .bold))
                                }
                                .foregroundStyle(WadeColors.primary(scheme))
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(WadeColors.aitint2(scheme), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.isPolishing || vm.hasPolished)
                        }
                    }
                    .padding(13)
                    .background(WadeColors.card2(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.segment))

                    if let note = vm.polishNote {
                        Text(note).font(WadeFont.pretendard(11.5)).foregroundStyle(WadeColors.primary(scheme))
                    }
                }

                AmountKeypad(onKey: { vm.tapKey($0) }, onBackspace: { vm.backspace() })

                Button {
                    do {
                        try vm.save()
                        onSaved()
                        dismiss()
                    } catch {
                        // 저장 실패 시 시트를 닫지 않는다(성공을 가장하지 않음). 오류 토스트는 후속.
                    }
                } label: {
                    HStack(spacing: 6) { Icon("check", size: 22); Text("저장하기").font(WadeFont.pretendard(17, weight: .heavy)) }
                        .foregroundStyle(vm.canSave ? WadeColors.onPrimary(scheme) : WadeColors.ink3(scheme))
                        .frame(maxWidth: .infinity).padding(17)
                        .background(vm.canSave ? WadeColors.primary(scheme) : WadeColors.track(scheme),
                                    in: RoundedRectangle(cornerRadius: WadeRadius.button, style: .continuous))
                }
                .buttonStyle(.plain).disabled(!vm.canSave)
            }
            .padding(.horizontal, 24).padding(.bottom, 34)
        }
    }

    private func dateRow(_ vm: QuickAddViewModel) -> some View {
        HStack {
            Icon("event", size: 17, filled: false).foregroundStyle(WadeColors.ink3(scheme))
            Text("날짜").font(WadeFont.pretendard(13, weight: .semibold)).foregroundStyle(WadeColors.ink3(scheme))
            Spacer()
            DatePicker(
                "", selection: Binding(get: { vm.date }, set: { vm.date = $0 }),
                in: ...Date(), displayedComponents: [.date]
            )
            .labelsHidden()
            .tint(WadeColors.primary(scheme))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(WadeColors.card2(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.segment))
    }

    private func typeToggle(_ vm: QuickAddViewModel) -> some View {
        HStack(spacing: 3) {
            ForEach([TransactionKind.expense, .income], id: \.self) { t in
                Button { vm.type = t } label: {
                    Text(t == .expense ? "지출" : "수입")
                        .font(WadeFont.pretendard(12.5, weight: .bold))
                        .foregroundStyle(vm.type == t ? WadeColors.onPrimary(scheme) : WadeColors.ink2(scheme))
                        .padding(.horizontal, 15).padding(.vertical, 7)
                        .background(vm.type == t ? (t == .income ? WadeColors.good(scheme) : WadeColors.primary(scheme)) : .clear,
                                    in: Capsule())
                }.buttonStyle(.plain)
            }
        }
        .padding(3).background(WadeColors.card2(scheme), in: Capsule())
    }

    private func stepChips(_ vm: QuickAddViewModel) -> some View {
        let activeIndex: Int = {
            if vm.amountDigits.isEmpty { return 0 }
            if vm.type == .expense && vm.selectedCategoryID == nil { return 1 }
            return 2
        }()
        let steps: [(icon: String, label: String)] = [
            ("payments", "금액"),
            ("category", "카테고리"),
            ("check_circle", "저장")
        ]

        return HStack(spacing: 7) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                let hot = index <= activeIndex
                HStack(spacing: 5) {
                    Icon(step.icon, size: 15, filled: false)
                    Text(step.label).font(WadeFont.pretendard(11.5, weight: .bold))
                }
                .foregroundStyle(hot ? WadeColors.primary(scheme) : WadeColors.ink3(scheme))
                .padding(.horizontal, 11).padding(.vertical, 5)
                .background(hot ? WadeColors.primarysoft(scheme) : WadeColors.card2(scheme), in: Capsule())

                if index < steps.count - 1 {
                    Icon("chevron_right", size: 15, filled: false)
                        .foregroundStyle(WadeColors.ink3(scheme))
                }
            }
        }
        .padding(.bottom, 2)
    }

    private func categorySelector(_ vm: QuickAddViewModel) -> some View {
        let selected = selectedCategory(vm)
        let categories = filteredCategories(vm)
        let chipSpacing: CGFloat = 8

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("카테고리")
                    .font(WadeFont.pretendard(12.5, weight: .bold))
                    .foregroundStyle(WadeColors.ink3(scheme))
                Spacer()

                Text(selected?.name ?? "선택 필요")
                    .font(WadeFont.pretendard(12, weight: .bold))
                    .foregroundStyle(selected == nil ? WadeColors.ink3(scheme) : WadeColors.primary(scheme))

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showingCategorySearch.toggle()
                        if !showingCategorySearch { categoryQuery = "" }
                    }
                } label: {
                    Icon(showingCategorySearch ? "close" : "search", size: 17, filled: false)
                        .foregroundStyle(WadeColors.primary(scheme))
                        .frame(width: 30, height: 30)
                        .background(WadeColors.primarysoft(scheme), in: Circle())
                }
                .buttonStyle(.plain)
            }

            if showingCategorySearch {
                HStack(spacing: 9) {
                    Icon("search", size: 17, filled: false)
                        .foregroundStyle(WadeColors.ink3(scheme))
                    TextField("카테고리 검색", text: $categoryQuery)
                        .font(WadeFont.pretendard(14, weight: .semibold))
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(WadeColors.card2(scheme), in: RoundedRectangle(cornerRadius: WadeRadius.segment, style: .continuous))
            }

            if categories.isEmpty {
                Text("검색 결과가 없어요")
                    .font(WadeFont.pretendard(12.5, weight: .semibold))
                    .foregroundStyle(WadeColors.ink3(scheme))
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .padding(.top, 2)
            } else {
                GeometryReader { proxy in
                    let chipWidth = max(72, (proxy.size.width - chipSpacing * 3) / 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: chipSpacing) {
                            ForEach(categories) { cat in
                                CategoryChip(
                                    category: cat,
                                    isSelected: vm.selectedCategoryID == cat.id,
                                    width: chipWidth,
                                    action: { vm.selectedCategoryID = cat.id }
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .frame(height: 50)
            }
        }
    }

    private func selectedCategory(_ vm: QuickAddViewModel) -> CategoryRef? {
        guard let id = vm.selectedCategoryID else { return nil }
        return vm.categories.first { $0.id == id }
    }

    private func filteredCategories(_ vm: QuickAddViewModel) -> [CategoryRef] {
        let trimmed = categoryQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return vm.categories }
        return vm.categories.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}

private struct CategoryChip: View {
    @Environment(\.colorScheme) private var scheme
    let category: CategoryRef
    let isSelected: Bool
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Icon(category.iconName, size: 17)
                    .foregroundStyle(Color(hex: category.colorHex))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: category.colorHex).opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(category.name)
                    .font(WadeFont.pretendard(12.5, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? WadeColors.primary(scheme) : WadeColors.ink2(scheme))
            .frame(width: width, height: 44)
            .background(isSelected ? WadeColors.primarysoft(scheme) : WadeColors.card2(scheme),
                        in: RoundedRectangle(cornerRadius: WadeRadius.segment, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: WadeRadius.segment, style: .continuous)
                .stroke(isSelected ? WadeColors.primary(scheme) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

private struct CategoryIcon: View {
    let category: CategoryRef
    let size: CGFloat

    var body: some View {
        Icon(category.iconName, size: size * 0.5)
            .foregroundStyle(Color(hex: category.colorHex))
            .frame(width: size, height: size)
            .background(Color(hex: category.colorHex).opacity(0.13), in: RoundedRectangle(cornerRadius: WadeRadius.iconTile))
    }
}
