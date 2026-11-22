import ActivityKit
import Foundation

// Shared by the app (pod) and the widget extension: the config plugin copies this file into the extension.
// The type name is the wire `attributesType`; do not rename.
public struct LACAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    public var title: String
    public var subtitle: String?
    public var progress: Double?
    public var endDate: Double? // epoch seconds
    public var status: String?
    public var values: [String: String]?
  }

  public var lacId: String?
  public var name: String
}
