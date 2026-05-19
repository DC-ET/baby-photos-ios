import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }

            AlbumView()
                .tabItem {
                    Label("相册", systemImage: "photo.on.rectangle.angled")
                }

            HistoryView()
                .tabItem {
                    Label("记录", systemImage: "clock.fill")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
    }
}
