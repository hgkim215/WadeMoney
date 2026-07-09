import Foundation
import SwiftData
import WidgetKit
import WadeMoneyCore

/// 같은 이름의 카테고리를 또 만들려 할 때 던진다 — UI가 사전 차단하는 게 원칙이고 이건 마지막 방어선.
struct DuplicateCategoryNameError: Error {}

@MainActor
final class CategoryStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    private func models(archived: Bool) throws -> [CategoryModel] {
        try context.fetch(FetchDescriptor<CategoryModel>(sortBy: [SortDescriptor(\.sortOrder)]))
            .filter { $0.isArchived == archived }
    }

    func active() throws -> [CategoryRef] { try models(archived: false).map { $0.toRef() } }
    func archived() throws -> [CategoryRef] { try models(archived: true).map { $0.toRef() } }

    /// 보관된 카테고리까지 포함해 같은 이름(공백 무시)이 이미 있는지. `excluding`은 수정 중인 자기 자신.
    func isNameTaken(_ name: String, excluding: UUID? = nil) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let all = (try? context.fetch(FetchDescriptor<CategoryModel>())) ?? []
        return all.contains { $0.id != excluding && $0.name.trimmingCharacters(in: .whitespaces) == trimmed }
    }

    func add(name: String, iconName: String, colorHex: String) throws {
        guard !isNameTaken(name) else { throw DuplicateCategoryNameError() }
        let maxOrder = try context.fetch(FetchDescriptor<CategoryModel>())
            .map(\.sortOrder).max() ?? -1
        context.insert(CategoryModel(name: name, iconName: iconName, colorHex: colorHex, sortOrder: maxOrder + 1))
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func update(id: UUID, name: String, iconName: String, colorHex: String) throws {
        guard !isNameTaken(name, excluding: id) else { throw DuplicateCategoryNameError() }
        guard let m = try model(id) else { return }
        m.name = name
        m.iconName = iconName
        m.colorHex = colorHex
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func archive(id: UUID) throws {
        guard let m = try model(id) else { return }
        m.isArchived = true
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 이 카테고리를 참조하는 거래가 전체 기간(이번 달뿐 아니라 과거 전체) 통틀어 하나도 없는지.
    /// 참으로 나올 때만 하드 삭제를 허용해 과거 통계 무결성을 지킨다.
    func isUnused(_ id: UUID) throws -> Bool {
        try context.fetchCount(FetchDescriptor<TransactionModel>(predicate: #Predicate { $0.category?.id == id })) == 0
    }

    /// 실수로 만든, 한 번도 쓰이지 않은 카테고리를 즉시 삭제한다(보관 없이).
    /// 거래 기록이 있는 카테고리는 archive(_:)만 허용 — 과거 도넛·통계가 카테고리를 잃지 않도록.
    func delete(id: UUID) throws {
        guard try isUnused(id), let m = try model(id) else { return }
        context.delete(m)
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func restore(id: UUID) throws {
        guard let m = try model(id) else { return }
        m.isArchived = false
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func reorder(_ orderedIDs: [UUID]) throws {
        let all = try context.fetch(FetchDescriptor<CategoryModel>())
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        for (index, id) in orderedIDs.enumerated() {
            byID[id]?.sortOrder = index
        }
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func model(_ id: UUID) throws -> CategoryModel? {
        try context.fetch(FetchDescriptor<CategoryModel>(predicate: #Predicate { $0.id == id })).first
    }
}
