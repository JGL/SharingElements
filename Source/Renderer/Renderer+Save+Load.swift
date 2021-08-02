//
//  Renderer+Save+Load.swift
//  BodyElements
//
//  Created by Reza Ali on 7/16/21.
//  Copyright © 2021 Reza Ali. All rights reserved.
//

import Foundation

extension Renderer {
    // MARK: - Save & Load
    
    public func save() {
        saveParameters(parametersURL)
    }
    
    public func load() {
        loadParameters(parametersURL)
    }
    
    public func save(_ url: URL) {
        let saveParametersURL = url.appendingPathComponent("Parameters")
        removeFile(url)
        if createDirectory(url), createDirectory(saveParametersURL) {
            saveParameters(saveParametersURL)
        }
    }
    
    public func load(_ url: URL) {
        loadParameters(url.appendingPathComponent("Parameters"))
    }
    
    func saveParameters(_ url: URL) {
        for (key, param) in params {
            if let p = param {
                p.save(url.appendingPathComponent(key + ".json"))
            }
        }
    }
    
    func loadParameters(_ url: URL) {
        for (key, param) in params {
            if let p = param {
                p.load(url.appendingPathComponent(key + ".json"), append: false)
            }
        }
    }
    
    public func savePreset(_ name: String) {
        let url = presetsURL.appendingPathComponent(name)
        removeFile(url)
        save(url)
    }
    
    public func loadPreset(_ name: String) {
        load(presetsURL.appendingPathComponent(name))
    }
}

