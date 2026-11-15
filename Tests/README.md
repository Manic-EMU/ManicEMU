# Save sync core tests

The `SaveSyncCoreTests` target in the existing Xcode project compiles the same
production shared sources as the app. It has no app host or app dependencies.
Its shared scheme makes the test command work without relying on each user's
automatically generated schemes. Run it on an available iOS simulator:

```sh
xcodebuild -project ManicEmu/ManicEmu.xcodeproj -scheme SaveSyncCoreTests \
  -destination 'platform=iOS Simulator,name=<available simulator>' \
  CODE_SIGNING_ALLOWED=NO test
```

These tests cover the sync core only. They do not launch the app or verify
Realm/CloudKit wiring, two-device delivery, or hardware emulator lifecycle.
