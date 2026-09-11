//
//  DownloadManageView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/29.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import Tiercel

class DownloadManageView: BaseView {
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            if let navigationValue = action.navigationValue,
               navigationValue.isTapClose {
                self.hide()
            } else if let normalItemValue = action.normalItemValue {
                let task = self.tasks[normalItemValue.indexPath.row]
                if let button = normalItemValue.subActions?.itemStyle.buttonValue {
                    if button.tag == 0 {
                        //pause or continue task
                        if task.status == .suspended {
                            //继续下载
                            DownloadManager.shared.sessionManager.start(task)
                            NotificationCenter.default.post(name: R.NotificationName.BeginDownload, object: nil)
                            self.listPageView.updateCellData(self.getCell(task: task),
                                                             indexPath: normalItemValue.indexPath)
                        } else {
                            //暂停下载
                            DownloadManager.shared.sessionManager.suspend(task)
                            self.listPageView.updateCellData(self.getCell(task: task),
                                                             indexPath: normalItemValue.indexPath)
                        }
                        
                    } else if button.tag == 1 {
                        //remove task
                        UIView.makeAlert(detail: R.string.localizable.removeDownloadTask(task.fileName),
                                         confirmTitle: R.string.localizable.confirmTitle(),
                                         confirmAction: {
                            DownloadManager.shared.sessionManager.remove(task)
                        })
                    }
                }
                
            }
        }
        return view
    }()
    
    private var tasks: [DownloadTask]
    
    required init?(parameters: Any...) {
        self.tasks = DownloadManager.shared.sessionManager.tasks.filter {
            $0.status == .running || $0.status == .waiting || $0.status == .suspended || $0.status == .failed
        }
        super.init(frame: .zero)
        
        for (index, task) in tasks.enumerated() {
            task.completion { [weak self] insideTask in
                guard let self = self else { return }
                if insideTask.status == .removed || insideTask.status == .succeeded {
                    self.tasks.removeFirst(where: { $0.url == insideTask.url })
                    self.updateContents()
                }
            }
            
            task.progress { [weak self] insideTask in
                guard let self = self else { return }
                self.listPageView.updateCellData(self.getCell(task: insideTask),
                                                 indexPath: IndexPath(row: index, section: 0))
            }
        }
        
        
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func getListPage() -> ASListPage {
        let navigation = ASListPage.Navigation.defaultNavigation(title: R.string.localizable.cloudDriveBrowserDownload(),
                                                                 titleIcon: .symbolImage(R.image.cloudDownload_iconSymbols()))
        
        let blankSlate = ASListPage.BlankSlate(title: R.string.localizable.noDownloadTask())
        
        return ASListPage(navigation: navigation,
                          sections: getSections(),
                          blankSlate: blankSlate,
                          backgroundColor: .clear,
                          pageInsets: .insets(top: R.Size.SheetGrabberTopInset))
    }
    
    private func updateContents() {
        listPageView.sections = getSections()
    }
    
    private func getSections() -> [ASListPage.Section] {
        return [.init(cells: tasks.map({ getCell(task: $0) }))]
    }
    
    private func getCell(task: DownloadTask) -> ASListPage.Cell {
        var styles = [ASListPage.Cell.Style]()
        styles.append(.icon(.image(R.image.file_browser_document()),
                            iconSize: .fixSize(R.Size.IconSizeExtraLarge)))
        styles.append(.title(.largeText(task.fileName)))
        if task.status == .failed {
            styles.append(.detail(.extraSmallText(R.string.localizable.downloadFailed())))
        } else {
            let detail = "\(FileType.humanReadableFileSize(UInt64(task.progress.completedUnitCount)) ?? "0.0 KB")/\(FileType.humanReadableFileSize(UInt64(task.progress.totalUnitCount)) ?? "0.0 KB")"
            styles.append(.detail(.extraSmallText(detail)))
            if task.status == .suspended {
                styles.append(.button(.iconOnly(icon: .symbolImage(R.image.playCircle_iconSymbols()),
                                                iconSize: R.Size.IconSizeExtraLarge,
                                                background: .clear,
                                                insets: .init(inset: R.Size.ContentSpaceTiny))))
            } else {
                styles.append(.button(.iconOnly(icon: .symbolImage(R.image.pauseCircle_iconSymbols()),
                                                iconSize: R.Size.IconSizeExtraLarge,
                                                background: .clear,
                                                insets: .init(inset: R.Size.ContentSpaceTiny))))
            }
        }
        var button = ASButton.iconOnly(icon: .symbolImage(R.image.selectX_iconSymbols()),
                                       iconSize: R.Size.IconSizeExtraLarge,
                                       background: .clear,
                                       insets: .init(inset: R.Size.ContentSpaceTiny))
        button.tag = 1
        styles.append(.button(button))
        styles.append(.progress(ASProgress(value: Float(task.progress.fractionCompleted))))
        return ASListPage.Cell.normal(styles, enablePressEffect: false)
    }
}

extension DownloadManageView: ShowableView {
    
}
