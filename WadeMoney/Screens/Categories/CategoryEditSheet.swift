import SwiftUI

enum CategoryPalette {
    static let icons = ["restaurant","local_cafe","directions_bus","shopping_bag","movie","medical_services",
                        "home","category","flight","pets","fitness_center","school","card_giftcard","sports_esports",
                        "checkroom","local_gas_station","phone_iphone","savings"]
    static let colors = ["#E28A4E","#C4924E","#6F9FD8","#DB84AE","#D8AE45","#5DB794","#8E82CE","#A69B8C",
                         "#4DA0C4","#E0687A","#7BB661","#B072C4"]
}

struct CategoryEditSheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var icon: String
    @State private var color: String
    let isEditing: Bool
    let onSave: (String, String, String) -> Void
    let onArchive: (() -> Void)?

    init(editing item: CategoryManageViewModel.Item?, onSave: @escaping (String, String, String) -> Void, onArchive: (() -> Void)?) {
        _name = State(initialValue: item?.name ?? "")
        _icon = State(initialValue: item?.iconName ?? CategoryPalette.icons[0])
        _color = State(initialValue: item?.colorHex ?? CategoryPalette.colors[0])
        isEditing = item != nil
        self.onSave = onSave
        self.onArchive = onArchive
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(isEditing ? "카테고리 수정" : "새 카테고리").font(WadeFont.pretendard(20, weight: .heavy)).padding(.top, 16)
                // 미리보기 + 이름
                HStack(spacing: 12) {
                    Icon(icon, size: 24).foregroundStyle(Color(hex: color)).frame(width: 46, height: 46)
                        .background(Color(hex: color).opacity(0.15), in: RoundedRectangle(cornerRadius: WadeRadius.control))
                    TextField("이름", text: $name).font(WadeFont.pretendard(17, weight: .semibold))
                }
                sectionLabel("아이콘")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(CategoryPalette.icons, id: \.self) { name in
                        Button { icon = name } label: {
                            Icon(name, size: 20).foregroundStyle(icon == name ? Color(hex: color) : WadeColors.ink2(scheme))
                                .frame(width: 42, height: 42)
                                .background(icon == name ? Color(hex: color).opacity(0.15) : WadeColors.card2(scheme),
                                            in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                    }
                }
                sectionLabel("색")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(CategoryPalette.colors, id: \.self) { hex in
                        Button { color = hex } label: {
                            Circle().fill(Color(hex: hex)).frame(width: 36, height: 36)
                                .overlay(Circle().stroke(WadeColors.ink(scheme), lineWidth: color == hex ? 2 : 0))
                        }.buttonStyle(.plain)
                    }
                }
                Button {
                    onSave(name.trimmingCharacters(in: .whitespaces), icon, color); dismiss()
                } label: {
                    Text("저장").font(WadeFont.pretendard(17, weight: .heavy))
                        .foregroundStyle(canSave ? .white : WadeColors.ink3(scheme))
                        .frame(maxWidth: .infinity).padding(16)
                        .background(canSave ? WadeColors.primary(scheme) : WadeColors.track(scheme),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }.buttonStyle(.plain).disabled(!canSave)
                if let onArchive {
                    Button { onArchive(); dismiss() } label: {
                        Text("보관하기").font(WadeFont.pretendard(15, weight: .bold)).foregroundStyle(WadeColors.bad(scheme))
                            .frame(maxWidth: .infinity).padding(12)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 30)
        }
        .presentationDetents([.large])
        .background(WadeColors.sheet(scheme))
    }

    private func sectionLabel(_ t: String) -> some View {
        Text(t).font(WadeFont.pretendard(12.5, weight: .bold)).foregroundStyle(WadeColors.ink3(scheme))
    }
}
