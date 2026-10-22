//
//  ShaderPreviewView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/23.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ShaderPreviewView: RoundAndBorderView {
    private let imageView: ASIconView = {
        let view = ASIconView()
        view.backgroundColor = R.Color.BackgroundPrimary
        return view
    }()
    
    private lazy var changeImageButton: ASButtonView = {
        let view = ASButtonView(.smallIconButton(icon: .symbolImage(R.image.cover_iconSymbols()),
                                                 background: R.Color.BackgroundQuaternary))
        view.didTapButton = { [weak self] in
            guard let self else { return }
            ImageFetcher.showCommonFetcher(sources: [.capture, .library, .file],
                                           in: self.hostingWindowScene,
                                           completion: { [weak self] fetchImage, _ in
                guard let self, let fetchImage = fetchImage?.scaled(toSize: self.dimensions) else { return }
                self.image = fetchImage
            })
        }
        return view
    }()
    
    private var dimensions = CGSize(width: 200, height: 150)
    var image = R.image.shader_preview()! {
        didSet {
            updatePreview()
        }
    }
    var shader: Shader? {
        didSet {
            updatePreview()
        }
    }
    
    init(dimensions: CGSize? = nil, image: UIImage? = nil, shader: Shader? = nil) {
        super.init(roundCorner: .allCorners, borderColor: .clear)
        
        backgroundColor = R.Color.BackgroundSecondary
        
        if let dimensions {
            self.dimensions = dimensions
        }
        
        if let image {
            self.image = image
        }
        
        if let shader {
            self.shader = shader
        }
        
        addSubview(imageView)
        
        addSubview(changeImageButton)
        changeImageButton.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(R.Size.ContentSpaceExtraSmall)
        }
        
        updatePreview()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.snp.remakeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(imageView.snp.height).multipliedBy(self.dimensions.width/self.dimensions.height)
            if size.IsRelativelyWideRectangle {
                make.top.bottom.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            } else {
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            }
        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updatePreview() {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            if let shader = self.shader,
               !shader.isOriginal,
               let shaderImage = LibretroCore.previewImage(with: self.image, shaderPath: shader.filePath) {
                DispatchQueue.main.async { [weak self] in
                    self?.imageView.icon = .image(shaderImage,
                                                  cornerStyle: .radius(R.Size.CornerRadiusSmall))
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.imageView.icon = .image(self.image,
                                                 cornerStyle: .radius(R.Size.CornerRadiusSmall))
                }
            }
        }
    }
}
