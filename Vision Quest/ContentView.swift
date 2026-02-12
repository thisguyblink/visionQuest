//
//  Depth Map.swift
//  Vision Quest
//
//  Created by Patrick Smith on 2/12/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("This is the Home Page!")

                NavigationLink(destination: Depth_Map()) {
                    Text("Depth Map Page")
                }
                NavigationLink(destination: Object_Detection()) {
                    Text("Object Detection Page")
                }
                NavigationLink(destination: Directions()) {
                    Text("Direction Page")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
