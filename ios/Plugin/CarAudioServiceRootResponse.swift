//
//  RootResponse.swift
//  JusticointeractiveCapacitorCarAudio
//
//  Created by Joe Flateau on 9/13/21.
//

import Foundation


struct CarAudioServiceRootResponse : Codable {
    let type: String;
    let items: [CarAudioServiceSectionReferenceResponse];
}

struct CarAudioServiceSectionReferenceResponse : Codable {
    let title: String;
    let icon: String;
    let type: String;
    let url: String;
}

struct CarAudioServiceSectionResponse : Codable {
    let items: [CarAudioResponseSectionGroup];
}

struct CarAudioResponseSectionGroup : Codable {
    let type: String;
    let title: String;
    let displayAs: String?;
    let items: [CarAudioResponseSectionItem];
}

struct CarAudioResponseSectionItem : Codable {
    let type: String;
    let title: String;
    let description: String;
    let url: String?;
    let imageUrl: String?;
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
    
    func getRoot(rootUrl:URL, completionHandler: @escaping (_ response:CarAudioServiceRootResponse) -> Void) {
        self.get(rootUrl: rootUrl, type: CarAudioServiceRootResponse.self, completionHandler: completionHandler)
    }
    
    func getSection(sourceUrl:URL, completionHandler: @escaping (_ response:CarAudioServiceSectionResponse) -> Void) {
        self.get(rootUrl: sourceUrl, type: CarAudioServiceSectionResponse.self, completionHandler: completionHandler)
    }
}
