import Foundation

/// Selectable look for the menu-bar toggle. Each style provides the SF Symbol
/// shown when collapsed (icons hidden) vs. expanded (icons visible).
enum ToggleStyle: String, CaseIterable, Identifiable {
    case chevronCompact
    case chevron
    case arrow
    case triangle
    case eye
    case circle
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chevronCompact: return "Chevron (thin)"
        case .chevron:        return "Chevron"
        case .arrow:          return "Arrow"
        case .triangle:       return "Triangle"
        case .eye:            return "Eye"
        case .circle:         return "Half circle"
        case .custom:         return "Custom (emoji / image)"
        }
    }

    /// SF Symbol name for the built-in styles. `.custom` falls back to a chevron
    /// (used only for previews / when no emoji or image is set).
    func symbolName(collapsed: Bool) -> String {
        switch self {
        case .chevronCompact: return collapsed ? "chevron.compact.left" : "chevron.compact.right"
        case .chevron:        return collapsed ? "chevron.left" : "chevron.right"
        case .arrow:          return collapsed ? "arrow.left" : "arrow.right"
        case .triangle:       return collapsed ? "arrowtriangle.left.fill" : "arrowtriangle.right.fill"
        case .eye:            return collapsed ? "eye.slash" : "eye"
        case .circle:         return collapsed ? "circle.lefthalf.filled" : "circle.righthalf.filled"
        case .custom:         return "star"
        }
    }
}

/// Selectable look for the divider handle(s).
enum DividerStyle: String, CaseIterable, Identifiable {
    case diagonal
    case dots
    case dot
    case dash
    case bars

    var id: String { rawValue }

    var title: String {
        switch self {
        case .diagonal: return "Slash"
        case .dots:     return "Dots"
        case .dot:      return "Dot"
        case .dash:     return "Dash"
        case .bars:     return "Bars"
        }
    }

    var symbolName: String {
        switch self {
        case .diagonal: return "line.diagonal"
        case .dots:     return "ellipsis"
        case .dot:      return "circle.fill"
        case .dash:     return "minus"
        case .bars:     return "line.3.horizontal"
        }
    }

    /// A visually distinct glyph for the deeper "always-hidden" divider so the
    /// two dividers can be told apart.
    var alwaysHiddenSymbolName: String {
        switch self {
        case .diagonal: return "line.diagonal.arrow"
        case .dots:     return "ellipsis.circle"
        case .dot:      return "smallcircle.filled.circle"
        case .dash:     return "minus.circle"
        case .bars:     return "line.3.horizontal.decrease"
        }
    }
}
