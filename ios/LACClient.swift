import ActivityKit
import Foundation
import UIKit

/// Talks to /api/sdk/* (see PROTOCOL.md) and observes ActivityKit for LACAttributes.
final class LACClient {
  static let shared = LACClient()
  static let type = "LACAttributes"

  private let defaults = UserDefaults.standard
  private let lock = NSLock()
  private var started = false
  private var seen = Set<String>()
  var onToken: ((String, String) -> Void)? // (kind, token)

  var publishableKey: String? { defaults.string(forKey: "lac.publishableKey") }
  var baseUrl: String { defaults.string(forKey: "lac.baseUrl") ?? "https://liveactivity.dev" }
  var userId: String? { defaults.string(forKey: "lac.userId") }
  var installId: String {
    if let id = defaults.string(forKey: "lac.installId") { return id }
    let id = UUID().uuidString
    defaults.set(id, forKey: "lac.installId")
    return id
  }

  func configure(key: String, baseUrl: String?) {
    defaults.set(key, forKey: "lac.publishableKey") // persisted so background launches can report
    if let baseUrl { defaults.set(baseUrl, forKey: "lac.baseUrl") } else { defaults.removeObject(forKey: "lac.baseUrl") }
    startObserving()
    if userId != nil { Task { await sendIdentify() } }
    Task { await sendDeviceToken() }
  }

  func identify(_ id: String?) {
    if let id { defaults.set(id, forKey: "lac.userId") } else { defaults.removeObject(forKey: "lac.userId") }
    if id != nil { Task { await sendIdentify() } }
  }

  private func sendIdentify() async {
    guard let userId else { return }
    _ = try? await post("/identify", ["installId": installId, "userId": userId])
  }

  // MARK: HTTP

  @discardableResult
  func post(_ path: String, _ body: [String: Any]) async throws -> [String: Any] {
    guard let key = publishableKey else { throw NSError(domain: "LAC", code: 1, userInfo: [NSLocalizedDescriptionKey: "configure() has not been called"]) }
    guard let url = URL(string: baseUrl + "/api/sdk" + path) else { throw URLError(.badURL) }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONSerialization.data(withJSONObject: body)
    // Keep the process alive long enough to finish while the app is in the background.
    let bg = await UIApplication.shared.beginBackgroundTask(withName: "lac-post")
    defer { Task { @MainActor in UIApplication.shared.endBackgroundTask(bg) } }
    let (data, resp) = try await URLSession.shared.data(for: req)
    let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
    let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    guard (200..<300).contains(code) else {
      throw NSError(domain: "LAC", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP \(code): \(json["error"] ?? "")"])
    }
    return json
  }

  private func base(_ extra: [String: Any]) -> [String: Any] {
    var b: [String: Any] = ["installId": installId, "attributesType": Self.type]
    if let userId { b["userId"] = userId }
    return b.merging(extra) { $1 }
  }

  static func hex(_ d: Data) -> String { d.map { String(format: "%02x", $0) }.joined() }

  /// The APNs device token, for an activity's fallbackAlert. Kept in UserDefaults: it can arrive before the first
  /// configure(), which sends it then.
  func setDeviceToken(_ data: Data) {
    defaults.set(Self.hex(data), forKey: "lac.deviceToken")
    Task { await sendDeviceToken() }
  }

  private func sendDeviceToken() async {
    guard publishableKey != nil, let token = defaults.string(forKey: "lac.deviceToken") else { return }
    var body: [String: Any] = ["installId": installId, "token": token]
    if let userId { body["userId"] = userId }
    _ = try? await post("/device-token", body)
  }

  // MARK: Observation

  func startObserving() {
    guard #available(iOS 16.2, *) else { return }
    lock.lock(); defer { lock.unlock() }
    guard !started else { return }
    started = true
    if #available(iOS 17.2, *) {
      Task {
        for await data in Activity<LACAttributes>.pushToStartTokenUpdates {
          let token = Self.hex(data)
          self.onToken?("pushToStart", token)
          _ = try? await self.post("/push-to-start-token", self.base([
            "token": token, "osVersion": UIDevice.current.systemVersion,
          ]))
        }
      }
    }
    Task { for await a in Activity<LACAttributes>.activityUpdates { self.observe(a) } }
    for a in Activity<LACAttributes>.activities { observe(a) }
  }

  @available(iOS 16.2, *)
  private func observe(_ a: Activity<LACAttributes>) {
    lock.lock()
    let isNew = seen.insert(a.id).inserted
    lock.unlock()
    guard isNew else { return }
    Task { await self.report(a) }
    Task {
      for await data in a.pushTokenUpdates {
        self.onToken?("activity", Self.hex(data))
        await self.report(a)
      }
    }
    Task { for await _ in a.activityStateUpdates { await self.report(a) } }
  }

  @available(iOS 16.2, *)
  private func report(_ a: Activity<LACAttributes>) async {
    let state: String
    switch a.activityState {
    case .active: state = "active"
    case .ended: state = "ended"
    case .dismissed: state = "dismissed"
    case .stale: state = "stale"
    default: state = "pending" // iOS 26 scheduled-but-not-started
    }
    var attrs: [String: Any] = ["name": a.attributes.name]
    if let id = a.attributes.lacId { attrs["lacId"] = id }
    var body: [String: Any] = ["activityKitId": a.id, "state": state, "attributes": attrs]
    if let id = a.attributes.lacId { body["lacId"] = id }
    if let t = a.pushToken { body["pushToken"] = Self.hex(t) }
    if let data = try? JSONEncoder().encode(a.content.state),
       let obj = try? JSONSerialization.jsonObject(with: data) { body["contentState"] = obj }
    _ = try? await post("/activity", base(body))
  }

  // MARK: Local control

  @available(iOS 16.2, *)
  func find(_ id: String) -> Activity<LACAttributes>? {
    Activity<LACAttributes>.activities.first { $0.id == id || $0.attributes.lacId == id }
  }

  @available(iOS 16.2, *)
  static func state(_ dict: [String: Any]) throws -> LACAttributes.ContentState {
    try JSONDecoder().decode(LACAttributes.ContentState.self, from: JSONSerialization.data(withJSONObject: dict))
  }

  @available(iOS 16.2, *)
  func start(_ dict: [String: Any], name: String, staleDate: Date?) throws -> String {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      throw NSError(domain: "LAC", code: 2, userInfo: [NSLocalizedDescriptionKey: "Live Activities are disabled"])
    }
    let a = try Activity.request(
      attributes: LACAttributes(lacId: nil, name: name),
      content: .init(state: try Self.state(dict), staleDate: staleDate),
      pushType: .token)
    observe(a)
    return a.id
  }

  func schedule(_ dict: [String: Any], startAt: Date, name: String) async throws -> String {
    var local = false
    if #available(iOS 26.0, *) { local = true }
    let res = try await post("/schedule", base([
      "attributes": ["name": name], "contentState": dict,
      "startAt": Int(startAt.timeIntervalSince1970 * 1000), "localScheduled": local,
    ]))
    guard let id = res["id"] as? String else { throw URLError(.cannotParseResponse) }
    if #available(iOS 26.0, *) {
      // shortcut: if the local request throws the server still believes it is locally scheduled; it falls back to push-to-start after 60 s.
      let state = try Self.state(dict)
      let a = try Activity.request(
        attributes: LACAttributes(lacId: id, name: name),
        content: .init(state: state, staleDate: nil),
        pushType: .token, style: .standard,
        alertConfiguration: .init(title: LocalizedStringResource(stringLiteral: state.title),
                                  body: LocalizedStringResource(stringLiteral: state.subtitle ?? ""), sound: .default),
        start: startAt)
      observe(a)
    }
    return id
  }
}
