import Foundation

/// Talks to Apple's private iTunes/App Store endpoints (same protocol ipatool uses).
/// Only works for apps the signed-in Apple ID has already purchased.
struct AppStoreAccount: Codable {
    var email: String
    var dsid: String
    var passwordToken: String
    var storeFront: String
}

struct GDVersion: Identifiable, Hashable {
    var id: String { externalId }
    let externalId: String
    let version: String   // CFBundleShortVersionString, e.g. "2.2074"
}

enum StoreError: LocalizedError {
    case twoFactorRequired, badCredentials, notPurchased, http(Int), malformed(String)
    var errorDescription: String? {
        switch self {
        case .twoFactorRequired: return "Enter the 2FA code sent to your devices."
        case .badCredentials: return "Wrong Apple ID or password."
        case .notPurchased: return "This Apple ID hasn't purchased Geometry Dash."
        case .http(let c): return "Server returned HTTP \(c)."
        case .malformed(let m): return "Unexpected response: \(m)"
        }
    }
}

final class AppStoreClient {
    static let gdBundleId = "com.robtop.geometryjump"
    private let guid: String = {
        // Stable pseudo-device id; ipatool uses the Mac's MAC address.
        let k = "prismatic.guid"
        if let g = UserDefaults.standard.string(forKey: k) { return g }
        let g = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)).uppercased()
        UserDefaults.standard.set(g, forKey: k); return g
    }()
    private let ua = "Configurator/2.17 (Macintosh; OS X 15.2; 24C5089c) AppleWebKit/0620.1.16.11.6"
    private let session = URLSession(configuration: .ephemeral)

    // MARK: Auth
    func login(email: String, password: String, code: String? = nil) async throws -> AppStoreAccount {
        var url = URL(string: "https://auth.itunes.apple.com/auth/MZFinance.woa/wa/authenticate?guid=\(guid)")!
        for _ in 0..<4 { // follow Apple's regional redirects, resending the body
            let body: [String: Any] = [
                "appleId": email, "attempt": code == nil ? "4" : "2", "createSession": "true",
                "guid": guid, "password": password + (code ?? ""), "rmp": "0", "why": "signIn"]
            let (plist, resp) = try await post(url, body)
            if resp.statusCode == 302, let loc = resp.value(forHTTPHeaderField: "Location"),
               let u = URL(string: loc) { url = u; continue }
            if let fail = plist["failureType"] as? String, !fail.isEmpty {
                if fail == "-5000" || (plist["customerMessage"] as? String)?.contains("Configurator_message") == true {
                    throw StoreError.twoFactorRequired
                }
                throw StoreError.badCredentials
            }
            guard let dsid = plist["dsPersonId"] as? String, let tok = plist["passwordToken"] as? String
            else { throw StoreError.malformed("no session in auth reply") }
            let sf = resp.value(forHTTPHeaderField: "x-set-apple-store-front")?
                .components(separatedBy: "-").first ?? "143441"
            return AppStoreAccount(email: email, dsid: dsid, passwordToken: tok, storeFront: sf)
        }
        throw StoreError.malformed("too many redirects")
    }

    // MARK: Lookup / versions
    func trackId(country: String = "US") async throws -> Int {
        let u = URL(string: "https://itunes.apple.com/lookup?bundleId=\(Self.gdBundleId)&country=\(country)")!
        let (d, _) = try await session.data(from: u)
        let j = try JSONSerialization.jsonObject(with: d) as? [String: Any]
        guard let r = (j?["results"] as? [[String: Any]])?.first, let id = r["trackId"] as? Int
        else { throw StoreError.malformed("app not found in storefront") }
        return id
    }

    /// Lists every historical build the account can download.
    func versions(account: AppStoreAccount) async throws -> [GDVersion] {
        let app = try await trackId()
        let latest = try await downloadInfo(account: account, appId: app, versionId: nil)
        let ids = (latest.metadata["softwareVersionExternalIdentifiers"] as? [Any])?.map { "\($0)" } ?? []
        var out: [GDVersion] = []
        for id in ids { // each lookup is one request; cache this in a real build
            if let info = try? await downloadInfo(account: account, appId: app, versionId: id),
               let v = info.metadata["bundleShortVersionString"] as? String {
                out.append(GDVersion(externalId: id, version: v))
            }
        }
        return out.sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }

    struct DownloadInfo { let url: URL; let sinf: Data?; let metadata: [String: Any] }

    func downloadInfo(account: AppStoreAccount, appId: Int, versionId: String?) async throws -> DownloadInfo {
        var body: [String: Any] = ["creditDisplay": "", "guid": guid, "salableAdamId": "\(appId)"]
        if let v = versionId { body["externalVersionId"] = v }
        let url = URL(string: "https://p25-buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/volumeStoreDownloadProduct?guid=\(guid)")!
        let (plist, _) = try await post(url, body, account: account)
        if (plist["failureType"] as? String)?.isEmpty == false { throw StoreError.notPurchased }
        guard let item = (plist["songList"] as? [[String: Any]])?.first,
              let s = item["URL"] as? String, let u = URL(string: s),
              let meta = item["metadata"] as? [String: Any]
        else { throw StoreError.malformed("no songList") }
        let sinf = ((item["sinfs"] as? [[String: Any]])?.first?["sinf"]) as? Data
        return DownloadInfo(url: u, sinf: sinf, metadata: meta)
    }

    // MARK: HTTP
    private func post(_ url: URL, _ body: [String: Any], account: AppStoreAccount? = nil)
        async throws -> ([String: Any], HTTPURLResponse) {
        var r = URLRequest(url: url); r.httpMethod = "POST"
        r.setValue(ua, forHTTPHeaderField: "User-Agent")
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let a = account {
            r.setValue(a.dsid, forHTTPHeaderField: "X-Dsid")
            r.setValue(a.dsid, forHTTPHeaderField: "iCloud-DSID")
            r.setValue(a.passwordToken, forHTTPHeaderField: "X-Token")
        }
        r.httpBody = try PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
        let noRedirect = RedirectBlocker()
        let (d, resp) = try await session.data(for: r, delegate: noRedirect)
        let http = resp as! HTTPURLResponse
        let plist = (try? PropertyListSerialization.propertyList(from: d, format: nil)) as? [String: Any] ?? [:]
        if http.statusCode >= 400 { throw StoreError.http(http.statusCode) }
        return (plist, http)
    }
}

private final class RedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ s: URLSession, task: URLSessionTask, willPerformHTTPRedirection r: HTTPURLResponse,
                    newRequest: URLRequest) async -> URLRequest? { nil }
}
