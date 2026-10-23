#!/usr/bin/env python3
"""Update metadata/version/1.0.4 for the Halloween scenes, lifetime plan and open-on-charge guide.

    python3 scripts/m6b-metadata.py

Local preparation only; applying to App Store Connect is a separate approved `asc metadata apply`.
Idempotent: a second run changes nothing.
"""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent / "metadata/version/1.0.4"

# promo (<=170), Halloween bullet, lifetime bullet, charge bullet, lifetime sentence for the Pro paragraph
T = {
"en-US": ("Halloween is here: Haunted Moon, Pumpkin Patch and Ghost Forest. 23 cinematic loops that play when you wake your iPhone.",
  "3 Halloween scenes: Haunted Moon, Pumpkin Patch and Ghost Forest.", "Pro now also comes as a one-time Lifetime purchase.",
  "Set Nightstand to open when you plug in, with a step-by-step Shortcuts guide.", "Or unlock Pro once with a one-time Lifetime purchase."),
"tr": ("Cadılar Bayramı geldi: Perili Ay, Balkabağı Tarlası ve Hayalet Ormanı. iPhone'unu uyandırınca oynayan 23 sinematik döngü.",
  "3 Cadılar Bayramı sahnesi: Perili Ay, Balkabağı Tarlası ve Hayalet Ormanı.", "Pro artık tek seferlik Ömür Boyu satın alma olarak da var.",
  "Adım adım Kestirmeler rehberiyle Komodin modunu şarja takınca açılacak şekilde ayarla.", "Ya da Pro'yu tek seferlik Ömür Boyu satın almayla aç."),
"de-DE": ("Halloween ist da: Spukmond, Kürbisfeld und Geisterwald. 23 Kino-Loops, die beim Aufwecken deines iPhone spielen.",
  "3 Halloween-Szenen: Spukmond, Kürbisfeld und Geisterwald.", "Pro gibt es jetzt auch als einmaligen Lebenslang-Kauf.",
  "Lass Nightstand beim Anstecken öffnen – mit Schritt-für-Schritt-Anleitung für Kurzbefehle.", "Oder schalte Pro einmalig mit dem Lebenslang-Kauf frei."),
"es-ES": ("Llega Halloween: Luna embrujada, Huerto de calabazas y Bosque de fantasmas. 23 bucles cinematográficos que se activan al encender tu iPhone.",
  "3 escenas de Halloween: Luna embrujada, Huerto de calabazas y Bosque de fantasmas.", "Pro ahora también está disponible como compra única De por vida.",
  "Haz que Nightstand se abra al cargar, con una guía paso a paso de Atajos.", "O desbloquea Pro una sola vez con la compra única De por vida."),
"fr-FR": ("Halloween est là : Lune hantée, Champ de citrouilles et Forêt des fantômes. 23 boucles cinématiques qui s’animent au réveil de ton iPhone.",
  "3 scènes d’Halloween : Lune hantée, Champ de citrouilles et Forêt des fantômes.", "Pro existe aussi en achat unique À vie.",
  "Fais s’ouvrir Nightstand à la recharge grâce à un guide Raccourcis pas à pas.", "Ou débloque Pro une fois pour toutes avec l’achat unique À vie."),
"it": ("È arrivato Halloween: Luna stregata, Campo di zucche e Foresta dei fantasmi. 23 loop cinematografici che partono quando risvegli l’iPhone.",
  "3 scene di Halloween: Luna stregata, Campo di zucche e Foresta dei fantasmi.", "Pro ora è disponibile anche come acquisto una tantum A vita.",
  "Fai aprire Nightstand quando colleghi il caricatore, con una guida passo passo per Comandi Rapidi.", "Oppure sblocca Pro una volta per tutte con l’acquisto A vita."),
"pt-BR": ("Chegou o Halloween: Lua assombrada, Campo de abóboras e Floresta fantasma. 23 loops cinematográficos que tocam quando você desperta o iPhone.",
  "3 cenas de Halloween: Lua assombrada, Campo de abóboras e Floresta fantasma.", "O Pro agora também vem como compra única Vitalícia.",
  "Faça o Nightstand abrir ao carregar, com um guia passo a passo de Atalhos.", "Ou desbloqueie o Pro de uma vez com a compra única Vitalícia."),
"nl-NL": ("Halloween is er: Spookmaan, Pompoenveld en Spokenbos. 23 filmische loops die spelen als je je iPhone wekt.",
  "3 Halloween-scènes: Spookmaan, Pompoenveld en Spokenbos.", "Pro is nu ook verkrijgbaar als eenmalige Levenslang-aankoop.",
  "Laat Nightstand openen bij het opladen, met een stapsgewijze Opdrachten-gids.", "Of ontgrendel Pro in één keer met de eenmalige Levenslang-aankoop."),
"sv": ("Halloween är här: Spökmåne, Pumpafältet och Spökskogen. 23 filmiska loopar som spelas när du väcker din iPhone.",
  "3 halloweenscener: Spökmåne, Pumpafältet och Spökskogen.", "Pro finns nu även som engångsköp för livstid.",
  "Låt Nightstand öppnas när du kopplar in laddaren, med en steg-för-steg-guide för Genvägar.", "Eller lås upp Pro en gång med ett engångsköp för livstid."),
"da": ("Halloween er her: Hjemsøgt måne, Græskarmarken og Spøgelsesskoven. 23 filmiske loops, der afspilles, når du vækker din iPhone.",
  "3 halloweenscener: Hjemsøgt måne, Græskarmarken og Spøgelsesskoven.", "Pro fås nu også som et engangskøb for livstid.",
  "Få Nightstand til at åbne ved opladning med en trin-for-trin-guide til Genveje.", "Eller lås Pro op én gang med et engangskøb for livstid."),
"no": ("Halloween er her: Hjemsøkt måne, Gresskaråkeren og Spøkelsesskogen. 23 filmatiske looper som spilles når du vekker iPhonen.",
  "3 halloweenscener: Hjemsøkt måne, Gresskaråkeren og Spøkelsesskogen.", "Pro finnes nå også som et engangskjøp for livstid.",
  "Få Nightstand til å åpnes ved lading, med en trinnvis guide for Snarveier.", "Eller lås opp Pro én gang med et engangskjøp for livstid."),
"pl": ("Nadeszło Halloween: Nawiedzony księżyc, Dyniowe pole i Las duchów. 23 filmowe pętle, które ruszają po wybudzeniu iPhone’a.",
  "3 sceny na Halloween: Nawiedzony księżyc, Dyniowe pole i Las duchów.", "Pro jest teraz dostępne także jako jednorazowy zakup Dożywotnio.",
  "Ustaw, by Nightstand otwierał się podczas ładowania – z przewodnikiem krok po kroku po Skrótach.", "Możesz też odblokować Pro jednorazowym zakupem Dożywotnio."),
"ru": ("Хэллоуин уже здесь: Призрачная луна, Тыквенное поле и Лес призраков. 23 кинематографичные петли, которые оживают при пробуждении iPhone.",
  "3 сцены к Хэллоуину: Призрачная луна, Тыквенное поле и Лес призраков.", "Pro теперь можно купить навсегда одним платежом.",
  "Nightstand может открываться при зарядке — с пошаговой инструкцией для «Команд».", "Или откройте Pro навсегда одной покупкой."),
"ja": ("ハロウィンがやってきた：幽霊の月、かぼちゃ畑、おばけの森。iPhoneを起こすと動き出す23本のシネマティックループ。",
  "ハロウィンの3シーン：幽霊の月、かぼちゃ畑、おばけの森。", "Proに買い切りプランが加わりました。",
  "ショートカットの手順ガイドで、充電時にNightstandを自動で開けます。", "または買い切りでProをずっと使えます。"),
"ko": ("할로윈이 왔어요: 유령의 달, 호박밭, 유령의 숲. iPhone을 깨우면 재생되는 시네마틱 루프 23개.",
  "할로윈 장면 3개: 유령의 달, 호박밭, 유령의 숲.", "이제 Pro를 평생 1회 구매로도 이용할 수 있습니다.",
  "단축어 단계별 가이드로 충전할 때 Nightstand가 열리도록 설정하세요.", "또는 평생 1회 구매로 Pro를 잠금 해제하세요."),
"zh-Hans": ("万圣节来了：鬼月夜、南瓜田和幽灵森林。23 段电影级循环，唤醒 iPhone 即刻播放。",
  "3 个万圣节场景：鬼月夜、南瓜田和幽灵森林。", "Pro 现提供一次性终身购买。",
  "借助快捷指令分步指南，让 Nightstand 在充电时自动打开。", "也可以通过一次性终身购买解锁 Pro。"),
"zh-Hant": ("萬聖節來了：鬼月夜、南瓜田和幽靈森林。23 段電影級循環，喚醒 iPhone 即刻播放。",
  "3 個萬聖節場景：鬼月夜、南瓜田和幽靈森林。", "Pro 現提供一次性終身購買。",
  "透過捷徑逐步指南，讓 Nightstand 在充電時自動開啟。", "也可以透過一次性終身購買解鎖 Pro。"),
"ar-SA": ("الهالوين هنا: القمر المسكون وحقل اليقطين وغابة الأشباح. 23 حلقة سينمائية تتحرك عند إيقاظ iPhone.",
  "3 مشاهد للهالوين: القمر المسكون وحقل اليقطين وغابة الأشباح.", "أصبح Pro متاحًا أيضًا بشراء لمرة واحدة مدى الحياة.",
  "اجعل Nightstand يفتح عند توصيل الشاحن مع دليل خطوة بخطوة للاختصارات.", "أو افتح Pro مرة واحدة بشراء مدى الحياة."),
"hi": ("हैलोवीन आ गया: भुतहा चाँद, कद्दू का खेत और भूतों का जंगल। 23 सिनेमैटिक लूप जो iPhone जगाते ही चलते हैं।",
  "3 हैलोवीन सीन: भुतहा चाँद, कद्दू का खेत और भूतों का जंगल।", "Pro अब एक बार की लाइफ़टाइम खरीद के रूप में भी उपलब्ध है।",
  "शॉर्टकट की चरण-दर-चरण गाइड से चार्ज लगाते ही Nightstand खुलने के लिए सेट करें।", "या एक बार की लाइफ़टाइम खरीद से Pro अनलॉक करें।"),
"id": ("Halloween telah tiba: Bulan Berhantu, Ladang Labu, dan Hutan Hantu. 23 loop sinematik yang diputar saat iPhone Anda dibangunkan.",
  "3 adegan Halloween: Bulan Berhantu, Ladang Labu, dan Hutan Hantu.", "Pro kini juga tersedia sebagai pembelian Seumur Hidup sekali bayar.",
  "Atur Nightstand agar terbuka saat mengisi daya, lengkap dengan panduan Pintasan langkah demi langkah.", "Atau buka Pro sekali bayar dengan pembelian Seumur Hidup."),
"th": ("ฮาโลวีนมาแล้ว: จันทร์ผีสิง ไร่ฟักทอง และป่าผี ลูปภาพยนตร์ 23 รายการที่เล่นเมื่อปลุก iPhone",
  "3 ฉากฮาโลวีน: จันทร์ผีสิง ไร่ฟักทอง และป่าผี", "ตอนนี้ Pro มีแบบซื้อครั้งเดียวตลอดชีพแล้ว",
  "ตั้งให้ Nightstand เปิดเมื่อเสียบชาร์จ พร้อมคู่มือคำสั่งลัดทีละขั้น", "หรือปลดล็อก Pro ด้วยการซื้อครั้งเดียวตลอดชีพ"),
"vi": ("Halloween đã đến: Trăng ma ám, Cánh đồng bí ngô và Rừng ma. 23 vòng lặp điện ảnh phát khi bạn đánh thức iPhone.",
  "3 cảnh Halloween: Trăng ma ám, Cánh đồng bí ngô và Rừng ma.", "Pro giờ có thêm gói mua một lần Trọn đời.",
  "Đặt Nightstand tự mở khi cắm sạc, kèm hướng dẫn Phím tắt từng bước.", "Hoặc mở khóa Pro một lần với gói mua Trọn đời."),
}

files = {p.stem: p for p in root.glob("*.json")}
assert set(files) == set(T), set(files) ^ set(T)
for locale, (promo, halloween, lifetime, charge, sentence) in T.items():
    assert len(promo) <= 170, (locale, len(promo))
    path = files[locale]
    data = json.loads(path.read_text())
    if halloween in data["whatsNew"]:
        continue
    for key in ("description", "whatsNew"):
        data[key] = re.sub(r"(?<!\d)33(?!\d)", "36", data[key])
        data[key] = re.sub(r"(?<!\d)20(?!\d)", "23", data[key])
    lines = data["whatsNew"].split("\n")
    # New items lead; the closing "fixes" line stays last.
    lines = [f"• {halloween}"] + lines[:-1] + [f"• {lifetime}", f"• {charge}"] + lines[-1:]
    data["whatsNew"] = "\n".join(lines)
    data["promotionalText"] = promo
    legal = data["description"].index("https://screenmotion-legal")
    cut = data["description"].rindex("\n\n", 0, legal)
    data["description"] = data["description"][:cut] + " " + sentence + data["description"][cut:]
    assert len(data["description"]) <= 4000 and len(data["whatsNew"]) <= 4000, locale
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
print("updated", len(T))
