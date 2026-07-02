import Foundation
import SwiftData
import WidgetKit
import WadeMoneyCore

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

    func add(name: String, iconName: String, colorHex: String) throws {
        let maxOrder = try context.fetch(FetchDescriptor<CategoryModel>())
            .map(\.sortOrder).max() ?? -1
        context.insert(CategoryModel(name: name, iconName: iconName, colorHex: colorHex, sortOrder: maxOrder + 1))
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func update(id: UUID, name: String, iconName: String, colorHex: String) throws {
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
