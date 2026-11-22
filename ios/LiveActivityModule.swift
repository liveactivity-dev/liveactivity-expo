import ExpoModulesCore
import ActivityKit

public class LiveActivityModule: Module {
  public func definition() -> ModuleDefinition {
    Name("LiveActivity")
    Events("onToken")

    OnCreate {
      LACClient.shared.onToken = { [weak self] kind, token in
        self?.sendEvent("onToken", ["kind": kind, "token": token])
      }
      LACClient.shared.startObserving()
    }

    Function("configure") { (key: String, baseUrl: String?) in LACClient.shared.configure(key: key, baseUrl: baseUrl) }
    Function("identify") { (userId: String?) in LACClient.shared.identify(userId) }

    AsyncFunction("start") { (state: [String: Any], name: String, staleDateMs: Double?) -> String in
      guard #available(iOS 16.2, *) else { throw unsupported() }
      return try LACClient.shared.start(state, name: name, staleDate: staleDateMs.map { Date(timeIntervalSince1970: $0 / 1000) })
    }

    AsyncFunction("schedule") { (state: [String: Any], startAtMs: Double, name: String) -> String in
      guard #available(iOS 16.2, *) else { throw unsupported() }
      return try await LACClient.shared.schedule(state, startAt: Date(timeIntervalSince1970: startAtMs / 1000), name: name)
    }

    AsyncFunction("update") { (id: String, state: [String: Any]) in
      guard #available(iOS 16.2, *), let a = LACClient.shared.find(id) else { throw notFound(id) }
      await a.update(ActivityContent(state: try LACClient.state(state), staleDate: nil))
    }

    AsyncFunction("end") { (id: String, state: [String: Any]?) in
      guard #available(iOS 16.2, *), let a = LACClient.shared.find(id) else { throw notFound(id) }
      let content = try state.map { ActivityContent(state: try LACClient.state($0), staleDate: nil) }
      await a.end(content, dismissalPolicy: .default)
    }
  }

  private func unsupported() -> Exception { Exception(name: "ERR_UNSUPPORTED", description: "Live Activities need iOS 16.2+") }
  private func notFound(_ id: String) -> Exception { Exception(name: "ERR_NOT_FOUND", description: "No running activity \(id)") }
}
