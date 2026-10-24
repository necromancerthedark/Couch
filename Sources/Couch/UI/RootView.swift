// RootView.swift — the Settings window: sidebar + one page per tab (ADR-020).

import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case controller = "Controller"
    case tuning = "Tuning"
    case debug = "Debug"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "switch.2"
        case .controller: return "gamecontroller"
        case .tuning: return "slider.horizontal.3"
        case .debug: return "ladybug"
        case .about: return "info.circle"
        }
    }
}

final class NavState: ObservableObject {
    @Published var selection: SettingsTab? = .general
}

struct RootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var nav: NavState

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 820, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // Plain sidebar (not NavigationSplitView): same look, and it renders in
    // the README screenshot capture, which native sidebars do not.
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().frame(width: 26, height: 26)
                Text("Couch").font(.headline)
            }
            .padding(.horizontal, 10).padding(.bottom, 14).padding(.top, 6)

            ForEach(SettingsTab.allCases) { tab in
                let selected = (nav.selection ?? .general) == tab
                Button { nav.selection = tab } label: {
                    Label(tab.rawValue, systemImage: tab.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .background(selected ? Color.accentColor : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(12)
        .frame(width: 176)
        .background(Color.primary.opacity(0.04))
    }

    @ViewBuilder private var detail: some View {
        switch nav.selection ?? .general {
        case .general: GeneralView(model: model)
        case .controller: ControllerView(model: model)
        case .tuning: TuningView(model: model, settings: model.settings, pad: model.pad)
        case .debug: DebugView(model: model, events: model.events)
        case .about: AboutView()
        }
    }
}

/// Page title used at the top of every tab.
struct PageTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.largeTitle.bold()).padding(.bottom, 4)
    }
}
