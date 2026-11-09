import SwiftUI

struct LanguageMenu: View {
    let lang: Lang
    @Binding var langRaw: String

    var body: some View {
        Menu {
            ForEach(Lang.allCases) { lg in
                Button {
                    langRaw = lg.rawValue
                } label: {
                    if lang == lg {
                        Label(lg.rawValue.uppercased(), systemImage: "checkmark")
                    } else {
                        Text(lg.rawValue.uppercased())
                    }
                }
            }
        } label: {
            Label(lang.rawValue.uppercased(), systemImage: "globe")
        }
        .accessibilityLabel(lang.rawValue.uppercased())
    }
}
