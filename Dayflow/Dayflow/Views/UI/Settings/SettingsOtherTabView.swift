import SwiftUI

struct SettingsOtherTabView: View {
  @ObservedObject var viewModel: OtherSettingsViewModel
  @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
  @FocusState private var isOutputLanguageFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      recordingScheduleCard

      SettingsCard(title: "App preferences", subtitle: "General toggles and telemetry settings") {
        VStack(alignment: .leading, spacing: 14) {
          Toggle(
            isOn: Binding(
              get: { launchAtLoginManager.isEnabled },
              set: { launchAtLoginManager.setEnabled($0) }
            )
          ) {
            Text("Launch Dayflow at login")
              .font(.custom("Nunito", size: 13))
              .foregroundColor(.black.opacity(0.7))
          }
          .toggleStyle(.switch)
          .pointingHandCursor()

          Text(
            "Keeps the menu bar controller running right after you sign in so capture can resume instantly."
          )
          .font(.custom("Nunito", size: 11.5))
          .foregroundColor(.black.opacity(0.5))

          Toggle(isOn: $viewModel.analyticsEnabled) {
            Text("Share crash reports and anonymous usage data")
              .font(.custom("Nunito", size: 13))
              .foregroundColor(.black.opacity(0.7))
          }
          .toggleStyle(.switch)
          .pointingHandCursor()

          Toggle(isOn: $viewModel.showDockIcon) {
            Text("Show Dock icon")
              .font(.custom("Nunito", size: 13))
              .foregroundColor(.black.opacity(0.7))
          }
          .toggleStyle(.switch)
          .pointingHandCursor()

          Text("When off, Dayflow runs as a menu bar-only app.")
            .font(.custom("Nunito", size: 11.5))
            .foregroundColor(.black.opacity(0.5))

          Toggle(isOn: $viewModel.showTimelineAppIcons) {
            Text("Show app/website icons in timeline")
              .font(.custom("Nunito", size: 13))
              .foregroundColor(.black.opacity(0.7))
          }
          .toggleStyle(.switch)
          .pointingHandCursor()

          Text("When off, timeline cards won't show app or website icons.")
            .font(.custom("Nunito", size: 11.5))
            .foregroundColor(.black.opacity(0.5))

          VStack(alignment: .leading, spacing: 8) {
            Text("Output language override")
              .font(.custom("Nunito", size: 13))
              .foregroundColor(.black.opacity(0.7))
            HStack(spacing: 10) {
              TextField("English", text: $viewModel.outputLanguageOverride)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .frame(maxWidth: 220)
                .focused($isOutputLanguageFocused)
                .onChange(of: viewModel.outputLanguageOverride) {
                  viewModel.markOutputLanguageOverrideEdited()
                }
              DayflowSurfaceButton(
                action: {
                  viewModel.saveOutputLanguageOverride()
                  isOutputLanguageFocused = false
                },
                content: {
                  HStack(spacing: 6) {
                    Image(
                      systemName: viewModel.isOutputLanguageOverrideSaved
                        ? "checkmark" : "square.and.arrow.down"
                    )
                    .font(.system(size: 12, weight: .semibold))
                    Text(viewModel.isOutputLanguageOverrideSaved ? "Saved" : "Save")
                      .font(.custom("Nunito", size: 12))
                  }
                  .padding(.horizontal, 2)
                },
                background: Color.white,
                foreground: Color(red: 0.25, green: 0.17, blue: 0),
                borderColor: Color(hex: "FFE0A5"),
                cornerRadius: 8,
                horizontalPadding: 12,
                verticalPadding: 7,
                showOverlayStroke: true
              )
              .disabled(viewModel.isOutputLanguageOverrideSaved)
              DayflowSurfaceButton(
                action: {
                  viewModel.resetOutputLanguageOverride()
                  isOutputLanguageFocused = false
                },
                content: {
                  Text("Reset")
                    .font(.custom("Nunito", size: 11))
                },
                background: Color.white,
                foreground: Color(red: 0.25, green: 0.17, blue: 0),
                borderColor: Color(hex: "FFE0A5"),
                cornerRadius: 8,
                horizontalPadding: 10,
                verticalPadding: 6,
                showOverlayStroke: true
              )
            }
            Text(
              "The default language is English. You can specify any language here (examples: English, 简体中文, Español, 日本語, 한국어, Français)."
            )
            .font(.custom("Nunito", size: 11.5))
            .foregroundColor(.black.opacity(0.5))
            .fixedSize(horizontal: false, vertical: true)
          }

          Text(
            "Dayflow v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")"
          )
          .font(.custom("Nunito", size: 12))
          .foregroundColor(.black.opacity(0.45))
        }
      }
    }
  }

  private var recordingScheduleCard: some View {
    SettingsCard(title: "Recording schedule", subtitle: "Automatically start and stop recording at specific times") {
      VStack(alignment: .leading, spacing: 14) {
        Toggle(isOn: $viewModel.scheduleEnabled) {
          Text("Enable schedule")
            .font(.custom("Nunito", size: 13))
            .foregroundColor(.black.opacity(0.7))
        }
        .toggleStyle(.switch)

        if viewModel.scheduleEnabled {
          VStack(alignment: .leading, spacing: 14) {
            Text("Recording times")
              .font(.custom("Nunito", size: 12))
              .fontWeight(.semibold)
              .foregroundColor(.black.opacity(0.6))
              .padding(.top, 4)

            HStack(spacing: 14) {
              VStack(alignment: .leading, spacing: 6) {
                Text("Start")
                  .font(.custom("Nunito", size: 11))
                  .foregroundColor(.black.opacity(0.5))
                DatePicker("", selection: $viewModel.scheduleStartTime, displayedComponents: .hourAndMinute)
                  .datePickerStyle(.compact)
                  .labelsHidden()
              }

              Image(systemName: "arrow.right")
                .foregroundColor(.black.opacity(0.35))
                .padding(.top, 12)

              VStack(alignment: .leading, spacing: 6) {
                Text("End")
                  .font(.custom("Nunito", size: 11))
                  .foregroundColor(.black.opacity(0.5))
                DatePicker("", selection: $viewModel.scheduleEndTime, displayedComponents: .hourAndMinute)
                  .datePickerStyle(.compact)
                  .labelsHidden()
              }
            }

            Text("Days of week")
              .font(.custom("Nunito", size: 12))
              .fontWeight(.semibold)
              .foregroundColor(.black.opacity(0.6))
              .padding(.top, 4)

            HStack(spacing: 8) {
              ForEach([
                (1, "S"),  // Sunday
                (2, "M"),  // Monday
                (3, "T"),  // Tuesday
                (4, "W"),  // Wednesday
                (5, "T"),  // Thursday
                (6, "F"),  // Friday
                (7, "S")   // Saturday
              ], id: \.0) { day, label in
                dayButton(day: day, label: label)
              }
            }

            Text("Recording will automatically start and stop during scheduled times on selected days.")
              .font(.custom("Nunito", size: 11.5))
              .foregroundColor(.black.opacity(0.55))
              .padding(.top, 4)
          }
        }
      }
      .padding(.top, 4)
    }
  }

  private func dayButton(day: Int, label: String) -> some View {
    let isSelected = viewModel.scheduleDays.contains(day)

    return Button {
      if isSelected {
        viewModel.scheduleDays.remove(day)
      } else {
        viewModel.scheduleDays.insert(day)
      }
    } label: {
      Text(label)
        .font(.custom("Nunito", size: 13))
        .fontWeight(.semibold)
        .foregroundColor(isSelected ? .white : .black.opacity(0.6))
        .frame(width: 32, height: 32)
        .background(
          Circle()
            .fill(isSelected ? Color(red: 0.25, green: 0.17, blue: 0) : Color.white.opacity(0.6))
        )
        .overlay(
          Circle()
            .stroke(isSelected ? Color.clear : Color.black.opacity(0.2), lineWidth: 1)
        )
    }
    .buttonStyle(PlainButtonStyle())
  }
}
