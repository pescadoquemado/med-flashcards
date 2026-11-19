import SwiftUI
import UIKit

enum Theme {
    static let teal = Color(red: 0.05, green: 0.35, blue: 0.42)
    static let red = Color(red: 0.88, green: 0.27, blue: 0.23)
    static let amber = Color(red: 0.72, green: 0.46, blue: 0.10)
    static let green = Color(red: 0.07, green: 0.52, blue: 0.43)
    static let blue = Color(red: 0.18, green: 0.44, blue: 0.86)

    // Counter colours on the dark teal bar (new · learning · due), Anki-style.
    static let countNew = Color(red: 0.61, green: 0.77, blue: 1.0)
    static let countLearn = Color(red: 1.0, green: 0.69, blue: 0.66)
    static let countDue = Color(red: 0.56, green: 0.88, blue: 0.78)

    static let cardBG = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.19, blue: 0.22, alpha: 1)
            : UIColor(red: 1.0, green: 0.99, blue: 0.97, alpha: 1)
    })

    static let rule = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.27, blue: 0.31, alpha: 1)
            : UIColor(red: 0.84, green: 0.90, blue: 0.95, alpha: 1)
    })
}

extension Rating {
    var color: Color {
        switch self {
        case .again: return Theme.red
        case .hard: return Theme.amber
        case .good: return Theme.green
        case .easy: return Theme.blue
        }
    }
}
