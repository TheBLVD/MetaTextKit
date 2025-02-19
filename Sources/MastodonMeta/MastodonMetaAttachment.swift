//
//  MastodonMetaAttachment.swift
//  
//
//  Created by Cirno MainasuK on 2021-6-26.
//

import os.log
import UIKit
import Combine
import UniformTypeIdentifiers
import SDWebImage
import Meta

public class MastodonMetaAttachment: NSTextAttachment, MetaAttachment {

    public var disposeBag = Set<AnyCancellable>()

    static let placeholderImage: UIImage = {
        let size = CGSize(width: 1, height: 1)
        return UIGraphicsImageRenderer(size: size).image { context in
            context.cgContext.setFillColor(UIColor.clear.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }
    }()


    let logger = Logger(subsystem: "MastodonMetaAttachment", category: "UI")

    public let string: String
    public let url: String
    public let content: UIView
    public var contentFrame: CGRect = .zero

    var imageView: SDAnimatedImageView? {
        return content as? SDAnimatedImageView
    }

    public init(string: String, url: String, content: UIView) {
        self.string = string
        self.url = url
        self.content = content
        super.init(data: nil, ofType: UTType.image.identifier)

        image = MastodonMetaAttachment.placeholderImage
    }

    public override func image(forBounds imageBounds: CGRect, textContainer: NSTextContainer?, characterIndex charIndex: Int) -> UIImage? {
        contentFrame = imageBounds

        imageView?.contentMode = .scaleAspectFit
        imageView?.sd_setImage(
            with: URL(string: url),
            placeholderImage: nil,
            options: .preloadAllFrames,
            progress: nil
        ) { [weak self] image, error, cacheType, url in
            guard let self = self else { return }
            guard let image = image else { return }
            guard let totalFrameCount = self.imageView?.player?.totalFrameCount, totalFrameCount > 1
            else {
                // resize transformer not works for APNG
                // force resize for single frame animated image
                let scale: CGFloat = 3
                let size = CGSize(width: ceil(imageBounds.size.width * scale), height: ceil(imageBounds.size.height * scale))
                self.imageView?.image = image.sd_resizedImage(with: size, scaleMode: .aspectFit)
                return
            }
        }
        
        return super.image(forBounds: imageBounds, textContainer: textContainer, characterIndex: charIndex)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

