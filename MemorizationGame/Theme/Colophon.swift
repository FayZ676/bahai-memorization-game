import SwiftUI

struct Colophon: View {
    let author: String

    var body: some View {
        Text("—\u{00A0}\(author)")
            .appFont(Typography.attribution)
            .foregroundStyle(Theme.faint)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
