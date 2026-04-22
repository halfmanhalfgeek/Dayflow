import SwiftUI

struct SettingsOtherTabView: View {
  @ObservedObject var viewModel: OtherSettingsViewModel
  @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
  @FocusState private var isOutputLanguageFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: SettingsStyle.sectionSpacing) {
      recordingScheduleSection
      appPreferencesSection
      outputLanguageSection
    }
  }

  // MARK: - Recording schedule

  private var recordingScheduleSection: some View {
    SettingsSection(
      title: "Recording schedule",
      subtitle: "Automatically start and stop recording at specific times."
    ) {
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

  // MARK: - App preferences

  private var appPreferencesSection: some View {
    SettingsSection(
      title: "App preferences",
      subtitle: "General toggles and telemetry settings."
    ) {
      VStack(alignment: .leading, spacing: 0) {
        SettingsRow(
          label: "Launch Dayflow at login",
          subtitle:
            "Keeps the menu bar controller running right after you sign in so capture can resume instantly."
        ) {
          SettingsToggle(
            isOn: Binding(
              get: { launchAtLoginManager.isEnabled },
              set: { launchAtLoginManager.setEnabled($0) }
            )
          )
        }

        SettingsRow(label: "Share crash reports and anonymous usage data") {
          SettingsToggle(isOn: $viewModel.analyticsEnabled)
        }

        SettingsRow(
          label: "Show Dock icon",
          subtitle: "When off, Dayflow runs as a menu bar-only app."
        ) {
          SettingsToggle(isOn: $viewModel.showDockIcon)
        }

        SettingsRow(
          label: "Show app/website icons in timeline",
          subtitle: "When off, timeline cards won't show app or website icons."
        ) {
          SettingsToggle(isOn: $viewModel.showTimelineAppIcons)
        }

        SettingsRow(
          label: "Save all timelapses to disk",
          subtitle:
            "New and reprocessed timeline cards will pre-generate timelapse videos and store them on disk instead of building them on demand. Uses more storage and background processing.",
          showsDivider: false
        ) {
          SettingsToggle(isOn: $viewModel.saveAllTimelapsesToDisk)
        }
      }
    }
  }
  // MARK: - Output language override

  private var outputLanguageSection: some View {
    SettingsSection(
      title: "Output language override",
      subtitle:
        "The default language is English. You can specify any language here (examples: English, 简体中文, Español, 日本語, 한국어, Français)."
    ) {
      HStack(spacing: 10) {
        TextField("English", text: $viewModel.outputLanguageOverride)
          .textFieldStyle(.roundedBorder)
          .disableAutocorrection(true)
          .frame(maxWidth: 220)
          .focused($isOutputLanguageFocused)
          .onChange(of: viewModel.outputLanguageOverride) {
            viewModel.markOutputLanguageOverrideEdited()
          }

        SettingsSecondaryButton(
          title: viewModel.isOutputLanguageOverrideSaved ? "Saved" : "Save",
          systemImage: viewModel.isOutputLanguageOverrideSaved
            ? "checkmark" : nil,
          isDisabled: viewModel.isOutputLanguageOverrideSaved,
          action: {
            viewModel.saveOutputLanguageOverride()
            isOutputLanguageFocused = false
          }
        )

        SettingsSecondaryButton(
          title: "Reset",
          action: {
            viewModel.resetOutputLanguageOverride()
            isOutputLanguageFocused = false
          }
        )

        Spacer()
      }
    }
  }
}
