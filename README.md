# @liveactivity/expo

Live Activities for Expo / React Native, driven from your backend through LiveActivity (push-to-start, updates, end).
iOS only. The module ships one generic activity type, `LACAttributes`, with a fixed content state, so no custom Swift is needed.

## Install

```sh
npx expo install @liveactivity/expo expo-build-properties
```

`app.json`:

```json
{ "expo": { "plugins": [
  ["expo-build-properties", { "ios": { "deploymentTarget": "16.2" } }],
  "@liveactivity/expo"
] } }
```

Then `npx expo prebuild --platform ios` and run a dev build (not Expo Go). The plugin adds `NSSupportsLiveActivities`
(+ frequent updates), the `aps-environment` entitlement, and a `LACWidget` extension target with `LACAttributes.swift`
and a default Live Activity + Dynamic Island view. Edit `ios/LACWidget/LACLiveActivityView.swift` (it is not overwritten
on later prebuilds), or pass `{ viewFile: "path/to/View.swift" }` as plugin option to replace it.

## Quickstart

```ts
import * as LAC from '@liveactivity/expo';

LAC.configure({ publishableKey: 'pk_...' });   // call at startup; baseUrl optional
LAC.identify(user.id);                         // or null on logout

const id = await LAC.start({ title: 'Order #1', progress: 0.2, endDate: Date.now() / 1000 + 600 }, { name: 'order' });
await LAC.update(id, { title: 'Order #1', progress: 0.7 });
await LAC.end(id, { title: 'Delivered', progress: 1 });

await LAC.schedule({ title: 'Kickoff' }, new Date(Date.now() + 120_000)); // returns server activity id
LAC.addTokenListener(({ kind, token }) => {});
```

`ContentState`: `title`, `subtitle?`, `progress?` (0..1), `endDate?` (epoch seconds, shows a countdown), `status?`, `values?` (string map).
`start`/`schedule` ids work with `update`/`end`. Start from your backend with the secret key (`POST /api/v1/activities`)
using `attributesType: "LACAttributes"`, `attributes: { name }` and the same content state keys.

The key and install id are stored in UserDefaults, and observation starts in the app delegate, so a background launch
caused by a push-to-start still reports its tokens (after `configure` has run once).

## Limits

- Real device only; the iOS Simulator does not issue push tokens.
- Push-to-start needs iOS 17.2+. Local start/update/end work from iOS 16.2.
- `schedule` uses a local scheduled start on iOS 26+; before that, the server starts it with a push (needs a push-to-start token, so iOS 17.2+).
- Content state is fixed to the `LACAttributes.ContentState` fields; custom layouts are done by editing the SwiftUI view.
- Full native build is only verified inside an Expo app (pods); see the demo in `examples/ExpoDemo`.
