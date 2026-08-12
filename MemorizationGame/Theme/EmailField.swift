import SwiftUI

struct EmailField: View {
    @Binding var email: String

    var body: some View {
        TextField("So I can write back", text: $email)
            .appFont(Typography.body)
            .foregroundStyle(Theme.ink)
            .tint(Theme.accent)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
    }
}
