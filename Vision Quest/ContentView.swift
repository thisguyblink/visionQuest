//
//  Depth Map.swift
//  Vision Quest
//
//  Created by Patrick Smith on 2/12/26.
//

import SwiftUI

struct LandingPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("This is the Home Page!")
        }
    }
}

//struct SplashScreen: View {
//    var body: some View {
//        TabView {
//            LandingPage()
//            Depth_Map()
//            Object_Detection()
//            Directions()
//        }.tabViewStyle(.page(indexDisplayMode: .automatic))
//    }
//}

struct SplashScreen: View {
    @State private var goToNextPage = false

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                Image("VisionQuestLogoMockup")
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)

                Text("VisionQuest")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding()

                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                goToNextPage = true
            }
            .navigationDestination(isPresented: $goToNextPage) {
                LandingPage()
            }
        }
    }
}

struct HomePagePreview: PreviewProvider {
    static var previews: some View {
        SplashScreen()
    }
}
