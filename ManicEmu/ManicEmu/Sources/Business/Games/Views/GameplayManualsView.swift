//
//  GameplayManualsView.swift
//  ManicEmu
//
//  Created by Aoshuang on 2025/10/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
import PDFKit
import UniformTypeIdentifiers

class GameplayManualsView: BaseView {
    private var game: Game
    private var hideCompletion: (() -> Void)? = nil
    
    private lazy var navigationView: ASNavigationView = {
        let view = ASNavigationView(.defaultNavigation(title: game.displayName,
                                                       titleIcon: .symbolImage(R.image.introduction_iconSymbols()),
                                                       tools: [
                                                        .symbolImage(R.image.delete_iconSymbols(), colors: [R.Color.Red]),
                                                        .symbolImage(R.image.folder_iconSymbols())
                                                       ]))
        view.didTapClose = { [weak self] in
            guard let self else { return }
            // 记录当前阅读的页数
            if let currentPage = self.pdfView.currentPage, let document = self.pdfView.document {
                let pageIndex = document.index(for: currentPage)
                self.game.updateExtra(key: ExtraKey.manualPage.rawValue, value: pageIndex)
            }
            // 记录当前的缩放比例
            self.game.updateExtra(key: ExtraKey.manualScaleFactor.rawValue, value: self.pdfView.scaleFactor)
            self.hide()
        }
        
        view.didTapTools = { [weak self] index in
            guard let self else { return }
            if index == 0 {
                //remove
                if let manualsPath = game.manualsPath {
                    try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.GameplayManuals.appendingPathComponent(manualsPath)))
                    self.game.updateExtra(key: ExtraKey.manualPage.rawValue, value: nil)
                    self.game.updateExtra(key: ExtraKey.manualFileName.rawValue, value: nil)
                    self.game.updateExtra(key: ExtraKey.manualScaleFactor.rawValue, value: nil)
                    self.hide()
                }
            } else if index == 1 {
                //add pdf
                FilesImporter.shared.presentImportController(supportedTypes: [UTType.pdf],
                                                             allowsMultipleSelection: false,
                                                             manualHandle: { [weak self] urls in
                    guard let self else { return }
                    if let pdfUrl = urls.first {
                        do {
                            let pdfName = pdfUrl.lastPathComponent
                            let manualsPath = URL(fileURLWithPath: R.Path.GameplayManuals.appendingPathComponent(pdfName))
                            try FileManager.safeCopyItem(at: pdfUrl, to: manualsPath, shouldReplace: true)
                            self.game.updateExtra(key: ExtraKey.manualPage.rawValue, value: nil)
                            self.game.updateExtra(key: ExtraKey.manualScaleFactor.rawValue, value: nil)
                            self.game.updateExtra(key: ExtraKey.manualFileName.rawValue, value: pdfName)
                            self.pdfView.document = PDFDocument(url: manualsPath)
                            self.pdfView.autoScales = true
                        } catch {}
                    }
                }, in: self.hostingWindowScene)
            }
        }
        return view
    }()
    
    private var pdfView: PDFView = {
        let view = PDFView()
        view.backgroundColor = R.Color.BackgroundPrimary
        view.autoScales = true
        return view
    }()
    
    required init?(parameters: Any...) {
        guard let game = parameters.compactMap({ $0 as? Game }).first else { return nil }
        self.game = game
        super.init(frame: .zero)
        backgroundColor = R.Color.BackgroundPrimary
        
        addSubview(navigationView)
        navigationView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(R.Size.SheetGrabberTopInset)
            make.leading.trailing.equalTo(self.safeAreaLayoutGuide)
            make.height.equalTo(R.Size.NavigationHeight)
        }
        
        let lastScaleFactor = game.getExtraDouble(key: ExtraKey.manualScaleFactor.rawValue)
        
        addSubview(pdfView)
        if lastScaleFactor != nil {
            pdfView.autoScales = false
        }
        pdfView.snp.makeConstraints { make in
            make.top.equalTo(navigationView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide)
        }
        
        if let manualsPath = game.manualsPath {
            pdfView.document = PDFDocument(url: URL(fileURLWithPath: manualsPath))
        }
        
        // 加载到上一次读取的位置和缩放比例
        if let lastReadPage = game.getExtraInt(key: ExtraKey.manualPage.rawValue),
           let document = pdfView.document,
           lastReadPage < document.pageCount,
           let page = document.page(at: lastReadPage) {
            pdfView.isHidden = true
            DispatchQueue.main.asyncAfter(delay: 0.5, execute: { [weak self] in
                guard let self else { return }
                self.pdfView.isHidden = false
                self.pdfView.go(to: page)
                
                // 恢复上一次的缩放比例
                if let lastScaleFactor {
                    self.pdfView.scaleFactor = CGFloat(lastScaleFactor)
                }
            })
        } else {
            // 如果没有保存的页数，但有保存的缩放比例，也要恢复
            if let lastScaleFactor {
                DispatchQueue.main.asyncAfter(delay: 0.5, execute: { [weak self] in
                    guard let self else { return }
                    self.pdfView.scaleFactor = CGFloat(lastScaleFactor)
                })
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension GameplayManualsView: ShowableView {
    static func show(game: Game, hideCompletion: (() -> Void)? = nil) {
        Self.show(parameters: game)?.hideCompletion = hideCompletion
    }
    
    func dataForShow(_ defaultData: ASSheet) -> ASSheet {
        var sheetData = defaultData
        sheetData.fullScreenForLandscape = true
        return sheetData
    }
    
    func didHide() {
        hideCompletion?()
    }
}
