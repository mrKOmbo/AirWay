//
//  PPILogger.swift
//  AirWayWatch Watch App
//
//  Centralized logger using os.Logger so logs appear in Console.app and log show.
//  Swift print() doesn't reliably appear in the unified log on watchOS.
//

import os

enum PPILog {
    private static let subsystem = "com.airway.ppi"

    static let demo     = Logger(subsystem: subsystem, category: "DEMO")
    static let engine   = Logger(subsystem: subsystem, category: "PPI-ENGINE")
    static let sigmoid  = Logger(subsystem: subsystem, category: "PPI-SIGMOID")
    static let baseline = Logger(subsystem: subsystem, category: "BASELINE")
    static let content  = Logger(subsystem: subsystem, category: "CONTENT")
    static let haptic   = Logger(subsystem: subsystem, category: "HAPTIC")
    static let health     = Logger(subsystem: subsystem, category: "HEALTHKIT")
    static let wc         = Logger(subsystem: subsystem, category: "WC-WATCH")
    static let cigarette  = Logger(subsystem: subsystem, category: "CIGARETTE")
}
