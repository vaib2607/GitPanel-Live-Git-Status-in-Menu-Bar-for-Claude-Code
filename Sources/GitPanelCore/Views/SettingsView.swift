import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.system(size: 13, weight: .medium))

            Toggle("Enable usage tracking", isOn: $settings.usageEnabled)
                .font(.system(size: 13))
                .accessibilityLabel("Enable usage tracking")
                .accessibilityHint("Toggles automatic usage tracking on or off")

            VStack(alignment: .leading, spacing: 4) {
                Text("Usage remaining")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("e.g. 80%  ·  120 credits  ·  4h left", text: $settings.usageRemaining)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .accessibilityLabel("Usage remaining")
                    .accessibilityHint("Enter a custom usage remaining value, such as 80%, 120 credits, or 4h left")
                Text("Shown in the Environment menu → Usage remaining.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .disabled(!settings.usageEnabled)

            Spacer()
        }
        .padding(16)
        .frame(width: 360, height: 200)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
