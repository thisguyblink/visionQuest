//
//  Vision_QuestApp.swift
//  Vision Quest
//
//  Created by Patrick Smith on 2/12/26.
//

import SwiftUI
import SwiftData
import GoogleMaps

@main
struct Vision_QuestApp: App {
    @StateObject private var lidarManager = DepthCameraManager()
    init() {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_API_KEY") as? String,
              !key.isEmpty,
              key != "$(GOOGLE_API_KEY)" else {
            fatalError("GOOGLE_API_KEY is missing or was not substituted from xcconfig")
        }

        GMSServices.provideAPIKey(key)
    }
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(lidarManager)
                .onAppear {
                    lidarManager.start()
                }
                
        }
        .modelContainer(sharedModelContainer)
    }
}
