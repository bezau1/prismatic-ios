import SwiftUI

struct SignInView: View {
    @EnvironmentObject var acct: AccountState
    @Environment(\.dismiss) var dismiss
    @State private var email = "", password = "", code = ""
    @State private var needs2FA = false, busy = false, error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("Use the Apple ID that purchased Geometry Dash. Credentials go straight to Apple; only a session token is stored.")) {
                    TextField("Apple ID", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                    if needs2FA { TextField("2FA code", text: $code).keyboardType(.numberPad) }
                }
                if let error { Text(error).foregroundStyle(.red) }
                Button(busy ? "Signing in…" : "Sign in") { Task { await go() } }.disabled(busy || email.isEmpty)
                if acct.account != nil { Button("Sign out", role: .destructive) { acct.account = nil; dismiss() } }
            }.navigationTitle("App Store")
        }
    }
    func go() async {
        busy = true; defer { busy = false }
        do {
            acct.account = try await AppStoreClient().login(email: email, password: password, code: needs2FA ? code : nil)
            dismiss()
        } catch StoreError.twoFactorRequired { needs2FA = true; error = "Enter the code Apple just sent, then tap Sign in again." }
        catch { self.error = error.localizedDescription }
    }
}
