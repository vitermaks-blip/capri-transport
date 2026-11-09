import Foundation

enum AppSupport {
    static let email = "support.oraricapri@gmail.com"

    static var mailURL: URL? {
        URL(string: "mailto:\(email)?subject=\(subjectFragment)")
    }

    private static var subjectFragment: String {
        "Capri%20Transport"
    }
}
