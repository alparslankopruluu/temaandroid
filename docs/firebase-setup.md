# Firebase setup and verification

ScreenMotion uses two Firebase projects. Debug builds target `screenmotion-dev`; release
builds target `screenmotion-prod`. Both projects have Anonymous Authentication and
Google Analytics enabled. Crashlytics receives reports only after an app run and a
crash or recorded nonfatal event.

| Platform | Dev app ID | Prod app ID |
|---|---|---|
| iOS | `1:418739201078:ios:09591541d8c78beacd6497` | `1:477861030089:ios:38f88022a676b2c6604518` |
| Android | `1:418739201078:android:5f4def72852cc67fcd6497` | `1:477861030089:android:e4ea888d193259b4604518` |

Download the four SDK configuration files into their gitignored paths from an
authenticated Firebase CLI session:

```sh
firebase apps:sdkconfig ios 1:418739201078:ios:09591541d8c78beacd6497 -o App/Config/dev/GoogleService-Info.plist
firebase apps:sdkconfig ios 1:477861030089:ios:38f88022a676b2c6604518 -o App/Config/prod/GoogleService-Info.plist
firebase apps:sdkconfig android 1:418739201078:android:5f4def72852cc67fcd6497 -o android/app/src/debug/google-services.json
firebase apps:sdkconfig android 1:477861030089:android:e4ea888d193259b4604518 -o android/app/src/release/google-services.json
```

`project.yml` copies the appropriate iOS plist into the app bundle and uploads
build dSYMs to the matching Crashlytics project. Android's Google Services and Crashlytics Gradle
plugins select the build-type JSON and process release mapping files. The
configuration files contain public SDK keys but stay out of Git.

Verify a new build by confirming an Anonymous entry in the matching Firebase
Authentication user list, an `app_opened` event in Analytics DebugView (use
`-FIRDebugEnabled` for an iOS simulator or `adb shell setprop debug.firebase.analytics.app com.screenmotion.studio`
for Android), and a controlled debug-only nonfatal/crash receipt in Crashlytics.
The iOS debug build emits one sanitized nonfatal if launched with
`SIMCTL_CHILD_SCREENMOTION_VERIFY_CRASHLYTICS=1 xcrun simctl launch <device> com.screenmotion.studio`.
Use a locally signed simulator build for this check; an unsigned build can fail
Firebase Installations keychain access with `SecItemCopyMatching (-34018)`.
Do not use a production crash to validate the integration. Device evidence and
App Store/Play privacy disclosures must be completed before distribution.
