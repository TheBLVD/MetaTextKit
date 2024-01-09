//
//  Meta.swift
//  
//
//  Created by MainasuK Cirno on 2021-6-7.
//

import Foundation

public enum Meta {
    case url(_ text: String, trimmed: String, url: String, userInfo: [AnyHashable: Any]? = nil)
    case hashtag(_ text: String, hashtag: String, userInfo: [AnyHashable: Any]? = nil)
    case mention(_ text: String, mention: String, userInfo: [AnyHashable: Any]? = nil)
    case email(_ text: String, userInfo: [AnyHashable: Any]? = nil)
    case emoji(_ text: String, shortcode: String, url: String, userInfo: [AnyHashable: Any]? = nil)
    case formatted(_ text: String, FormatType)
    case none
}

extension Meta {
    
    public enum FormatType {
        case strong // e.g. bold
        case emphasized // e.g. italic
        case underlined
        case strikethrough
        case code
        case blockquote
        case orderedList
        case unorderedList
        case listItem(indentLevel: Int)
    }
    
}

extension Meta {
    public var primaryText: String {
        switch self {
        case .url(let text, _, _, _):      return text
        case .emoji(let text, _, _, _):    return text
        case .hashtag(let text, _, _):     return text
        case .mention(let text, _, _):     return text
        case .email(let text, _):          return text
        case .formatted(let text, _):      return text
        case .none:                        return ""
        }
    }

    public static func trim(content: String, orderedEntities: [Meta.Entity]) -> String {
        var content = content
        for entity in orderedEntities {
            Meta.trim(content: &content, entity: entity, entities: orderedEntities)
        }
        return content
    }

    static func trim(content: inout String, entity: Meta.Entity, entities: [Meta.Entity]) {
        let text: String
        let trimmed: String
        switch entity.meta {
        case .url(let _text, let _trimmed, _, _):
            text = _text
            trimmed = _trimmed
        case .emoji(let _text, _, _, _):
            text = _text
            trimmed = " "
        default:
            return
        }

        guard let index = entities.firstIndex(where: { $0.range == entity.range }) else { return }
        guard let range = Range(entity.range, in: content) else { return }
        content.replaceSubrange(range, with: trimmed)

        let offset = trimmed.count - text.count
        entity.range.length += offset

        let moveEntities = Array(entities[index...].dropFirst())
        for moveEntity in moveEntities {
            moveEntity.range.location += offset
        }
    }
}

extension Meta: CustomDebugStringConvertible {
    private var kind: String {
        switch self {
        case .url: return "URL"
        case .hashtag: return "hashtag"
        case .mention: return "mention"
        case .email: return "email"
        case .emoji: return "emoji"
        case .formatted(_, let formatType): return "formatted.\(formatType)"
        case .none: return "none"
        }
    }
    
    public var debugDescription: String {
        let encodedContent = primaryText.rawRepresent
        return "\(kind): \(encodedContent)"
    }
}
