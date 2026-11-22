// Default Live Activity UI. The config plugin only writes this file if it does not exist yet:
// edit it freely (or point the plugin's `viewFile` option at your own copy).
import ActivityKit
import SwiftUI
import WidgetKit

struct LACLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LACAttributes.self) { context in
      LACLockScreenView(state: context.state)
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.75))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      let s = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) { Text(s.title).font(.headline) }
        DynamicIslandExpandedRegion(.trailing) { LACCountdown(state: s) }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            if let sub = s.subtitle { Text(sub).font(.subheadline) }
            if let p = s.progress { ProgressView(value: min(max(p, 0), 1)) }
          }
        }
      } compactLeading: {
        Text(s.status ?? s.title).lineLimit(1)
      } compactTrailing: {
        LACCountdown(state: s).frame(maxWidth: 48)
      } minimal: {
        Image(systemName: "bolt.fill")
      }
    }
  }
}

struct LACCountdown: View {
  let state: LACAttributes.ContentState
  var body: some View {
    if let end = state.endDate, Date(timeIntervalSince1970: end) > Date() {
      Text(timerInterval: Date.now...Date(timeIntervalSince1970: end), countsDown: true)
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }
  }
}

struct LACLockScreenView: View {
  let state: LACAttributes.ContentState
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(state.title).font(.headline)
        Spacer()
        LACCountdown(state: state)
      }
      if let sub = state.subtitle { Text(sub).font(.subheadline).foregroundStyle(.secondary) }
      if let p = state.progress { ProgressView(value: min(max(p, 0), 1)) }
      if let status = state.status { Text(status).font(.caption) }
    }
  }
}
