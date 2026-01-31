import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView(selectedTab: $selectedTab)
            } else {
                AuthView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .noteReceived)) { notification in
            if let _ = notification.userInfo?["note_id"] as? String {
                selectedTab = 1 // Switch to Inbox tab
            }
        }
    }
}

struct MainTabView: View {
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            WindMapView()
                .tabItem {
                    Label("Discover", systemImage: "wind")
                }
                .tag(0)

            InboxView()
                .tabItem {
                    Label("Inbox", systemImage: "tray.fill")
                }
                .tag(1)

            ComposeNoteView()
                .tabItem {
                    Label("Compose", systemImage: "pencil.and.scribble")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(DesignSystem.Colors.primary)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(LocationService.shared)
}
