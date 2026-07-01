import Foundation
import SwiftData

struct SeedCategory {
    let name: String
    let iconName: String
    let colorHex: String
}

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
    static func seedIfNeeded(_ context: ModelContext) throws {
        let existing = try context.fetchCount(FetchDescriptor<CategoryModel>())
        guard existing == 0 else { return }

        for (index, seed) in defaults.enumerated() {
            context.insert(CategoryModel(
                name: seed.name,
                iconName: seed.iconName,
                colorHex: seed.colorHex,
                sortOrder: index
            ))
        }
        try context.save()
    }
}
