# Huawei delivery lane

The Android package runs on Huawei devices that support Android APKs. Its live wallpaper,
MediaStore exports, widgets and icon ZIPs use platform APIs and do not require HMS.

For supported EMUI devices, Huawei Theme Studio can turn the owned artwork and generated
icon packs into a `.hwt` theme with dynamic lock screen, home wallpaper and icons. Use only
files generated from `App/Resources/Assets.xcassets` and the in-app 24-icon exporter. Keep
the four collections separate and preserve the 22 theme identifiers from `catalog.json`.

Validation still requires Theme Studio plus a compatible physical Huawei device. Launcher
touch delivery, lock-screen animation, theme signing and AppGallery packaging vary by EMUI
release. HarmonyOS 5+ native delivery needs a separate ArkTS/HAP project; this Android
package is not evidence of native HarmonyOS support.
