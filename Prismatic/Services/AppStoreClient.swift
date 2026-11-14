import Foundation
import ApplePackage

/// App Store access via the vendored ApplePackage (SAP-signed login, version list, IPA download).
/// Only works for apps the signed-in Apple ID has already purchased.
typealias AppStoreAccount = ApplePackage.Account

struct GDVersion: Identifiable, Hashable {
    var id: String { externalId }
    let externalId: String
    let version: String   // CFBundleShortVersionString, e.g. "2.2074"
}

enum StoreError: LocalizedError {
    case twoFactorRequired, notPurchased, http(Int), malformed(String)
    var errorDescription: String? {
        switch self {
        case .twoFactorRequired: return "Enter the 2FA code sent to your devices, then tap Sign in again."
        case .notPurchased: return "This Apple ID hasn't purchased Geometry Dash."
        case .http(let c): return "Server returned HTTP \(c)."
        case .malformed(let m): return "Unexpected response: \(m)"
        }
    }
}

final class AppStoreClient {
    static let shared = AppStoreClient()
    static let gdBundleId = "com.robtop.geometryjump"
    /// Apple wants the same SAP session for the password attempt and the follow-up 2FA code.
    private var pending: Authenticator?

    func login(email: String, password: String, code: String? = nil) async throws -> AppStoreAccount {
        let code = code ?? ""
        do {
            if !code.isEmpty, let session = pending {
                let acct = try await session.authenticate(email: email, password: password, code: code)
                pending = nil
                return acct
            }
            let session = try await Authenticator(cookies: [])
            pending = session
            let acct = try await session.authenticate(email: email, password: password, code: code)
            pending = nil
            return acct
        } catch AuthenticationError.verificationCodeRequired {
            throw StoreError.twoFactorRequired
        }
    }

    private func app(for account: AppStoreAccount) async throws -> Software {
        let country = Configuration.countryCode(for: account.store) ?? "US"
        return try await Lookup.lookup(bundleID: Self.gdBundleId, countryCode: country)
    }

    /// Every historical build this account can download (newest first).
    func versions(account: inout AppStoreAccount) async throws -> [GDVersion] {
        let software = try await app(for: account)
        let ids: [String]
        do { ids = try await VersionFinder.list(account: &account, bundleIdentifier: Self.gdBundleId) }
        catch ApplePackageError.licenseRequired { throw StoreError.notPurchased }
        var out: [GDVersion] = []
        for id in ids { // one request per version; cache this in a real build
            let meta = try? await VersionLookup.getVersionMetadata(account: &account, app: software, versionID: id)
            out.append(GDVersion(externalId: id, version: meta?.displayVersion ?? id))
        }
        return out.sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }

    /// Downloads the IPA for one version, with the FairPlay receipt injected like installd expects.
    func downloadIPA(account: inout AppStoreAccount, externalVersionId: String) async throws -> URL {
        let software = try await app(for: account)
        let output: DownloadOutput
        do { output = try await Download.download(account: &account, app: software, externalVersionID: externalVersionId) }
        catch ApplePackageError.licenseRequired { throw StoreError.notPurchased }
        guard let url = URL(string: output.downloadURL) else { throw StoreError.malformed("bad download URL") }
        let (tmp, _) = try await URLSession.shared.pDownload(from: url)
        try await SignatureInjector.inject(sinfs: output.sinfs, iTunesMetadata: output.iTunesMetadata, into: tmp.path)
        return tmp
    }
}
