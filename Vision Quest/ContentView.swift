//
//  Depth Map.swift
//  Vision Quest
//
//  Created by Patrick Smith on 2/12/26.
//

import SwiftUI
import AVFoundation

// FIXME: Add text-to-speech once merged with Tyler's branch
struct LandingPage: View {
    // let speech = SpeechFuncts()
    var body: some View {
        VStack(spacing: 20) {
            // let welcome_message = "Welcome to Vision Quest ..."
            // speech.speak()
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
            .task {
                try? await Task.sleep(for: .seconds(3))
                goToNextPage = true
            }
            .navigationDestination(isPresented: $goToNextPage) {
                LandingPage().navigationBarBackButtonHidden(true)
            }
        }
    }
}

struct HomePagePreview: PreviewProvider {
    static var previews: some View {
        SplashScreen()
    }
}
