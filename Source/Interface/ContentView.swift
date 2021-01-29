//
//  ContentView.swift
//  Flocking
//
//  Created by Reza Ali on 1/28/21.
//  Copyright © 2020 Reza Ali. All rights reserved.
//

import SwiftUI

import Forge
import Satin

struct ContentView: SwiftUI.View {
    @EnvironmentObject var renderer: Renderer

    var body: some SwiftUI.View {
        ForgeView(renderer: renderer)
            .frame(minWidth: 512, minHeight: 512)
            .edgesIgnoringSafeArea(.all)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some SwiftUI.View {
        ContentView().environmentObject(Renderer())
    }
}
