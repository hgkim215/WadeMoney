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
        if let existing = try context.fetch(FetchDescriptor<AppSettingsModel>()).first {
            return existing
        }
        let created = AppSettingsModel()
        context.insert(created)
        return created
    }
}
