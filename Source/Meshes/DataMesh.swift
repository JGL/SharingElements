//
//  DataMesh.swift
//  BodyElements
//
//  Created by Reza Ali on 7/16/21.
//  Copyright © 2021 Reza Ali. All rights reserved.
//

import Satin

class DataMesh: Mesh {
    var updateData = true
                
    func _setup()
    {
        
    }
    
    func _update()
    {
        
    }
    
    override func update() {
        if updateData {
            _setup()
            updateData = false
        }
        _update()
        super.update()
    }
}

