import SwiftUI

@main
struct SMC_breach: App {
    var body: some Scene {
        // Creates the item in the system menu bar
        MenuBarExtra("SMC Breach", systemImage: "star.fill") {
            AppMenu()
        }
    }
}

struct AppMenu: View {
    var body: some View {
        Button("Crazy button!") {
            print("Action clicked!")
        }
        
        Button("Ts gonna be great!") {
            // Open settings code here
        }
        
        Divider()
        
        Button("Quit :(") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
