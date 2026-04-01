import Foundation
import SwiftUI

enum RepeatMode: String, CaseIterable {
    case none
    case one
    case all
}

enum EQPreset: String, CaseIterable {
    case flat
    case bass
    case vocal
    case rock
    case electronic
    
    var displayName: String {
        switch self {
        case .flat: return "Flat"
        case .bass: return "Bass Boost"
        case .vocal: return "Vocal"
        case .rock: return "Rock"
        case .electronic: return "Electronic"
        }
    }
    
    // Band gains for 5-band EQ: [60Hz, 250Hz, 1kHz, 4kHz, 10kHz]
    var bandGains: [Float] {
        switch self {
        case .flat: return [0, 0, 0, 0, 0]
        case .bass: return [6, 4, 0, 0, 2]
        case .vocal: return [-2, 0, 4, 2, 0]
        case .rock: return [4, 2, -1, 3, 4]
        case .electronic: return [4, 2, 0, 2, 5]
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case tr
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .en: return "English"
        case .tr: return "Türkçe"
        }
    }
}
