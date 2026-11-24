//  IPAPhotogrammetryApp.swift
//  Application entry point that wires up environment objects and manages lifecycle tasks.

import SwiftUI
import AppKit

@main
struct IPAPhotogrammetryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var languageManager = LanguageManager()
    @StateObject var settings = SettingsManager.instance
    @StateObject private var photogrammetryViewModel = PhotogrammetryViewModel()
    @StateObject private var autoScaleViewModel = AutoScaleViewModel()
    @StateObject private var objRenamerViewModel = OBJRenamerViewModel()
    @StateObject private var readmeGeneratorViewModel = ReadmeGeneratorViewModel()
    @StateObject private var folderStructureViewModel = FolderStructureViewModel()
    @StateObject private var boneFolderViewModel = BoneFolderViewModel()

    var body: some Scene {
        Window("Integrated Photogrammetry Assistant", id: "workspace") {
            ContentView()
                .environmentObject(languageManager)
                .environmentObject(photogrammetryViewModel)
                .environmentObject(autoScaleViewModel)
                .environmentObject(objRenamerViewModel)
                .environmentObject(readmeGeneratorViewModel)
                .environmentObject(folderStructureViewModel)
                .environmentObject(boneFolderViewModel)
                .environmentObject(settings)
        }
        .defaultSize(width: 1440, height: 850)
        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }


}

// Intermediate view that manages the splash screen and the transition to the main interface.
struct ContentView: View {
    @State private var showLaunchScreen = true
    
    var body: some View {
        Group {
            if showLaunchScreen {
                LaunchScreenView()
                    .onAppear {
                        print("Splash screen started")
                        // Splash screen duration: 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            print("Switching to MainView")
                            withAnimation {
                                showLaunchScreen = false
                            }
                        }
                    }
            } else {
                MainView() // MainView inherits all the previously injected environment objects.
            }
        }
    }
}
