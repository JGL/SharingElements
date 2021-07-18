//
//  Paths.swift
//  BodyElements
//
//  Created by Reza Ali on 7/16/21.
//  Copyright © 2021 Reza Ali. All rights reserved.
//

import Foundation
import Satin

func fileExists(_ url: URL) -> Bool {
    let fm = FileManager.default
    return fm.fileExists(atPath: url.path)
}

public func removeFile(_ url: URL)
{
    let fm = FileManager.default
    if fm.fileExists(atPath: url.path)
    {
        do
        {
            try fm.removeItem(at: url)
        }
        catch
        {
            print(error)
        }
    }
}

func createDirectory(_ url: URL) -> Bool
{
    let fm = FileManager.default
    do
    {
        try fm.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
        return true
    }
    catch
    {
        print(error.localizedDescription)
        return false
    }
}

func copyDirectory(at: URL, to: URL) -> Bool
{
    let fm = FileManager.default
    do
    {
        try fm.copyItem(at: at, to: to)
        return true
    }
    catch
    {
        print(error.localizedDescription)
        return false
    }
}

func copyDirectory(atPath: String, toPath: String, force: Bool = false)
{
    let fm = FileManager.default
    // upon fresh install copy shaders directory
    if !fm.fileExists(atPath: toPath)
    {
        do
        {
            try fm.copyItem(atPath: atPath, toPath: toPath)
        }
        catch
        {
            print(error)
        }
    }
    // otherwise go through all the files and only overwrite the files that dont exist and the ones that have been updates
    else
    {
        do
        {
            let results = try fm.subpathsOfDirectory(atPath: atPath)
            for file in results
            {
                let srcPath = atPath + "/" + file
                let dstPath = toPath + "/" + file

                var directory: ObjCBool = ObjCBool(false)
                if fm.fileExists(atPath: srcPath, isDirectory: &directory)
                {
                    if directory.boolValue
                    {
                        if !fm.fileExists(atPath: dstPath)
                        {
                            do
                            {
                                try fm.copyItem(atPath: srcPath, toPath: dstPath)
                            }
                            catch
                            {
                                print(error)
                            }
                        }
                        else
                        {
                            copyDirectory(atPath: srcPath, toPath: dstPath)
                        }
                    }
                    else
                    {
                        do
                        {
                            let resPathAttributes = try fm.attributesOfItem(atPath: srcPath)
                            if fm.fileExists(atPath: dstPath)
                            {
                                let dstPathAttributes = try fm.attributesOfItem(atPath: dstPath)
                                if let resDate = resPathAttributes[.modificationDate] as? Date, let dstDate = dstPathAttributes[.modificationDate] as? Date
                                {
                                    if force || resDate > dstDate
                                    {
                                        do
                                        {
                                            try fm.removeItem(atPath: dstPath)
                                            try fm.copyItem(atPath: srcPath, toPath: dstPath)
                                        }
                                        catch
                                        {
                                            print(error)
                                        }
                                    }
                                }
                            }
                            else
                            {
                                do
                                {
                                    try fm.copyItem(atPath: srcPath, toPath: dstPath)
                                }
                                catch
                                {
                                    print(error)
                                }
                            }
                        }
                        catch
                        {
                            print(error)
                        }
                    }
                }
            }
        }
        catch
        {
            print(error)
        }
    }
}


public func getDocumentsDirectoryURL() -> URL
{
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
}

public func getDocumentsDirectoryURL(_ path: String) -> URL
{
    return getDocumentsDirectoryURL().appendingPathComponent(path)
}

public func getDocumentsAssetsDirectoryUrl() -> URL
{
    return getDocumentsDirectoryURL("Assets")
}

public func getDocumentsAssetsDirectoryUrl(_ path: String) -> URL
{
    return getDocumentsAssetsDirectoryUrl().appendingPathComponent(path)
}

public func getResourceDirectory() -> String
{
    return Bundle.main.resourcePath!
}

public func getResourceDirectory(_ path: String) -> String
{
    return getResourceDirectory() + "/" + path
}

public func getResourcesDirectoryURL() -> URL
{
    return Bundle.main.resourceURL!
}

public func getResourceDirectoryUrl(_ path: String) -> URL
{
    return getResourcesDirectoryURL().appendingPathComponent(path)
}

public func getResourceAssetsDirectory() -> String
{
    return getResourceDirectory("Assets")
}

public func getResourceAssetsDirectory(_ path: String) -> String
{
    return getResourceAssetsDirectory() + "/" + path
}

public func getResourceAssetsDirectoryUrl() -> URL
{
    return URL(fileURLWithPath: getResourceAssetsDirectory())
}

public func getResourceAssetsDirectoryUrl(_ path: String) -> URL
{
    return getResourceAssetsDirectoryUrl().appendingPathComponent(path)
}
