import AppKit
import SwiftUI

final class SettingsModel: ObservableObject {
    @Published private(set) var settings: FeatureSettings
    @Published var accessibilityGranted = false
    @Published var saveError: String?
    private let onChange: () -> Void

    init(settings: FeatureSettings, onChange: @escaping () -> Void) {
        self.settings = settings
        self.onChange = onChange
    }

    func binding(for keyPath: WritableKeyPath<FeatureSettings, Bool>) -> Binding<Bool> {
        Binding(get: { self.settings[keyPath: keyPath] }, set: { value in
            var updated = self.settings
            updated[keyPath: keyPath] = value
            do {
                try FeatureSettingsStore.save(updated)
                self.settings = updated
                self.saveError = nil
                self.onChange()
            } catch {
                self.saveError = "Could not save settings: \(error.localizedDescription)"
            }
        })
    }
}

struct SettingsPanel: View {
    @ObservedObject var model: SettingsModel
    let openAccessibilitySettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                    .resizable()
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("BestWinMac").font(.title2.bold())
                    Text("Features").foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 24)

            sectionTitle("Shortcuts & Corners")
            featureRow("Show Desktop", detail: "⌘D", symbol: "rectangle.3.group",
                       binding: model.binding(for: \.showDesktop))
            featureRow("Bottom-Right Hot Corner", detail: "300 ms", symbol: "arrow.down.right",
                       binding: model.binding(for: \.showDesktopHotCorner))
            featureRow("Cut Files in Finder", detail: "⌘X / ⌘V", symbol: "scissors",
                       binding: model.binding(for: \.finderCut))

            sectionTitle("Finder Context Menu")
                .padding(.top, 18)
            featureRow("Open with VS Code", symbol: "chevron.left.forwardslash.chevron.right",
                       binding: model.binding(for: \.openVSCode))
            featureRow("Copy Path", symbol: "doc.on.doc",
                       binding: model.binding(for: \.copyPath))
            featureRow("Create Desktop Shortcut", symbol: "arrowshape.turn.up.right",
                       binding: model.binding(for: \.desktopAlias))
            featureRow("New Markdown File", symbol: "doc.badge.plus",
                       binding: model.binding(for: \.newMarkdown))

            if (model.settings.showDesktop || model.settings.showDesktopHotCorner || model.settings.finderCut)
                && !model.accessibilityGranted {
                Button("Grant Accessibility Access…", action: openAccessibilitySettings)
                    .padding(.top, 16)
            }
            if let error = model.saveError {
                Text(error).foregroundStyle(.red).font(.caption)
                    .padding(.top, 10)
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 420, height: 560)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 6)
    }

    private func featureRow(_ title: String, detail: String? = nil,
                            symbol: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(title)
            Spacer(minLength: 8)
            if let detail {
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Toggle(title, isOn: binding)
                .labelsHidden()
                .accessibilityLabel(title)
        }
        .frame(height: 42)
    }
}
