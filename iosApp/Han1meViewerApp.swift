import SwiftUI
import Han1meShared

@main
struct Han1meViewerApp: App {
    private let sharedEnvironment = SharedAppEnvironment(driverFactory: DatabaseDriverFactory())

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView(environment: sharedEnvironment)
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }

                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }

                LoginView(authFeature: sharedEnvironment.authFeature())
                    .tabItem {
                        Label("Login", systemImage: "person.crop.circle")
                    }
            }
        }
    }
}
