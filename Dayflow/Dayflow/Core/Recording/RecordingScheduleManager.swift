//
//  RecordingScheduleManager.swift
//  Dayflow
//
//  Manages automatic recording based on schedule
//

import Foundation
import Combine

@MainActor
final class RecordingScheduleManager: ObservableObject {
    static let shared = RecordingScheduleManager()
    
    /// Whether current time is within the scheduled recording window
    @Published private(set) var isInScheduledWindow: Bool = false
    
    /// Whether schedule is currently enabled
    var scheduleEnabled: Bool {
        RecordingSchedulePreferences.shared.isEnabled
    }
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        startTimer()
        evaluateSchedule()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Public API
    
    /// Determine if recording should be active right now based on schedule
    /// Returns nil if schedule is disabled (manual control)
    func shouldBeRecording() -> Bool? {
        guard scheduleEnabled else {
            return nil // Schedule disabled, defer to manual control
        }
        
        // If manually paused, don't record even if in scheduled window
        if PauseManager.shared.isPaused {
            return false
        }
        
        return isInScheduledWindow
    }
    
    /// Force re-evaluation of schedule (useful when settings change)
    func refresh() {
        objectWillChange.send()
        evaluateSchedule()
    }
    
    // MARK: - Schedule Evaluation
    
    private func evaluateSchedule() {
        let schedule = RecordingSchedulePreferences.shared.schedule
        
        guard schedule.isEnabled else {
            isInScheduledWindow = false
            return
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Check if today is in scheduled days
        let weekday = calendar.component(.weekday, from: now)
        guard schedule.daysOfWeek.contains(weekday) else {
            isInScheduledWindow = false
            return
        }
        
        // Get current time components
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTimeInMinutes = currentHour * 60 + currentMinute
        
        // Get scheduled time range
        let startTimeInMinutes = schedule.startHour * 60 + schedule.startMinute
        let endTimeInMinutes = schedule.endHour * 60 + schedule.endMinute
        
        // Check if current time is within the scheduled window
        let wasInWindow = isInScheduledWindow
        
        if endTimeInMinutes > startTimeInMinutes {
            // Normal case: e.g., 9:00 AM to 5:00 PM
            isInScheduledWindow = currentTimeInMinutes >= startTimeInMinutes && currentTimeInMinutes < endTimeInMinutes
        } else {
            // Spans midnight: e.g., 11:00 PM to 2:00 AM
            isInScheduledWindow = currentTimeInMinutes >= startTimeInMinutes || currentTimeInMinutes < endTimeInMinutes
        }
        
        // If window state changed, update recording state
        if wasInWindow != isInScheduledWindow {
            applyScheduleToRecording()
        }
    }
    
    /// Apply schedule state to AppState.isRecording
    private func applyScheduleToRecording() {
        guard scheduleEnabled else { return }
        
        // Don't override manual pause
        if PauseManager.shared.isPaused {
            return
        }
        
        let shouldRecord = isInScheduledWindow
        
        if AppState.shared.isRecording != shouldRecord {
            AppState.shared.isRecording = shouldRecord
            
            let action = shouldRecord ? "started" : "stopped"
            AnalyticsService.shared.capture("recording_schedule_\(action)", [
                "in_window": isInScheduledWindow
            ])
        }
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        stopTimer()
        
        // Check schedule every minute
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluateSchedule()
            }
        }
        
        // Ensure timer fires even when menu is open
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
