//
//  ReaderWebtoonCollectionViewCell.swift
//  Aidoku (iOS)
//
//  Created by Skitty on 9/27/22.
//

import UIKit

class ReaderWebtoonCollectionViewCell: UICollectionViewCell {

    static let estimatedHeight: CGFloat = 300

    let pageView = ReaderPageView()
    var page: Page?
    private var sourceId: String?

    var infoPageType: ReaderPageViewController.InfoPageType?
    var infoView: ReaderInfoPageView?

    lazy var reloadButton = UIButton(type: .roundedRect)

    override init(frame: CGRect) {
        super.init(frame: frame)

        pageView.maxWidth = true
        pageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pageView)

        reloadButton.isHidden = true
        reloadButton.setTitle(NSLocalizedString("RELOAD", comment: ""), for: .normal)
        reloadButton.addTarget(self, action: #selector(reload), for: .touchUpInside)
        reloadButton.contentEdgeInsets = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        reloadButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(reloadButton)

        let pageHeight1 = pageView.heightAnchor.constraint(equalTo: heightAnchor)
        let pageHeight2 = pageView.heightAnchor.constraint(equalTo: pageView.imageView.heightAnchor)
        let pageHeight3 = pageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 1)
        pageHeight1.priority = UILayoutPriority(5)
        pageHeight2.priority = UILayoutPriority(10)
        pageHeight3.priority = UILayoutPriority(15)

        NSLayoutConstraint.activate([
            pageView.topAnchor.constraint(equalTo: topAnchor),
            pageView.widthAnchor.constraint(equalTo: widthAnchor),
            pageHeight1, pageHeight2, pageHeight3,

            reloadButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            reloadButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        pageView.imageView.image = nil
        reloadButton.isHidden = true
        pageView.imageTask = nil
    }

    func setPage(page: Page) {
        self.page = page
    }

    func loadPage(sourceId: String? = nil) async {
        guard let page = page, page.type == .imagePage else { return }
        self.sourceId = sourceId
        reloadButton.isHidden = true
        infoView?.isHidden = true
        pageView.isHidden = false
        let success = await pageView.setPage(page, sourceId: sourceId)
        reloadButton.isHidden = success
    }

    func loadInfo(prevChapter: Chapter?, nextChapter: Chapter?) {
        guard let page = page, page.type != .imagePage else { return }
        if infoView == nil {
            let infoView = ReaderInfoPageView(type: page.type == .prevInfoPage ? .previous : .next)
            infoView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(infoView)
            NSLayoutConstraint.activate([
                infoView.topAnchor.constraint(equalTo: topAnchor),
                infoView.leftAnchor.constraint(equalTo: leftAnchor),
                infoView.rightAnchor.constraint(equalTo: rightAnchor),
                infoView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            self.infoView = infoView
        } else if (page.type == .prevInfoPage && infoView?.type != .previous) || (page.type == .nextInfoPage && infoView?.type != .next) {
            infoView?.type = page.type == .prevInfoPage ? .previous : .next
        }
        infoView?.isHidden = false
        pageView.isHidden = true
        if page.type == .prevInfoPage {
            infoView?.previousChapter = prevChapter
            infoView?.currentChapter = nextChapter
            infoView?.nextChapter = nil
        } else {
            infoView?.previousChapter = nil
            infoView?.currentChapter = prevChapter
            infoView?.nextChapter = nextChapter
        }
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let fallback = CGSize(
            width: bounds.width != 0 ? bounds.width : UIScreen.main.bounds.width,
            height: Self.estimatedHeight
        )

        if page?.type != .imagePage {
            layoutAttributes.size = fallback
        } else {
            if let image = pageView.imageView.image, image.size.width > 0 {
                let multiplier = image.size.height / image.size.width
                let size = CGSize(width: bounds.width, height: bounds.width * multiplier)
                if size.height > 0 {
                    layoutAttributes.size = size
                } else {
                    layoutAttributes.size = fallback
                }
            } else {
                layoutAttributes.size = fallback
            }
        }

        return layoutAttributes
    }

    @objc func reload() {
        Task {
            await loadPage(sourceId: sourceId)
        }
    }
}
