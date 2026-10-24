// AboutView.swift — icon, version, credits.

import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 112, height: 112)
            Text("Couch").font(.largeTitle.bold())
            Text("Version \(AppModel.version)").foregroundStyle(.secondary)
            Text("Gamepad media remote for macOS.")
                .padding(.top, 4)
            Text("by Kumar Gaurav Pandey").foregroundStyle(.secondary)
            Link("github.com/necromancerthedark/Couch",
                 destination: URL(string: "https://github.com/necromancerthedark/Couch")!)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
