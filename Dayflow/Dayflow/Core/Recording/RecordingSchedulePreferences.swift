//
//  RecordingSchedulePreferences.swift
//  Dayflow
//
//  Manages recording schedule preferences and storage
//

import Foundation

/// Recording schedule configuration
struct RecordingSchedule: Codable, Equatable {
    var isEnabled: Bool
    var startHour: Int       // 0-23
    var startMinute: Int     // 0-59
    var endHour: Int         // 0-23
    var endMinute: Int       // 0-59
    var daysOfWeek: Set<Int> // 1=Sunday, 2=Monday, ..., 7=Saturday
    
    static var `default`: RecordingSchedule {
        RecordingSchedule(
            isEnabled: false,
            startHour: 9,
            startMinute: 0,
            endHour: 17,
            endMinute: 0,
            daysOfWeek: [2, 3, 4, 5, 6] // Monday-Friday
        )
    }
    
    /// Get start time as DateComponents
    var startTimeComponents: DateComponents {
        DateComponents(hour: startHour, minute: startMinute)
    }
    
    /// Get end time as DateComponents
    var endTimeComponents: DateComponents {
        DateComponents(hour: endHour, minute: endMinute)
    }
    
    /// Convert start time to Date (using today as base)
    func startTimeAsDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        return calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: now) ?? now
    }
    
    /// Convert end time to Date (using today as base)
    func endTimeAsDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        return calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: now) ?? now
    }
}

/// Manages storage and retrieval of recording schedule preferences
final class RecordingSchedulePreferences {
    static let shared = RecordingSchedulePreferences()
    
    private let scheduleKey = "recordingSchedule"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {}
    
    /// Get the current schedule
    var schedule: RecordingSchedule {
        get {
            guard let data = UserDefaults.standard.data(forKey: scheduleKey),
                  let schedule = try? decoder.decode(RecordingSchedule.self, from: data) else {
                return .default
            }
            return schedule
        }
        set {
            if let data = try? encoder.encode(newValue) {
                UserDefaults.standard.set(data, forKey: scheduleKey)
            }
        }
    }
    
    /// Check if schedule is enabled
    var isEnabled: Bool {
        get { schedule.isEnabled }
        set {
            var current = schedule
            current.isEnabled = newValue
            schedule = current
        }
    }
    
    /// Update schedule settings
    func updateSchedule(
        enabled: Bool? = nil,
        startHour: Int? = nil,
        startMinute: Int? = nil,
        endHour: Int? = nil,
        endMinute: Int? = nil,
        daysOfWeek: Set<Int>? = nil
    ) {
        var current = schedule
        
        if let enabled = enabled {
            current.isEnabled = enabled
        }
        if let startHour = startHour {
            current.startHour = startHour
        }
        if let startMinute = startMinute {
            current.startMinute = startMinute
        }
        if let endHour = endHour {
            current.endHour = endHour
        }
        if let endMinute = endMinute {
            current.endMinute = endMinute
        }
        if let daysOfWeek = daysOfWeek {
            current.daysOfWeek = daysOfWeek
        }
        
        schedule = current
    }
}
