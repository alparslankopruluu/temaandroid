#!/usr/bin/env python3
"""Generate Android resources from ScreenMotion's canonical owned iOS content."""

from __future__ import annotations

import json
import re
import shutil
from pathlib import Path
from xml.sax.saxutils import escape

ANDROID = Path(__file__).resolve().parents[1]
ROOT = ANDROID.parent
IOS = ROOT / "App" / "Resources"
RES = ANDROID / "app" / "src" / "main" / "res"

LOCALE_DIRS = {
    "en": "values", "tr": "values-tr", "ar": "values-ar", "ja": "values-ja",
    "zh-Hans": "values-zh-rCN", "ru": "values-ru", "es": "values-es",
    "pt-BR": "values-pt-rBR", "de": "values-de", "fr": "values-fr",
    "it": "values-it", "ko": "values-ko", "zh-Hant": "values-zh-rTW",
    "id": "values-in", "vi": "values-vi", "th": "values-th", "hi": "values-hi",
    "nl": "values-nl", "pl": "values-pl", "sv": "values-sv", "da": "values-da",
    "nb": "values-nb",
}


def resource_name(key: str) -> str:
    value = re.sub(r"[^a-zA-Z0-9_]", "_", key).lower()
    return f"k_{value}" if value[:1].isdigit() else value


def android_string(value: str) -> str:
    return escape(value).replace("'", "\\'").replace('"', '\\"').replace("%", "%%")


def generate_strings() -> None:
    strings = json.loads((IOS / "Localizable.xcstrings").read_text())["strings"]
    additions = {
        "en": (
            "Apply live wallpaper",
            "Save wallpaper",
            "Save 3-second video",
            "Movement and touch continue on supported Android launchers.",
            "Huawei theme installation depends on this device's EMUI or HarmonyOS capabilities.",
            "Google Play products are not configured in this local build.",
            "Development preview: Pro unlock is local and no real payment is taken.",
        ),
        "tr": (
            "Canlı duvar kağıdını uygula",
            "Duvar kağıdını kaydet",
            "3 saniyelik videoyu kaydet",
            "Desteklenen Android başlatıcılarda hareket ve dokunma devam eder.",
            "Huawei tema kurulumu cihazın EMUI veya HarmonyOS özelliklerine bağlıdır.",
            "Bu yerel derlemede Google Play ürünleri yapılandırılmadı.",
            "Geliştirme önizlemesi: Pro kilidi yerel açılır ve gerçek ödeme alınmaz.",
        ),
    }
    guides = {
        "en": (
            "Choose a scene and tap Apply live wallpaper.",
            "Review the motion in Android's preview, then tap Set wallpaper.",
            "Choose Home screen or Home and lock screen if your device offers it.",
            "Export the 24-icon ZIP and extract it in your files app.",
            "Open your launcher or theme app's icon customization settings.",
            "Choose each PNG. Stock launchers may require shortcuts or a compatible icon-pack launcher.",
            "Choose a widget background in ScreenMotion.",
            "Touch and hold an empty Home screen area, then tap Widgets.",
            "Find ScreenMotion and add Photo, Date, Calendar or Collection; resize as needed.",
        ),
        "tr": (
            "Bir sahne seçip Canlı duvar kâğıdını uygula'ya dokun.",
            "Android önizlemesinde hareketi kontrol edip Duvar kâğıdı olarak ayarla'ya dokun.",
            "Cihazın sunuyorsa Ana ekranı veya Ana ve kilit ekranını seç.",
            "24 simgeli ZIP paketini dışa aktar ve dosya uygulamanda çıkar.",
            "Başlatıcının veya tema uygulamanın simge özelleştirme ayarlarını aç.",
            "Her PNG'yi seç. Standart başlatıcılar kısayol veya uyumlu bir simge paketi başlatıcısı gerektirebilir.",
            "ScreenMotion'da bir widget arka planı seç.",
            "Ana ekranda boş bir alana basılı tutup Widget'lar'a dokun.",
            "ScreenMotion'ı bul; Fotoğraf, Tarih, Takvim veya Koleksiyon'u ekleyip boyutlandır.",
        ),
    }
    for locale, folder in LOCALE_DIRS.items():
        platform = additions.get(locale, additions["en"])
        entries = [
            '    <string name="app_name">ScreenMotion</string>',
            '    <string name="wallpaper_description">ScreenMotion interactive live wallpaper</string>',
            f'    <string name="action_apply_live_wallpaper">{android_string(platform[0])}</string>',
            f'    <string name="action_export_still">{android_string(platform[1])}</string>',
            f'    <string name="action_export_video">{android_string(platform[2])}</string>',
            f'    <string name="android_live_wallpaper_note">{android_string(platform[3])}</string>',
            f'    <string name="huawei_theme_note">{android_string(platform[4])}</string>',
            f'    <string name="android_purchase_unavailable">{android_string(platform[5])}</string>',
            f'    <string name="android_debug_purchase_note">{android_string(platform[6])}</string>',
            '    <string name="android_pro_badge">PRO</string>',
        ]
        guide = guides.get(locale, guides["en"])
        names = (
            "android_install_wallpaper_1", "android_install_wallpaper_2", "android_install_wallpaper_3",
            "android_install_icons_1", "android_install_icons_2", "android_install_icons_3",
            "android_install_widgets_1", "android_install_widgets_2", "android_install_widgets_3",
        )
        entries.extend(
            f'    <string name="{name}">{android_string(value)}</string>'
            for name, value in zip(names, guide)
        )
        for key in sorted(strings):
            unit = strings[key].get("localizations", {}).get(locale, {}).get("stringUnit")
            if not unit:
                raise SystemExit(f"Missing {locale}: {key}")
            entries.append(
                f'    <string name="{resource_name(key)}" formatted="false">{android_string(unit["value"])}</string>'
            )
        directory = RES / folder
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "strings.xml").write_text(
            "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>\n"
            + "\n".join(entries)
            + "\n</resources>\n"
        )


def copy_catalog_and_art() -> None:
    raw = RES / "raw"
    raw.mkdir(parents=True, exist_ok=True)
    shutil.copy2(IOS / "catalog.json", raw / "catalog.json")
    shutil.copy2(IOS / "remote-content.json", raw / "remote_content.json")
    drawable = RES / "drawable-nodpi"
    drawable.mkdir(parents=True, exist_ok=True)
    for artwork in sorted((IOS / "Assets.xcassets").glob("*.imageset/art.png")):
        name = resource_name(artwork.parent.name.removesuffix(".imageset"))
        shutil.copy2(artwork, drawable / f"{name}.png")


if __name__ == "__main__":
    generate_strings()
    copy_catalog_and_art()
    print(f"Synced {len(LOCALE_DIRS)} locales and {len(list((RES / 'drawable-nodpi').glob('*.png')))} artwork files")
