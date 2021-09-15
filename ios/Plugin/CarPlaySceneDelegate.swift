//
//  SceneDelegate.swift
//  App
//
//  Created by Joe Flateau on 9/7/21.
//

import Foundation
import UIKit
import CarPlay
import SVGKit
import AVFoundation
import MediaPlayer
import Kingfisher

@available(iOS 13.0, *)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPTabBarTemplateDelegate {
    
    // MARK: - CPTemplateApplicationSceneDelegate
    // CarPlay connected
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        
        if #available(iOS 14.0, *) {
            let tabTemplate = CPTabBarTemplate(templates: [])
            tabTemplate.delegate = self
            self.interfaceController.setRootTemplate(tabTemplate, animated: true)
            self.loadRoot()
            
            observer = UserDefaults.standard.observe(\.carAudioPluginUrl, options: [.new], changeHandler: { (defaults, change) in
                print("keyChange " + (UserDefaults.standard.carAudioPluginUrl ?? ""))
                self.loadRoot()
            })
        }
    }
    
    // CarPlay disconnected
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        observer?.invalidate()
        observer = nil
    }
    
    // MARK: - CPTabBarTemplateDelegate
    @available(iOS 14.0, *)
    func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
        let serviceSectionReference = selectedTemplate.userInfo as? CarAudioServiceSectionReferenceResponse;
        guard let serviceSectionReference = serviceSectionReference else {
            print("nil service reference")
            return;
        }
        guard let listTemplate = selectedTemplate as? CPListTemplate else {
            print("not a list template")
            return;
        }
        
        let sectionUrl = URL(string: serviceSectionReference.url, relativeTo: URL(string:UserDefaults.standard.carAudioPluginUrl!))!
        
        self.service.getSection(sourceUrl: sectionUrl) { section in
            self.populateListTemplate(rootUrl: sectionUrl, items: section.items, listTemplate: listTemplate)
        }
    }
    
    // MARK: - CarPlaySceneDelegate
    var interfaceController: CPInterfaceController!
    var player: AVQueuePlayer?
    var observer: NSKeyValueObservation?;
    var service = CarAudioService.init()
    
    @available(iOS 14.0, *)
    func loadRoot(){
        let rootUrl = UserDefaults.standard.carAudioPluginUrl
        
        var urlComponents = URLComponents(string: rootUrl!)!
        urlComponents.queryItems = (urlComponents.queryItems ?? []) + [
            URLQueryItem(name: "maxItemCount", value: String(CPListTemplate.maximumItemCount)),
            URLQueryItem(name: "maxSectionCount", value: String(CPListTemplate.maximumSectionCount)),
            URLQueryItem(name: "maxImageGridItemImages", value: String(CPMaximumNumberOfGridImages))
        ]
        let url = urlComponents.url!
        
        let rootTabTemplate: CPTabBarTemplate = self.interfaceController.rootTemplate as! CPTabBarTemplate;
        var tabTemplates = rootTabTemplate.templates
        
        self.service.getRoot(rootUrl: url) { serviceResponse in
            serviceResponse.items.enumerated().forEach { (tabIndex, tab) in
                var tabListTemplate: CPListTemplate;
                
                if tabTemplates.count > tabIndex {
                    tabListTemplate = tabTemplates[tabIndex] as! CPListTemplate
                } else {
                    tabListTemplate = CPListTemplate(title: tab.title, sections:[])
                    tabTemplates.append(tabListTemplate)
                }
                tabListTemplate.tabTitle = tab.title
                tabListTemplate.showsTabBadge = false
                tabListTemplate.userInfo = tab
                tabListTemplate.emptyViewTitleVariants = ["Loading"]
                tabListTemplate.emptyViewSubtitleVariants = [""]
                
                if let iconContents = FileManager.default.contents(atPath: Bundle.main.bundlePath + "/public/assets/img/\(tab.icon).svg") {
                    // HACK: SVGKit barfs on the first attempt to load an image but loads anything subsequent just fine...
                    let _ = SVGKImage.init(data: iconContents)
                    
                    let svgImage = SVGKImage.init(data: iconContents)
                    tabListTemplate.tabImage = svgImage?.uiImage
                }
            }
            
            if (tabTemplates.count != rootTabTemplate.templates.count) {
                rootTabTemplate.updateTemplates(tabTemplates)
            }
            
        }
    }
    
    @available(iOS 14.0, *)
    func populateListTemplate(rootUrl:URL, items: [CarAudioResponseSectionGroup], listTemplate: CPListTemplate) {
        var tabSections: [CPListSection] = []
        
        listTemplate.emptyViewTitleVariants = ["Empty"]
        listTemplate.emptyViewSubtitleVariants = ["No content available"]

        items.forEach { group in
            var tabSectionItems: [CPListItem] = []
        
            group.items.forEach { item in
                let listItem = CPListItem(text: item.title, detailText: item.description);
                listItem.handler = { _, completion in
                    switch (item.type) {
                    case "upcoming":
                        self.showUpcomingItemAlert(item);
                    case "playable":
                        self.playItem(item);
                    case "browsable":
                        self.browseItem(rootUrl, item: item);
                    default:
                        print("unknown item type")
                    }
                    completion()
                }
                tabSectionItems.append(listItem)
                
                if item.imageUrl != nil {
                    let imageUrl = URL(string: item.imageUrl!)
                    if imageUrl != nil {
                        KingfisherManager.shared.retrieveImage(with: ImageResource(downloadURL: imageUrl!), options: nil, progressBlock: nil) { result in
                            switch result {
                            case .success(let value):
                                listItem.setImage(value.image)
                            case .failure(let err):
                                print(err)
                            }
                        }
                    }
                }
            }
            
            let listSection = CPListSection(items: tabSectionItems, header: group.title, sectionIndexTitle: nil)
            tabSections.append(listSection)
        }
        
        listTemplate.updateSections(tabSections)
    }
    
    let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d 'at' H:mm a"
        return dateFormatter;
    }()
    
    let isoFormatter: ISO8601DateFormatter = {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds];
        return isoFormatter;
    }()
    
    @available(iOS 14.0, *)
    func showUpcomingItemAlert(_ item: CarAudioResponseSectionItem) {
        let parsedDate = isoFormatter.date(from: item.publishDate!)
        let formattedDate = dateFormatter.string(from: parsedDate!)
        
        let alertTemplate = CPAlertTemplate(titleVariants: ["\(item.title) will begin \(formattedDate)"], actions: [
                                                CPAlertAction(title: "Ok", style: .cancel) { action in
                                                    self.interfaceController.dismissTemplate(animated: true)
                                                }
        ])
        self.interfaceController.presentTemplate(alertTemplate, animated: true)
    }
    
    @available(iOS 14.0, *)
    func playItem(_ item: CarAudioResponseSectionItem) {
        let playerItem = AVPlayerItem(url: URL(string: item.url!)!)
        self.player = AVQueuePlayer(items:[playerItem])
        self.player!.play();
        self.interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true)
    }
    
    @available(iOS 14.0, *)
    func browseItem(_ rootUrl:URL, item: CarAudioResponseSectionItem) {
        let listTemplate = CPListTemplate(title: item.title, sections: [])
        let sourceUrl = URL(string: item.url!, relativeTo: rootUrl)!
        self.service.getSection(sourceUrl: sourceUrl) { section in
            self.populateListTemplate(rootUrl: sourceUrl, items: section.items, listTemplate: listTemplate)
        }
        self.interfaceController.pushTemplate(listTemplate, animated: true)
    }
}
