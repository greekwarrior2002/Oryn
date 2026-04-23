// Intentionally empty.
//
// The original `WeekDaySection` / `WeekTaskRow` were tightly coupled to the
// old "passive progress per day" design of the Week tab. The redesigned Week
// view (see WeekView.swift) composes richer per-day rows from `WeekPlanDay`
// rather than raw `ScheduleDay`, so these types are no longer used.
//
// The file itself is kept as a slot in the Xcode project to avoid touching
// `project.pbxproj`; it's a no-op at compile time.

import Foundation
