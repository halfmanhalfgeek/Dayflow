import SwiftUI

struct SettingsOtherTabView: View {
  @ObservedObject var viewModel: OtherSettingsViewModel
  @ObservedObject var launchAtLoginManager: LaunchAtLoginManager
  @AppStorage(DayflowAppearance.storageKey) private var appearance: DayflowAppearance = .system
  @FocusState private var isOutputLanguageFocused: Bool
  @State private var appLanguage = AppLanguagePreferences.selection()

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
      title: String(localized: "App preferences"),
      subtitle: String(localized: "General toggles and telemetry settings.")
    ) {
      VStack(alignment: .leading, spacing: 0) {
        SettingsRow(
          label: String(localized: "App language"),
          subtitle: String(
            localized:
              "Choose a language for Dayflow only. Quit and reopen the app to apply a change.")
        ) {
          Picker("App language", selection: $appLanguage) {
            ForEach(AppLanguage.allCases) { language in
              Text(verbatim: language.title).tag(language)
            }
          }
          .pickerStyle(.menu)
          .labelsHidden()
          .frame(width: 210)
          .onChange(of: appLanguage) {
            AppLanguagePreferences.setSelection(appLanguage)
          }
        }

        SettingsRow(
          label: String(localized: "Light/Dark mode"),
          subtitle: String(localized: "Follow the system setting or pick light or dark.")
        ) {
          Picker("", selection: $appearance) {
            ForEach(DayflowAppearance.allCases) { option in
              Text(option.title).tag(option)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          .frame(width: 210)
          .onChange(of: appearance) { _, newValue in
            AnalyticsService.shared.capture(
              "appearance_changed", ["appearance": newValue.rawValue])
          }
        }

        SettingsRow(
          label: String(localized: "Launch Dayflow at login"),
          subtitle:
            String(
              localized:
                "Keeps the menu bar controller running right after you sign in so capture can resume instantly."
            )
        ) {
          SettingsToggle(
            isOn: Binding(
              get: { launchAtLoginManager.isEnabled },
              set: { launchAtLoginManager.setEnabled($0) }
            )
          )
        }

        SettingsRow(
          label: String(localized: "Pause lengths"),
          subtitle: String(localized: "The three timed options shown when you pause Dayflow.")
        ) {
          HStack(spacing: 6) {
            ForEach(viewModel.pausePresetMinutes.indices, id: \.self) { index in
              Picker("Pause length", selection: $viewModel.pausePresetMinutes[index]) {
                ForEach(PausePresets.minuteOptions, id: \.self) { minutes in
                  Text(verbatim: PauseDuration.timed(minutes: minutes).shortLabel).tag(minutes)
                }
              }
              .pickerStyle(.menu)
              .labelsHidden()
              .frame(width: 78)
            }
          }
        }

        SettingsRow(label: String(localized: "Share crash reports and anonymous usage data")) {
          SettingsToggle(isOn: $viewModel.analyticsEnabled)
        }

        SettingsRow(
          label: String(localized: "Show Dock icon"),
          subtitle: String(localized: "When off, Dayflow runs as a menu bar-only app.")
        ) {
          SettingsToggle(isOn: $viewModel.showDockIcon)
        }

        SettingsRow(
          label: String(localized: "Show app/website icons in timeline"),
          subtitle: String(localized: "When off, timeline cards won't show app or website icons.")
        ) {
          SettingsToggle(isOn: $viewModel.showTimelineAppIcons)
        }

        SettingsRow(
          label: String(localized: "Show daily goal popups"),
          subtitle:
            String(
              localized:
                "When off, Dayflow won't automatically open goal setup or yesterday's review after 4am."
            )
        ) {
          SettingsToggle(isOn: $viewModel.showDailyGoalPopups)
        }

        SettingsRow(
          label: String(localized: "Save all timelapses to disk"),
          subtitle:
            String(
              localized:
                "New and reprocessed timeline cards will pre-generate timelapse videos and store them on disk instead of building them on demand. Uses more storage and background processing."
            )
        ) {
          SettingsToggle(isOn: $viewModel.saveAllTimelapsesToDisk)
        }

        SettingsRow(
          label: String(localized: "Getting started guide"),
          subtitle: String(
            localized:
              "Replay the welcome tour and bring back the first-day checklist on your timeline."),
          showsDivider: false
        ) {
          SettingsSecondaryButton(
            title: String(localized: "Show again"),
            action: { GettingStarted.replay() }
          )
        }
      }
    }
  }

  // MARK: - Output language override

  private var outputLanguageSection: some View {
    SettingsSection(
      title: String(localized: "Output language override"),
      subtitle:
        String(
          localized:
            "AI output follows the app language by default. Enter a language to override it, or reset to follow the app language. Existing summaries stay unchanged."
        )
    ) {
      HStack(spacing: 10) {
        TextField("App language", text: $viewModel.outputLanguageOverride)
          .textFieldStyle(.roundedBorder)
          .disableAutocorrection(true)
          .frame(maxWidth: 220)
          .focused($isOutputLanguageFocused)
          .onChange(of: viewModel.outputLanguageOverride) {
            viewModel.markOutputLanguageOverrideEdited()
          }

        SettingsSecondaryButton(
          title: viewModel.isOutputLanguageOverrideSaved
            ? String(localized: "Saved") : String(localized: "Save"),
          systemImage: viewModel.isOutputLanguageOverrideSaved
            ? "checkmark" : nil,
          isDisabled: viewModel.isOutputLanguageOverrideSaved,
          action: {
            viewModel.saveOutputLanguageOverride()
            isOutputLanguageFocused = false
          }
        )

        SettingsSecondaryButton(
          title: String(localized: "Reset"),
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
