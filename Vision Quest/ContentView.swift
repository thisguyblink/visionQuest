//
//  Depth Map.swift
//  Vision Quest
//
//  Created by Patrick Smith on 2/12/26.
//

import SwiftUI

struct SplashScreen: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("This is the Home Page!")
        }
    }
}

struct HomePage: View {
    var body: some View {
        TabView {
            SplashScreen()
            Depth_Map()
            Object_Detection()
            Directions()
        }.tabViewStyle(.page(indexDisplayMode: .automatic))
    }
}

struct HomePagePreview: PreviewProvider {
    static var previews: some View {
        HomePage()
    }
}
