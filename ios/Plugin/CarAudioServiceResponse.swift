//
//  RootResponse.swift
//  JusticointeractiveCapacitorCarAudio
//
//  Created by Joe Flateau on 9/13/21.
//

import Foundation


struct CarAudioServiceResponse : Codable {
    let type: String;
    let items: [CarAudioResponseSection];
}

struct CarAudioResponseSection : Codable {
    let title: String;
    let icon: String;
    let type: String;
    let items: [CarAudioResponseSectionGroup];
}

struct CarAudioResponseSectionGroup : Codable {
    let type: String;
    let title: String;
    let displayAs: String;
    let items: [CarAudioResponseSectionItem];
}

struct CarAudioResponseSectionItem : Codable {
    let type: String;
    let title: String;
    let description: String;
    let url: String;
    let imageUrl: String?;
}


class CarAudioService {
    func getRoot(rootUrl:URL, completionHandler: @escaping (_ response:CarAudioServiceResponse) -> Void) {
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
                let serviceResponse = try decoder.decode(CarAudioServiceResponse.self, from: data!)
                completionHandler(serviceResponse)
            } catch {
                print(error)
                return;
            }
        }
        task.resume()
    }
    
    func getSource(sourceUrl:URL, completionHandler: @escaping (_ response:[CarAudioResponseSectionGroup]) -> Void) {
        let task = URLSession.shared.dataTask(with: sourceUrl) { data, response, error in
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
                let serviceResponse = try decoder.decode([CarAudioResponseSectionGroup].self, from: data!)
                completionHandler(serviceResponse)
            } catch {
                print(error)
                return;
            }
        }
        task.resume()
    }
}
