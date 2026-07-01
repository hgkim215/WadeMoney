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

    // TODO(cloudkit): CloudKit 동기화가 켜지면 두 번째 기기(또는 최초 동기화가
    // 끝나기 전의 같은 기기)는 로컬 스토어가 비어 있는 것으로 보고 자신만의 기본
    // 카테고리 8종을 또 시드할 수 있다. CloudKit은 유니크 제약을 지원하지 않으므로
    // 이후 두 기기의 변경 사항이 병합될 때 중복 카테고리가 생길 수 있다.
    // 완화책(실기기 CloudKit 도입 시 구현): AppSettingsModel에 "seeded" 플래그를
    // 두고 최초 동기화가 완료된 뒤에만 이를 확인해 시딩 여부를 판단하거나,
    // 다른 중복 제거 전략을 적용한다.
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
