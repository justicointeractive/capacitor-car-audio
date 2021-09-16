//
//  RootResponse.swift
//  JusticointeractiveCapacitorCarAudio
//
//  Created by Joe Flateau on 9/13/21.
//

import Foundation


struct CarContentTabsResponse : Codable {
    let type: String;
    let items: [CarContentTabsTabReference];
}

struct CarContentTabsTabReference : Codable {
    let title: String;
    let icon: String;
    let type: String;
    let url: String;
}

struct CarContentListResponse : Codable {
    let type: String;
    let items: [CarContentSection];
}

struct CarContentGridResponse : Codable {
    let type: String;
    let items: [CarContentSection];
}

struct CarContentSection : Codable {
    let type: String;
    let title: String;
    let indexTitle: String?;
    let displayAs: String?;
    let items: [CarContentItem];
}

struct CarContentItem : Codable {
    let type: String;
    let title: String;
    let description: String;
    
    // browsable
    let displayAs: String?;
    
    // playable
    let imageUrl: String?;
    let artworkUrl: String?;
    
    // browsable & playable
    let url: String?;
    
    // upcoming & playable
    let publishDate: String?;
}


class CarAudioService {
    private func get<T>(rootUrl:URL, type: T.Type, completionHandler: @escaping (_ response: T) -> Void) where T : Decodable {
        let task = URLSession.shared.dataTask(with: rootUrl) { data, response, error in
            if let error = error {
                print(error)
                return;
            }
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print(response ?? "unknonwn server side error")
                return;
            }
            do {
                let decoder = JSONDecoder()
                let serviceResponse = try decoder.decode(type, from: data!)
                completionHandler(serviceResponse)
            } catch {
                print(error)
                return;
            }
        }
        task.resume()
    }
    
    func getRoot(rootUrl:URL, completionHandler: @escaping (_ response:CarContentTabsResponse) -> Void) {
        self.get(rootUrl: rootUrl, type: CarContentTabsResponse.self, completionHandler: completionHandler)
    }
    
    func getSection(sourceUrl:URL, completionHandler: @escaping (_ response:CarContentListResponse) -> Void) {
        self.get(rootUrl: sourceUrl, type: CarContentListResponse.self, completionHandler: completionHandler)
    }
}
