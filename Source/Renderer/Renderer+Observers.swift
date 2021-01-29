//
//  Renderer+Observers.swift
//  Flocking
//
//  Created by Reza Ali on 1/28/21.
//  Copyright © 2020 Reza Ali. All rights reserved.
//

import Foundation

extension Renderer {
    func setupObservers() {
        observers.append(particleCountParam.observe(\.value) { [unowned self] _, _ in
            self.particleSystem.count = self.particleCountParam.value
            self.sprite.instanceCount = self.particleCountParam.value
        })

        observers.append(resetParam.observe(\.value) { [unowned self] _, _ in
            if self.resetParam.value {
                self.particleSystem.reset()
                self.resetParam.value = false
            }
        })
    }
}
