import SwiftUI
import SwiftData

struct CategoryManageScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode
    @State private var viewModel: CategoryManageViewModel?
    @State private var editingItem: CategoryManageViewModel.Item?
    @State private var pendingDeleteItem: CategoryManageViewModel.Item?
    @State private var showNew = false

    private var isEditingList: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                VStack(spacing: 0) {
                    topBar

                    List {
                        Section("사용 중") {
                            ForEach(vm.activeItems) { item in
                                activeRow(item, vm: vm)
                            }
                            .onMove { source, destination in
                                withAnimation(.snappy(duration: 0.2)) {
                                    vm.move(from: source, to: destination)
                                }
                            }
                            .moveDisabled(!isEditingList)
                        }
                        if !vm.archivedItems.isEmpty {
                            Section("보관됨") {
                                ForEach(vm.archivedItems) { item in
                                    archivedRow(item, vm: vm)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: WadeSpacing.contentBottom) }
                }
                .background(WadeColors.bg(scheme))
            } else {
                // vm 로드 전에도 destination이 빈 뷰가 되지 않도록(비어 있으면 NavigationStack이
                // onAppear를 발화하지 않아 영원히 로드되지 않는 문제 회피).
                ProgressView()
            }
        }
        .navigationTitle("카테고리 관리")
        .sheet(item: $editingItem) { item in
            CategoryEditSheet(editing: item,
                              isNameTaken: { viewModel?.isNameTaken($0, excluding: item.id) ?? false },
                              onSave: { n, i, c in viewModel?.update(id: item.id, name: n, iconName: i, colorHex: c) },
                              onRemove: { remove(item, vm: viewModel) })
        }
        .sheet(isPresented: $showNew) {
            CategoryEditSheet(editing: nil,
                              isNameTaken: { viewModel?.isNameTaken($0) ?? false },
                              onSave: { n, i, c in viewModel?.add(name: n, iconName: i, colorHex: c) },
                              onRemove: nil)
        }
        .alert("카테고리를 삭제할까요?", isPresented: Binding(
            get: { pendingDeleteItem != nil },
            set: { if !$0 { pendingDeleteItem = nil } }
        )) {
            Button("삭제", role: .destructive) {
                if let item = pendingDeleteItem {
                    viewModel?.delete(id: item.id)
                }
                pendingDeleteItem = nil
            }
            Button("취소", role: .cancel) { pendingDeleteItem = nil }
        } message: {
            Text("\(pendingDeleteItem?.name ?? "이 카테고리")는 복원할 수 없어요.")
        }
        .onAppear {
            if viewModel == nil {
                let ctx = modelContext
                let vm = CategoryManageViewModel(categoryStore: CategoryStore(context: ctx),
                                                 repository: LedgerRepository(context: ctx),
                                                 now: Date(), calendar: .current)
                vm.load(); viewModel = vm
            }
        }
        .navigationBarBackButtonHidden(true)
        .enableSwipeBack { dismiss() }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        ZStack {
            Text("카테고리 관리")
                .font(WadeFont.pretendard(17, weight: .heavy))
                .foregroundStyle(WadeColors.ink(scheme))

            HStack {
                Button { dismiss() } label: {
                    Icon("chevron_left", size: 24, filled: false)
                        .foregroundStyle(WadeColors.ink(scheme))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로")

                Spacer()

                HStack(spacing: 14) {
                    topBarIconButton(isEditingList ? "check" : "edit",
                                     label: isEditingList ? "편집 완료" : "편집",
                                     isActive: isEditingList) {
                        withAnimation(.snappy(duration: 0.18)) {
                            editMode?.wrappedValue = isEditingList ? .inactive : .active
                        }
                    }
                    topBarIconButton("add", label: "카테고리 추가") {
                        showNew = true
                    }
                }
            }
        }
        .padding(.horizontal, WadeSpacing.screenH)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func topBarIconButton(_ icon: String, label: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(icon, size: 20, filled: icon != "edit")
                .foregroundStyle(isActive ? WadeColors.primary(scheme) : WadeColors.ink2(scheme))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func activeRow(_ item: CategoryManageViewModel.Item, vm: CategoryManageViewModel) -> some View {
        HStack(spacing: 12) {
            if isEditingList {
                rowContent(item)
            } else {
                Button { editingItem = item } label: {
                    rowContent(item)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 12)

            if isEditingList {
                destructiveActionButton(item.canDelete ? "삭제" : "보관",
                                        icon: item.canDelete ? "delete" : "archive") {
                    requestRemove(item, vm: vm)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .animation(.snappy(duration: 0.18), value: isEditingList)
    }

    private func archivedRow(_ item: CategoryManageViewModel.Item, vm: CategoryManageViewModel) -> some View {
        HStack(spacing: 12) {
            rowContent(item)
                .opacity(0.6)

            Spacer(minLength: 12)

            if isEditingList {
                HStack(spacing: 8) {
                    if item.canDelete {
                        destructiveActionButton("삭제", icon: "delete") {
                            pendingDeleteItem = item
                        }
                    }
                    actionButton("복원", icon: "unarchive") {
                        vm.restore(id: item.id)
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .animation(.snappy(duration: 0.18), value: isEditingList)
    }

    private func requestRemove(_ item: CategoryManageViewModel.Item, vm: CategoryManageViewModel) {
        if item.canDelete {
            pendingDeleteItem = item
        } else {
            vm.archive(id: item.id)
        }
    }

    private func remove(_ item: CategoryManageViewModel.Item, vm: CategoryManageViewModel?) {
        guard let vm else { return }
        if item.canDelete {
            vm.delete(id: item.id)
        } else {
            vm.archive(id: item.id)
        }
    }

    private func rowContent(_ item: CategoryManageViewModel.Item) -> some View {
        HStack(spacing: 13) {
            Icon(item.iconName, size: 20).foregroundStyle(Color(hex: item.colorHex)).frame(width: 36, height: 36)
                .background(Color(hex: item.colorHex).opacity(0.15), in: RoundedRectangle(cornerRadius: WadeRadius.smallTile))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(WadeFont.pretendard(15, weight: .semibold)).foregroundStyle(WadeColors.ink(scheme))
                Text(item.usageText).font(WadeFont.pretendard(11.5)).foregroundStyle(WadeColors.ink3(scheme))
            }
        }
    }

    private func destructiveActionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            HStack(spacing: 5) {
                Icon(icon, size: 14, filled: false)
                Text(title)
                    .font(WadeFont.pretendard(12.5, weight: .bold))
            }
            .foregroundStyle(WadeColors.bad(scheme))
            .frame(minWidth: 54, minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Icon(icon, size: 14, filled: false)
                Text(title)
                    .font(WadeFont.pretendard(12.5, weight: .bold))
            }
            .foregroundStyle(WadeColors.primary(scheme))
            .frame(minWidth: 54, minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
