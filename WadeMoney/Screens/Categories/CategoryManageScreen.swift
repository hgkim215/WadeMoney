import SwiftUI
import SwiftData

struct CategoryManageScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: CategoryManageViewModel?
    @State private var editingItem: CategoryManageViewModel.Item?
    @State private var showNew = false

    var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    Section("사용 중") {
                        ForEach(vm.activeItems) { item in
                            Button { editingItem = item } label: { rowContent(item) }.buttonStyle(.plain)
                        }
                        .onMove { vm.move(from: $0, to: $1) }
                    }
                    if !vm.archivedItems.isEmpty {
                        Section("보관됨") {
                            ForEach(vm.archivedItems) { item in
                                HStack {
                                    rowContent(item).opacity(0.6)
                                    Spacer()
                                    Button("복원") { vm.restore(id: item.id) }
                                        .font(WadeFont.pretendard(12, weight: .bold)).foregroundStyle(WadeColors.ink2(scheme))
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(WadeColors.bg(scheme))
            } else {
                // vm 로드 전에도 destination이 빈 뷰가 되지 않도록(비어 있으면 NavigationStack이
                // onAppear를 발화하지 않아 영원히 로드되지 않는 문제 회피).
                ProgressView()
            }
        }
        .navigationTitle("카테고리 관리")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) { Button { showNew = true } label: { Icon("add", size: 22) } }
        }
        .sheet(item: $editingItem) { item in
            CategoryEditSheet(editing: item,
                              onSave: { n, i, c in viewModel?.update(id: item.id, name: n, iconName: i, colorHex: c) },
                              onArchive: { viewModel?.archive(id: item.id) })
        }
        .sheet(isPresented: $showNew) {
            CategoryEditSheet(editing: nil,
                              onSave: { n, i, c in viewModel?.add(name: n, iconName: i, colorHex: c) },
                              onArchive: nil)
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
}
