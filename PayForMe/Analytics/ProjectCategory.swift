//
//  ProjectCategory.swift
//  Umlage
//
//  Cospend lets a project define its own expense categories (name + emoji +
//  colour). We read them straight off the server instead of shipping a
//  hardcoded table, so a renamed or custom category never shows up under the
//  wrong label in the statistics screen.
//
//  iHateMoney has no categories; for those projects the dictionary stays empty
//  and the category section of the statistics screen hides itself.
//

import Foundation

struct ProjectCategory: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    /// Emoji as stored by Cospend, e.g. "🛒". May be empty.
    let icon: String
    /// Hex string as stored by Cospend, e.g. "#ffaa22". May be empty.
    let color: String

    static let uncategorizedName = NSLocalizedString("stats_uncategorized", comment: "Bills without a category")

    /// The API sends `id` as a number, but `icon`/`color` are nullable and
    /// `name` occasionally arrives as an empty string. Decoding defensively
    /// keeps one odd category from throwing away the whole payload.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = intId
        } else if let stringId = try? container.decode(String.self, forKey: .id), let parsed = Int(stringId) {
            id = parsed
        } else {
            id = 0
        }
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        icon = (try? container.decode(String.self, forKey: .icon)) ?? ""
        color = (try? container.decode(String.self, forKey: .color)) ?? ""
    }

    init(id: Int, name: String, icon: String = "", color: String = "") {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
    }
}

/// Minimal view of the Cospend project payload. We only care about the
/// `categories` map (keyed by category id as a *string*) and the currency name.
struct ProjectMetadataResponse: Decodable {
    let categories: [Int: ProjectCategory]
    /// Free-text currency label configured in Cospend, e.g. "€". Empty when the
    /// project has none — we render bare numbers rather than guessing a symbol.
    let currencyName: String

    private enum CodingKeys: String, CodingKey {
        case categories
        case currencyname
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = (try? container.decode([String: ProjectCategory].self, forKey: .categories)) ?? [:]

        var mapped: [Int: ProjectCategory] = [:]
        for (key, value) in raw {
            // Prefer the id inside the object; fall back to the dictionary key.
            let id = value.id != 0 ? value.id : (Int(key) ?? 0)
            mapped[id] = ProjectCategory(id: id,
                                         name: value.name.isEmpty ? ProjectCategory.uncategorizedName : value.name,
                                         icon: value.icon,
                                         color: value.color)
        }
        categories = mapped
        currencyName = ((try? container.decode(String.self, forKey: .currencyname)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
