//
//  MetaText.swift
//
//
//  Created by MainasuK Cirno on 2021-6-7.
//

import UIKit
import Meta
import AVFoundation
public protocol MetaTextDelegate: AnyObject {
    func metaText(_ metaText: MetaText, processEditing textStorage: MetaTextStorage) -> MetaContent?
}

public class MetaText: NSObject {

    public weak var delegate: MetaTextDelegate?

    public let layoutManager: MetaLayoutManager
    public let textStorage: MetaTextStorage
    public let textView: MetaTextView

    static var fontSize: CGFloat = 17
    static var tabStopIndent: CGFloat = 20

    public var paragraphStyle: NSMutableParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        style.paragraphSpacing = 4
        style.paragraphSpacingBefore = 4
        return style
    }()

    public var textAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: MetaText.fontSize, weight: .regular)),
        .foregroundColor: UIColor.label,
    ]

    public var linkAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: MetaText.fontSize, weight: .semibold)),
        .foregroundColor: UIColor.link,
    ]
    
    public override init() {
        let textStorage = MetaTextStorage()
        self.textStorage = textStorage

        let layoutManager = MetaLayoutManager()
        self.layoutManager = layoutManager
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: .zero)
        layoutManager.addTextContainer(textContainer)

        textView = MetaTextView(frame: .zero, textContainer: textContainer)
        layoutManager.hostView = textView

        super.init()

        textStorage.processDelegate = self
        layoutManager.delegate = self
    }
    
}

extension MetaText {

    public var backedString: String {
        let string = textStorage.string
        let nsString = NSMutableString(string: string)
        textStorage.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: textStorage.length),
            options: [.reverse])
        { value, range, _ in
            guard let attachment = value as? MetaAttachment else { return }
            nsString.replaceCharacters(in: range, with: attachment.string)
        }
        return nsString as String
    }

}

extension MetaText {

    public func configure(
        content: MetaContent,
        isRedactedModeEnabled: Bool = false
    ) {
        let attributedString = NSMutableAttributedString(string: content.string)

        layoutManager.isRedactedModeEnabled = isRedactedModeEnabled
        
        MetaText.setAttributes(
            for: attributedString,
            textAttributes: textAttributes,
            linkAttributes: linkAttributes,
            paragraphStyle: paragraphStyle,
            content: content
        )

        textView.linkTextAttributes = linkAttributes
        textView.attributedText = attributedString
    }

    public func reset() {
        let attributedString = NSAttributedString(string: "")
        textView.attributedText = attributedString
    }

}

// MARK: - MetaTextStorageDelegate
extension MetaText: MetaTextStorageDelegate {
    public func processEditing(_ textStorage: MetaTextStorage) -> MetaContent? {
        // note: check the attachment content view needs remove or not
        // "Select All" then delete text not call the `drawGlyphs` methold
        if textStorage.length == 0 {
            for view in textView.subviews where view.tag == MetaLayoutManager.displayAttachmentContentViewTag {
                view.removeFromSuperview()
            }
        }

        guard let content = delegate?.metaText(self, processEditing: textStorage) else { return nil }

        // configure meta
        textStorage.beginEditing()
        MetaText.setAttributes(
            for: textStorage,
            textAttributes: textAttributes,
            linkAttributes: linkAttributes,
            paragraphStyle: paragraphStyle,
            content: content
        )
        textStorage.endEditing()

        return content
    }
}

extension MetaText {

    @discardableResult
    public static func setAttributes(
        for attributedString: NSMutableAttributedString,
        textAttributes: [NSAttributedString.Key: Any],
        linkAttributes: [NSAttributedString.Key: Any],
        paragraphStyle: NSMutableParagraphStyle,
        content: MetaContent
    ) -> [MetaAttachment] {

        // clean up
        var allRange = NSRange(location: 0, length: attributedString.length)
        for key in textAttributes.keys {
            attributedString.removeAttribute(key, range: allRange)
        }
        for key in linkAttributes.keys {
            attributedString.removeAttribute(key, range: allRange)
        }
        attributedString.removeAttribute(.meta, range: allRange)
        attributedString.removeAttribute(.paragraphStyle, range: allRange)

        // text
        attributedString.addAttributes(
            textAttributes,
            range: NSRange(location: 0, length: attributedString.length)
        )


        // paragraph
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: allRange)

        // meta
        for entity in content.entities {
            switch entity.meta {
            case .url, .hashtag, .mention, .email, .emoji:
                var linkAttributes = linkAttributes
                linkAttributes[.meta] = entity.meta
                // FIXME: the emoji make cause wrong entity range out of bounds
                // workaround: use intersection range temporary
                let stringRange = NSRange(location: 0, length: attributedString.length)
                let validEntityRange = NSIntersectionRange(stringRange, entity.range)
                guard validEntityRange.length > 0 else { continue }
                attributedString.addAttributes(linkAttributes, range: validEntityRange)
            case .none:
                break
            case .formatted(_, let type):
                guard entity.range.length > 0 else { continue }
                let stringRange = NSRange(location: 0, length: attributedString.length)
                let validEntityRange = NSIntersectionRange(stringRange, entity.range)
                guard validEntityRange.length > 0 else { continue }
                attributedString.addAttribute(.meta, value: entity.meta, range: validEntityRange)
                guard let font = attributedString.attribute(.font, at: validEntityRange.location, effectiveRange: nil) as? UIFont
                else { continue }
                let descriptor = font.fontDescriptor
                let paragraphStyle = attributedString.attribute(.paragraphStyle, at: validEntityRange.location, effectiveRange: nil) as? NSParagraphStyle ?? paragraphStyle
                switch type {
                case .strong:
                    if let bold = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitBold)) {
                        attributedString.addAttribute(.font, value: UIFont(descriptor: bold, size: font.pointSize), range: validEntityRange)
                    }
                case .emphasized:
                    if let italic = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitItalic)) {
                        attributedString.addAttribute(.font, value: UIFont(descriptor: italic, size: font.pointSize), range: validEntityRange)
                    }
                case .underlined:
                    attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: validEntityRange)
                    if let underlineColor = textAttributes[.foregroundColor] as? UIColor {
                        attributedString.addAttribute(.underlineColor, value: underlineColor, range: validEntityRange)
                    }
                case .strikethrough:
                    attributedString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: validEntityRange)
                    if let strikethroughColor = textAttributes[.foregroundColor] as? UIColor {
                        attributedString.addAttribute(.strikethroughColor, value: strikethroughColor, range: validEntityRange)
                    }
                case .code:
                    if let monospaced = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitMonoSpace)) {
                        attributedString.addAttribute(.font, value: UIFont(descriptor: monospaced, size: font.pointSize), range: validEntityRange)
                    }
                    let paragraphStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                    // FIXME: excpet list
                    paragraphStyle.lineHeightMultiple = 0.8
                    paragraphStyle.lineSpacing = 0
                    attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: validEntityRange)
                case .blockquote:
                    // set indent
                    let paragraphStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                    paragraphStyle.firstLineHeadIndent = 10
                    paragraphStyle.headIndent = 10
                    attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: validEntityRange)
                    // set text color
                    if let foregroundColor = textAttributes[.foregroundColor] as? UIColor {
                        attributedString.addAttribute(.foregroundColor, value: foregroundColor.withAlphaComponent(0.5), range: validEntityRange)
                    }
                case .orderedList, .unorderedList:
                    let paragraphStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                    paragraphStyle.paragraphSpacing = 0
                    paragraphStyle.paragraphSpacingBefore = 0
                    // set tab stop
                    let terminator = NSTextTab.columnTerminators(for: .current)
                    paragraphStyle.tabStops = (0..<10).map { i -> NSTextTab in
                        NSTextTab(textAlignment: .left, location: MetaText.tabStopIndent * CGFloat(i), options: [.columnTerminators: terminator])
                    }
                    attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: validEntityRange)
                case .listItem(let indentLevel):
                    let paragraphStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                    // remove the spacing between list items
                    paragraphStyle.paragraphSpacing = 0
                    paragraphStyle.paragraphSpacingBefore = 0
                    paragraphStyle.headIndent = MetaText.tabStopIndent * CGFloat(indentLevel)
                    attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: validEntityRange)
                }
            }
        }

        // attachment
        // set after the text & meta then inject the attachment
        var replacedAttachments: [MetaAttachment] = []
        for entity in content.entities.reversed() {
            guard let attachment = content.metaAttachment(for: entity) else { continue }
            replacedAttachments.append(attachment)
            let stringRange = NSRange(location: 0, length: attributedString.length)
            let validEntityRange = NSIntersectionRange(stringRange, entity.range)
            guard validEntityRange.length > 0 else { continue }
            let font = attributedString.attribute(.font, at: validEntityRange.location, effectiveRange: nil) as? UIFont
            let fontSize = font?.pointSize ?? MetaText.fontSize
            attachment.bounds = CGRect(
                origin: CGPoint(x: 0, y: -floor(fontSize / 5)),  // magic descender
                size: CGSize(width: fontSize, height: fontSize)
            )

            // inject attachment via replace string at entity range
            attributedString.replaceCharacters(in: validEntityRange, with: NSAttributedString(attachment: attachment))
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: validEntityRange)
        }
        allRange = NSRange(location: 0, length: attributedString.length)

        return replacedAttachments
    }

}
