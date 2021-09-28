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
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPTabBarTemplateDelegate, CPNowPlayingTemplateObserver {
    
    // MARK: - CPTemplateApplicationSceneDelegate
    // CarPlay connected
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        
        self.logEventIfFirebaseAnalyticsAvailable(
            name: "launch_car_app",
            parameters: [
                "car_app_type": "CarPlay" as NSObject
            ])
        
        if #available(iOS 14.0, *) {
            let tabTemplate = CPTabBarTemplate(templates: [])
            tabTemplate.delegate = self
            self.interfaceController.setRootTemplate(tabTemplate, animated: true)
            self.loadRoot()
            
            observer = UserDefaults.standard.observe(\.carAudioPluginUrl, options: [.new], changeHandler: { (defaults, change) in
                print("keyChange " + (UserDefaults.standard.carAudioPluginUrl ?? ""))
                self.loadRoot()
            })
            CPNowPlayingTemplate.shared.add(self)
        }
    }
    
    // CarPlay disconnected
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        observer?.invalidate()
        observer = nil
    }
    
    // MARK: - FirebaseAnalytics
    func logEventIfFirebaseAnalyticsAvailable(name: String, parameters: Dictionary<NSString, NSObject>) {
        let firebaseAnalyticsClassName = "FIRAnalytics";
        if let loadedClass = NSClassFromString(firebaseAnalyticsClassName) as? NSObject.Type {
            let logEventSelector = Selector("logEventWithName:parameters:")
            if loadedClass.responds(to: logEventSelector) {
                loadedClass.perform(logEventSelector, with: name, with: parameters)
            }
        }
    }
    
    // MARK: - CPTabBarTemplateDelegate
    @available(iOS 14.0, *)
    func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
        guard let serviceSectionReference = selectedTemplate.userInfo as? CarContentTabsTabReference else {
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
        guard let rootUrl = UserDefaults.standard.carAudioPluginUrl else {
            return;
        }
        
        var urlComponents = URLComponents(string: rootUrl)!
        urlComponents.queryItems = (urlComponents.queryItems ?? []) + [
            URLQueryItem(name: "maxItemCount", value: String(CPListTemplate.maximumItemCount)),
            URLQueryItem(name: "maxSectionCount", value: String(CPListTemplate.maximumSectionCount)),
            URLQueryItem(name: "maxGridItemsCount", value: String(8)),
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
                tabListTemplate.emptyViewSubtitleVariants = ["Please wait"]
                
                if let iconContents = FileManager.default.contents(atPath: Bundle.main.bundlePath + "/public/assets/img/\(tab.icon).svg") {
                    // HACK: SVGKit barfs on the first attempt to load an image but loads anything subsequent just fine...
                    let _ = SVGKImage.init(data: iconContents)
                    
                    let svgImage = SVGKImage.init(data: iconContents)
                    tabListTemplate.tabImage = svgImage?.uiImage
                }
            }
            
            rootTabTemplate.updateTemplates(tabTemplates)
            
        }
    }
    
    @available(iOS 14.0, *)
    func populateListTemplate(rootUrl:URL, items: [CarContentSection], listTemplate: CPListTemplate) {
        var tabSections: [CPListSection] = []
        
        listTemplate.emptyViewTitleVariants = ["Empty"]
        listTemplate.emptyViewSubtitleVariants = ["No content available"]

        items.forEach { group in
            var tabSectionItems: [CPListItem] = []
        
            group.items.forEach { item in
                var detailText = item.description
                if item.publishDate != nil {
                    detailText = "\(self.shortDateFormatter.string(from: self.isoFormatter.date(from: item.publishDate!)!)) • \(detailText)"
                }
                
                let listItem = CPListItem(text: item.title, detailText: detailText);
                
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
                
                listItem.accessoryType = {
                    switch(item.type) {
                    case "browsable":
                        return .disclosureIndicator;
                    default:
                        return .none;
                    }}()
                
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
            
            let listSection = CPListSection(items: tabSectionItems, header: group.title, sectionIndexTitle: group.indexTitle)
            tabSections.append(listSection)
        }
        
        listTemplate.updateSections(tabSections)
    }
    
//    @available(iOS 14.0, *)
//    func createGridTemplate(rootUrl:URL, title:String, items: [CarContentSection], completionHandler: @escaping (_ gridTemplate: CPGridTemplate) -> Void) {
//        let selectedSection = 0;
//
//        var buttons: [CPGridButton] = []
//
//        items[selectedSection].items.forEach { item in
//            KingfisherManager.shared.retrieveImage(with: ImageResource(downloadURL: URL(string: item.imageUrl!)!)) { imageResult in
//                switch imageResult {
//                case .success(let imageValue):
//                    let gridItem = CPGridButton(titleVariants: [item.title], image: imageValue.image) { _ in
//                        switch (item.type) {
//                        case "upcoming":
//                            self.showUpcomingItemAlert(item);
//                        case "playable":
//                            self.playItem(item);
//                        case "browsable":
//                            self.browseItem(rootUrl, item: item);
//                        default:
//                            print("unknown item type")
//                        }
//                    }
//
//                    buttons.append(gridItem)
//
//                    if (buttons.count == items.count) {
//                        let gridTemplate = CPGridTemplate(title: title, gridButtons: buttons)
//                        completionHandler(gridTemplate)
//                    }
//                case .failure(let error):
//                    print(error)
//                    return;
//                }
//            }
//        }
//
//    }
    
    let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d 'at' h:mm a"
        return dateFormatter;
    }()
    
    let shortDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, h:mm a"
        return dateFormatter;
    }()
    
    let isoFormatter: ISO8601DateFormatter = {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds];
        return isoFormatter;
    }()
    
    @available(iOS 14.0, *)
    func showUpcomingItemAlert(_ item: CarContentItem) {
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
    func playItem(_ item: CarContentItem) {
        let session = AVAudioSession.sharedInstance()
        
        self.logEventIfFirebaseAnalyticsAvailable(
            name: "select_content",
            parameters: [
                "content_type": (item.contentType ?? "") as NSObject,
                "item_id": (item.itemId ?? "") as NSObject,
                "car_app_type": "CarPlay" as NSObject
            ])
        
        do {
            try session.setCategory(.playback)
            try session.setActive(true)
        } catch {
            print(error)
            return
        }
        
        let playerItem = AVPlayerItem(url: URL(string: item.url!)!)
        if (self.player != nil) {
            self.player?.removeAllItems()
            self.player?.insert(playerItem, after: nil)
        } else {
            let player = AVQueuePlayer(items:[playerItem])
            
            let remoteCommandCenter = MPRemoteCommandCenter.shared()
            
            remoteCommandCenter.seekForwardCommand.isEnabled = false
            remoteCommandCenter.seekBackwardCommand.isEnabled = false
            
            remoteCommandCenter.playCommand.isEnabled = true
            remoteCommandCenter.playCommand.addTarget(handler: {e in
                player.play()
                return .success
            })
            remoteCommandCenter.pauseCommand.isEnabled = true
            remoteCommandCenter.pauseCommand.addTarget(handler: {e in
                player.pause()
                return .success
            })
            
            remoteCommandCenter.skipForwardCommand.preferredIntervals = [15]
            remoteCommandCenter.skipForwardCommand.addTarget(handler: {e in
                guard let skipEvent = e as? MPSkipIntervalCommandEvent else {
                    return .commandFailed
                }
                player.seek(to: CMTime(seconds: CMTimeGetSeconds(player.currentTime()) + skipEvent.interval, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                return .success
            })
            
            remoteCommandCenter.skipBackwardCommand.preferredIntervals = [15]
            remoteCommandCenter.skipBackwardCommand.addTarget(handler: {e in
                guard let skipEvent = e as? MPSkipIntervalCommandEvent else {
                    return .commandFailed
                }
                player.seek(to: CMTime(seconds: CMTimeGetSeconds(player.currentTime()) - skipEvent.interval, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                return .success
            })
            
            self.player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { _ in
                let isLive = CMTIME_IS_INDEFINITE(player.currentItem!.duration)
                let duration = isLive ? 0 : CMTimeGetSeconds(player.currentItem!.duration)
                
                remoteCommandCenter.skipForwardCommand.isEnabled = !isLive
                remoteCommandCenter.skipBackwardCommand.isEnabled = !isLive
                
                if var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                    if (!isLive) {
                        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
                    }
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
            }
            
            self.player = player;
        }
        
        self.player!.play();
       
        var nowPlayingInfo = [String: Any] ()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = item.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = item.description
        nowPlayingInfo[MPMediaItemPropertyReleaseDate] = item.publishDate
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        if (item.artworkUrl != nil) {
            let artworkUrl = URL(string: item.artworkUrl!)!
            KingfisherManager.shared.retrieveImage(with: ImageResource(downloadURL: artworkUrl), options: nil, progressBlock: nil) { result in
                switch result {
                case .success(let value):
                    let artwork = MPMediaItemArtwork(boundsSize: value.image.size, requestHandler: { _ -> UIImage in
                        return value.image
                    })
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                case .failure(let err):
                    print(err)
                }
            }
        }
        
        #if targetEnvironment(simulator)
          UIApplication.shared.endReceivingRemoteControlEvents()
          UIApplication.shared.beginReceivingRemoteControlEvents()
        #endif
        
        self.interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true)
    }
    
    @available(iOS 14.0, *)
    func browseItem(_ rootUrl:URL, item: CarContentItem) {
        switch item.displayAs {
        case "list":
            let listTemplate = CPListTemplate(title: item.title, sections: [])
            let sourceUrl = URL(string: item.url!, relativeTo: rootUrl)!
            self.service.getSection(sourceUrl: sourceUrl) { section in
                self.populateListTemplate(rootUrl: sourceUrl, items: section.items, listTemplate: listTemplate)
            }
            self.interfaceController.pushTemplate(listTemplate, animated: true)
        case "grid":
            let listTemplate = CPListTemplate(title: item.title, sections: [])
            let sourceUrl = URL(string: item.url!, relativeTo: rootUrl)!
            self.service.getSection(sourceUrl: sourceUrl) { section in
                self.populateListTemplate(rootUrl: sourceUrl, items: section.items, listTemplate: listTemplate)
            }
            self.interfaceController.pushTemplate(listTemplate, animated: true)
//        case "grid":
//            let sourceUrl = URL(string: item.url!, relativeTo: rootUrl)!
//            self.service.getSection(sourceUrl: sourceUrl) { section in
//                self.createGridTemplate(rootUrl: sourceUrl, title: item.title, items: section.items) { gridTemplate in
//                    self.interfaceController.pushTemplate(gridTemplate, animated: true)
//                }
//            }
        default:
            print("unknown template type")
            return;
        }
    }
}
