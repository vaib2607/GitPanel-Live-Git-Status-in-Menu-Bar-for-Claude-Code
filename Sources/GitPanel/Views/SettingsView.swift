import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 13, weight: .medium, design: .monospaced))

            Toggle("Enable usage tracking", isOn: $settings.usageEnabled)
                .font(.system(size: 13, design: .monospaced))

            VStack(alignment: .leading, spacing: 4) {
                Text("Usage remaining")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                TextField("e.g. 80%  ·  120 credits  ·  4h left", text: $settings.usageRemaining)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                Text("Shown in the Environment menu → Usage remaining.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .disabled(!settings.usageEnabled)

            Spacer()
        }
        .padding(20)
        .frame(width: 360, height: 200)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
