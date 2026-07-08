import Foundation
import SwiftData

struct SeedCategory {
    let name: String
    let iconName: String
    let colorHex: String
}

@MainActor
enum CategorySeeder {
    /// 디자인 시스템 §6 기본 카테고리(노출 순서와 무관한 시드 순서 = sortOrder 0..7).
    static let defaults: [SeedCategory] = [
        SeedCategory(name: "식비", iconName: "restaurant",       colorHex: "#E28A4E"),
        SeedCategory(name: "카페", iconName: "local_cafe",        colorHex: "#C4924E"),
        SeedCategory(name: "교통", iconName: "directions_bus",    colorHex: "#6F9FD8"),
        SeedCategory(name: "쇼핑", iconName: "shopping_bag",      colorHex: "#DB84AE"),
        SeedCategory(name: "문화", iconName: "movie",             colorHex: "#D8AE45"),
        SeedCategory(name: "의료", iconName: "medical_services",  colorHex: "#5DB794"),
        SeedCategory(name: "주거", iconName: "home",              colorHex: "#8E82CE"),
        SeedCategory(name: "기타", iconName: "category",          colorHex: "#A69B8C"),
    ]

    /// 카테고리가 하나도 없을 때만 기본 8종을 삽입한다(멱등).
    /// AppSettingsModel.didSeedDefaultCategories 플래그가 CloudKit으로 동기화되므로,
    /// 다른 기기가 이미 시드했다면(플래그가 먼저 내려온 경우) 로컬에 카테고리가 아직
    /// 안 보여도 재시드하지 않는다 — 최초 동기화 완료 전 중복 시드 경쟁을 완화한다.
    static func seedIfNeeded(_ context: ModelContext) throws {
        let settings = try fetchOrCreateSettings(context)
        guard !settings.didSeedDefaultCategories else { return }

        let existing = try context.fetchCount(FetchDescriptor<CategoryModel>())
        if existing == 0 {
            for (index, seed) in defaults.enumerated() {
                context.insert(CategoryModel(
                    name: seed.name,
                    iconName: seed.iconName,
                    colorHex: seed.colorHex,
                    sortOrder: index
                ))
            }
        }
        // existing > 0인데 플래그가 없는 경우(구버전에서 이미 시드된 사용자) — 시드하지 않고 플래그만 세운다.
        settings.didSeedDefaultCategories = true
        try context.save()
    }

    private static func fetchOrCreateSettings(_ context: ModelContext) throws -> AppSettingsModel {
        // SettingsStore와 같은 결정적 선택 규칙(중복 행 치유 포함)을 쓴다.
        try SettingsStore(context: context).settingsModel()
    }

    /// 여러 기기가 CloudKit으로 병합되면 같은 카테고리가 중복 생성될 수 있다(기본 카테고리든 커스텀 카테고리든).
    /// 이름만 비교하면 리네임으로 이름이 겹친 별개 카테고리까지 삭제(비가역 손실)될 수 있으므로,
    /// 이름+아이콘+색상이 모두 같은 진짜 중복만 id 최솟값 행으로 결정적으로 합치고(거래 재연결) 나머지를 지운다.
    /// 모든 기기가 같은 승자를 고르므로 동기화 후 상태가 수렴한다. 멱등 — 매 실행 시 호출해도 안전.
    static func reconcileDuplicateCategories(_ context: ModelContext) throws {
        struct DedupKey: Hashable {
            let name: String
            let iconName: String
            let colorHex: String
        }
        let all = try context.fetch(FetchDescriptor<CategoryModel>())
        let grouped = Dictionary(grouping: all) {
            DedupKey(name: $0.name, iconName: $0.iconName, colorHex: $0.colorHex)
        }

        var changed = false
        for (_, rows) in grouped where rows.count > 1 {
            let sorted = rows.sorted { $0.id < $1.id }
            let winner = sorted[0]
            for loser in sorted.dropFirst() {
                let loserID = loser.id
                let orphans = try context.fetch(
                    FetchDescriptor<TransactionModel>(predicate: #Predicate { $0.category?.id == loserID })
                )
                for txn in orphans { txn.category = winner }
                context.delete(loser)
                changed = true
            }
        }
        if changed { try context.save() }
    }
}
