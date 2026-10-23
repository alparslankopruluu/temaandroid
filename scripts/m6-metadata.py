#!/usr/bin/env python3
"""Prepare App Store metadata for iOS 1.0.4 (M6) from the pulled 1.0.3 metadata.

    python3 scripts/m6-metadata.py <pulled-metadata-dir>

Local preparation only: it writes metadata/version/1.0.4 and metadata/app-info. Applying to
App Store Connect is a separate, approved `asc metadata plan/apply` step.
"""
import json
import shutil
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
source = Path(sys.argv[1])

# Each pair must match the live 1.0.3 text exactly; a miss stops the script instead of shipping a stale claim.
FIXES = {
 "en-US": [("Turn your own video into a Live Photo wallpaper, free.", "Turn your own video into a Live Photo wallpaper."),
           ("No subscription needed.", "Your first 2 videos are free."),
           ("• 29 moving scenes", "• 33 moving scenes"),
           ("Five starter scenes and your own clips are free. Pro unlocks every scene, all icon packs, and scene exports.",
            "Five starter scenes and your first 2 videos are free. Pro unlocks every scene, unlimited videos, all icon packs, and scene exports.")],
 "tr": [("Kendi videonu ücretsiz olarak Live Photo duvar kâğıdına dönüştür.", "Kendi videonu Live Photo duvar kâğıdına dönüştür."),
        ("Abonelik gerekmez.", "İlk 2 videon ücretsiz."),
        ("• 29 hareketli sahne", "• 33 hareketli sahne"),
        ("Beş başlangıç sahnesi ve kendi kliplerin ücretsizdir. Pro tüm sahnelerin, tüm simge paketlerinin ve sahne dışa aktarımlarının kilidini açar.",
         "Beş başlangıç sahnesi ve ilk 2 videon ücretsizdir. Pro tüm sahnelerin, sınırsız videonun, tüm simge paketlerinin ve sahne dışa aktarımlarının kilidini açar.")],
 "de-DE": [("Verwandle dein eigenes Video kostenlos in ein Live Photo-Hintergrundbild.", "Verwandle dein eigenes Video in ein Live Photo-Hintergrundbild."),
           ("Kein Abo nötig.", "Deine ersten 2 Videos sind kostenlos."),
           ("• 29 bewegte Szenen", "• 33 bewegte Szenen"),
           ("Fünf Startszenen und deine eigenen Clips sind kostenlos. Pro schaltet alle Szenen, alle Symbolpakete und Szenenexporte frei.",
            "Fünf Startszenen und deine ersten 2 Videos sind kostenlos. Pro schaltet alle Szenen, unbegrenzt Videos, alle Symbolpakete und Szenenexporte frei.")],
 "es-ES": [("Convierte tu propio vídeo en un fondo de pantalla Live Photo, gratis.", "Convierte tu propio vídeo en un fondo de pantalla Live Photo."),
           ("No necesitas suscripción.", "Tus 2 primeros vídeos son gratis."),
           ("• 29 escenas en movimiento", "• 33 escenas en movimiento"),
           ("Cinco escenas iniciales y tus propios clips son gratis. Pro desbloquea todas las escenas, todos los packs de iconos y la exportación de escenas.",
            "Cinco escenas iniciales y tus 2 primeros vídeos son gratis. Pro desbloquea todas las escenas, vídeos ilimitados, todos los packs de iconos y la exportación de escenas.")],
 "fr-FR": [("Transforme ta propre vidéo en fond d’écran Live Photo, gratuitement.", "Transforme ta propre vidéo en fond d’écran Live Photo."),
           ("Aucun abonnement nécessaire.", "Tes 2 premières vidéos sont gratuites."),
           ("• 29 scènes animées", "• 33 scènes animées"),
           ("Cinq scènes de départ et tes propres clips sont gratuits. Pro débloque toutes les scènes, tous les packs d’icônes et les exports de scènes.",
            "Cinq scènes de départ et tes 2 premières vidéos sont gratuites. Pro débloque toutes les scènes, les vidéos illimitées, tous les packs d’icônes et les exports de scènes.")],
 "it": [("Trasforma il tuo video in uno sfondo Live Photo, gratis.", "Trasforma il tuo video in uno sfondo Live Photo."),
        ("Nessun abbonamento richiesto.", "I primi 2 video sono gratis."),
        ("• 29 scene in movimento", "• 33 scene in movimento"),
        ("Cinque scene iniziali e le tue clip sono gratuite. Pro sblocca tutte le scene, tutti i pacchetti di icone e l’esportazione delle scene.",
         "Cinque scene iniziali e i primi 2 video sono gratuiti. Pro sblocca tutte le scene, video illimitati, tutti i pacchetti di icone e l’esportazione delle scene.")],
 "pt-BR": [("Transforme o seu próprio vídeo em um papel de parede Live Photo, grátis.", "Transforme o seu próprio vídeo em um papel de parede Live Photo."),
           ("Não precisa de assinatura.", "Os 2 primeiros vídeos são grátis."),
           ("• 29 cenas em movimento", "• 33 cenas em movimento"),
           ("Cinco cenas iniciais e os seus próprios clipes são grátis. O Pro desbloqueia todas as cenas, todos os pacotes de ícones e a exportação de cenas.",
            "Cinco cenas iniciais e os 2 primeiros vídeos são grátis. O Pro desbloqueia todas as cenas, vídeos ilimitados, todos os pacotes de ícones e a exportação de cenas.")],
 "nl-NL": [("Maak van je eigen video een Live Photo-achtergrond, gratis.", "Maak van je eigen video een Live Photo-achtergrond."),
           ("Geen abonnement nodig.", "Je eerste 2 video’s zijn gratis."),
           ("• 29 bewegende scènes", "• 33 bewegende scènes"),
           ("Vijf startscènes en je eigen clips zijn gratis. Pro ontgrendelt alle scènes, alle symboolpakketten en het exporteren van scènes.",
            "Vijf startscènes en je eerste 2 video’s zijn gratis. Pro ontgrendelt alle scènes, onbeperkt video’s, alle symboolpakketten en het exporteren van scènes.")],
 "sv": [("Gör din egen video till en Live Photo-bakgrund, gratis.", "Gör din egen video till en Live Photo-bakgrund."),
        ("Ingen prenumeration behövs.", "Dina 2 första videor är gratis."),
        ("• 29 rörliga scener", "• 33 rörliga scener"),
        ("Fem startscener och dina egna klipp är gratis. Pro låser upp alla scener, alla symbolpaket och export av scener.",
         "Fem startscener och dina 2 första videor är gratis. Pro låser upp alla scener, obegränsat med videor, alla symbolpaket och export av scener.")],
 "da": [("Gør din egen video til en Live Photo-baggrund, gratis.", "Gør din egen video til en Live Photo-baggrund."),
        ("Intet abonnement påkrævet.", "Dine første 2 videoer er gratis."),
        ("• 29 levende scener", "• 33 levende scener"),
        ("Fem startscener og dine egne klip er gratis. Pro låser op for alle scener, alle symbolpakker og eksport af scener.",
         "Fem startscener og dine første 2 videoer er gratis. Pro låser op for alle scener, ubegrænsede videoer, alle symbolpakker og eksport af scener.")],
 "no": [("Gjør din egen video om til en Live Photo-bakgrunn, gratis.", "Gjør din egen video om til en Live Photo-bakgrunn."),
        ("Ingen abonnement nødvendig.", "De to første videoene er gratis."),
        ("• 29 levende scener", "• 33 levende scener"),
        ("Fem startscener og dine egne klipp er gratis. Pro låser opp alle scener, alle symbolpakker og eksport av scener.",
         "Fem startscener og de to første videoene er gratis. Pro låser opp alle scener, ubegrensede videoer, alle symbolpakker og eksport av scener.")],
 "pl": [("Zamień własne wideo w tapetę Live Photo za darmo.", "Zamień własne wideo w tapetę Live Photo."),
        ("Subskrypcja nie jest potrzebna.", "Pierwsze 2 filmy są bezpłatne."),
        ("• 29 ruchomych scen", "• 33 ruchome sceny"),
        ("Pięć scen startowych i Twoje własne klipy są bezpłatne. Pro odblokowuje wszystkie sceny, wszystkie pakiety ikon i eksport scen.",
         "Pięć scen startowych i pierwsze 2 filmy są bezpłatne. Pro odblokowuje wszystkie sceny, nielimitowane filmy, wszystkie pakiety ikon i eksport scen.")],
 "ru": [("Преврати своё видео в обои Live Photo — бесплатно.", "Преврати своё видео в обои Live Photo."),
        ("Подписка не нужна.", "Первые 2 видео — бесплатно."),
        ("• 29 движущихся сцен", "• 33 движущиеся сцены"),
        ("Пять стартовых сцен и твои собственные клипы бесплатны. Pro открывает все сцены, все наборы значков и экспорт сцен.",
         "Пять стартовых сцен и первые 2 видео бесплатны. Pro открывает все сцены, безлимитные видео, все наборы значков и экспорт сцен.")],
 "ja": [("自分の動画を無料でLive Photo壁紙に。", "自分の動画をLive Photo壁紙に。"),
        ("サブスクリプションは不要です。", "最初の2本は無料です。"),
        ("• 29の動くシーン", "• 33の動くシーン"),
        ("5つのスターターシーンと自分のクリップは無料です。Proではすべてのシーン、すべてのアイコンパック、シーンの書き出しが利用できます。",
         "5つのスターターシーンと最初の2本の動画は無料です。Proではすべてのシーン、無制限の動画、すべてのアイコンパック、シーンの書き出しが利用できます。")],
 "ko": [("내 동영상을 무료로 Live Photo 배경화면으로 만드세요.", "내 동영상을 Live Photo 배경화면으로 만드세요."),
        ("구독이 필요 없습니다.", "처음 2개는 무료입니다."),
        ("• 움직이는 장면 29개", "• 움직이는 장면 33개"),
        ("스타터 장면 5개와 내 클립은 무료입니다. Pro는 모든 장면, 모든 아이콘 팩, 장면 내보내기를 잠금 해제합니다.",
         "스타터 장면 5개와 처음 2개의 동영상은 무료입니다. Pro는 모든 장면, 무제한 동영상, 모든 아이콘 팩, 장면 내보내기를 잠금 해제합니다.")],
 "zh-Hans": [("免费把你自己的视频变成实况照片墙纸。", "把你自己的视频变成实况照片墙纸。"),
             ("无需订阅。", "前 2 段视频免费。"),
             ("• 29 个动态场景", "• 33 个动态场景"),
             ("五个入门场景和你自己的片段均可免费使用。Pro 解锁全部场景、全部图标包和场景导出。",
              "五个入门场景和前 2 段视频均可免费使用。Pro 解锁全部场景、无限视频、全部图标包和场景导出。")],
 "zh-Hant": [("免費把你自己的影片變成原況照片桌布。", "把你自己的影片變成原況照片桌布。"),
             ("不需要訂閱。", "前 2 段影片免費。"),
             ("• 29 個動態場景", "• 33 個動態場景"),
             ("五個入門場景和你自己的影片皆可免費使用。Pro 可解鎖全部場景、全部圖示包和場景輸出。",
              "五個入門場景和前 2 段影片皆可免費使用。Pro 可解鎖全部場景、無限影片、全部圖示包和場景輸出。")],
 "ar-SA": [("حوّل الفيديو الخاص بك إلى خلفية Live Photo مجانًا.", "حوّل الفيديو الخاص بك إلى خلفية Live Photo."),
           ("لا حاجة إلى اشتراك.", "أول مقطعين مجانيان."),
           ("• 29 مشهدًا متحركًا", "• 33 مشهدًا متحركًا"),
           ("خمسة مشاهد للبداية ومقاطعك الخاصة مجانية. يفتح Pro جميع المشاهد وجميع حزم الأيقونات وتصدير المشاهد.",
            "خمسة مشاهد للبداية وأول مقطعين مجانية. يفتح Pro جميع المشاهد ومقاطع غير محدودة وجميع حزم الأيقونات وتصدير المشاهد.")],
 "hi": [("अपने वीडियो को मुफ़्त में Live Photo वॉलपेपर में बदलें।", "अपने वीडियो को Live Photo वॉलपेपर में बदलें।"),
        ("किसी सब्सक्रिप्शन की ज़रूरत नहीं।", "पहले 2 वीडियो मुफ़्त हैं।"),
        ("• 29 चलते सीन", "• 33 चलते सीन"),
        ("पाँच शुरुआती सीन और आपकी अपनी क्लिप मुफ़्त हैं। Pro सभी सीन, सभी आइकन पैक और सीन एक्सपोर्ट अनलॉक करता है।",
         "पाँच शुरुआती सीन और पहले 2 वीडियो मुफ़्त हैं। Pro सभी सीन, असीमित वीडियो, सभी आइकन पैक और सीन एक्सपोर्ट अनलॉक करता है।")],
 "id": [("Ubah video Anda sendiri menjadi wallpaper Live Photo, gratis.", "Ubah video Anda sendiri menjadi wallpaper Live Photo."),
        ("Tidak perlu langganan.", "2 video pertama gratis."),
        ("• 29 adegan bergerak", "• 33 adegan bergerak"),
        ("Lima adegan awal dan klip Anda sendiri gratis. Pro membuka semua adegan, semua paket ikon, dan ekspor adegan.",
         "Lima adegan awal dan 2 video pertama gratis. Pro membuka semua adegan, video tanpa batas, semua paket ikon, dan ekspor adegan.")],
 "th": [("เปลี่ยนวิดีโอของคุณเองเป็นวอลเปเปอร์ Live Photo ได้ฟรี", "เปลี่ยนวิดีโอของคุณเองเป็นวอลเปเปอร์ Live Photo"),
        ("ไม่ต้องสมัครสมาชิก", "2 วิดีโอแรกฟรี"),
        ("• 29 ฉากเคลื่อนไหว", "• 33 ฉากเคลื่อนไหว"),
        ("ฉากเริ่มต้นห้าฉากและคลิปของคุณเองใช้ได้ฟรี Pro จะปลดล็อคทุกฉาก ชุดไอคอนทั้งหมด และการส่งออกฉาก",
         "ฉากเริ่มต้นห้าฉากและ 2 วิดีโอแรกใช้ได้ฟรี Pro จะปลดล็อคทุกฉาก วิดีโอไม่จำกัด ชุดไอคอนทั้งหมด และการส่งออกฉาก")],
 "vi": [("Biến video của chính bạn thành hình nền Live Photo, miễn phí.", "Biến video của chính bạn thành hình nền Live Photo."),
        ("Không cần đăng ký.", "2 video đầu tiên miễn phí."),
        ("• 29 cảnh chuyển động", "• 33 cảnh chuyển động"),
        ("Năm cảnh khởi đầu và clip của chính bạn đều miễn phí. Pro mở khóa mọi cảnh, tất cả gói biểu tượng và tính năng xuất cảnh.",
         "Năm cảnh khởi đầu và 2 video đầu tiên đều miễn phí. Pro mở khóa mọi cảnh, video không giới hạn, tất cả gói biểu tượng và tính năng xuất cảnh.")],
}

NEWS = {
 "en-US": ("• 4 new code-crafted scenes: Northern Lights, Neon Rain, Bioluminescence and Event Horizon.\n• 20 cinematic loops that play in the app and in your Live Photos.\n• Nightstand mode now lets you pick any scene while you charge.\n• A clearer Pro page with a free trial on the yearly plan.\n• Fixes and polish.",
           "New: Northern Lights, Neon Rain, Bioluminescence and Event Horizon. 20 cinematic loops that play when you wake your iPhone."),
 "tr": ("• Kodla tasarlanmış 4 yeni sahne: Kuzey Işıkları, Neon Yağmur, Biyolüminesans ve Olay Ufku.\n• Uygulamada ve Live Photo'larında oynayan 20 sinematik döngü.\n• Komodin modunda şarj olurken istediğin sahneyi seç.\n• Yıllık planda ücretsiz denemeyle daha net bir Pro sayfası.\n• Düzeltmeler ve iyileştirmeler.",
        "Yeni: Kuzey Işıkları, Neon Yağmur, Biyolüminesans ve Olay Ufku. iPhone'unu uyandırınca oynayan 20 sinematik döngü."),
 "de-DE": ("• 4 neue, programmierte Szenen: Nordlichter, Neonregen, Biolumineszenz und Ereignishorizont.\n• 20 Kino-Loops in der App und in deinen Live Photos.\n• Im Nachttischmodus wählst du beim Laden jede Szene.\n• Eine klarere Pro-Seite mit Gratis-Testphase im Jahresabo.\n• Fehlerbehebungen und Feinschliff.",
           "Neu: Nordlichter, Neonregen, Biolumineszenz und Ereignishorizont. 20 Kino-Loops, die beim Aufwecken deines iPhone spielen."),
 "es-ES": ("• 4 escenas nuevas creadas con código: Auroras boreales, Lluvia de neón, Bioluminiscencia y Horizonte de sucesos.\n• 20 bucles cinematográficos en la app y en tus Live Photos.\n• En el modo mesita de noche eliges cualquier escena mientras cargas.\n• Una página Pro más clara con prueba gratis en el plan anual.\n• Correcciones y mejoras.",
           "Nuevo: Auroras boreales, Lluvia de neón, Bioluminiscencia y Horizonte de sucesos. 20 bucles que se reproducen al activar tu iPhone."),
 "fr-FR": ("• 4 nouvelles scènes créées en code : Aurores boréales, Pluie néon, Bioluminescence et Horizon des événements.\n• 20 boucles cinématiques dans l’app et dans tes Live Photos.\n• Le mode table de chevet te laisse choisir n’importe quelle scène pendant la charge.\n• Une page Pro plus claire avec essai gratuit sur l’abonnement annuel.\n• Corrections et finitions.",
           "Nouveau : Aurores boréales, Pluie néon, Bioluminescence et Horizon des événements. 20 boucles qui s’animent au réveil de l’iPhone."),
 "it": ("• 4 nuove scene create con il codice: Aurora boreale, Pioggia al neon, Bioluminescenza e Orizzonte degli eventi.\n• 20 loop cinematografici nell’app e nelle tue Live Photo.\n• In modalità comodino scegli qualsiasi scena mentre ricarichi.\n• Una pagina Pro più chiara con prova gratuita sul piano annuale.\n• Correzioni e miglioramenti.",
        "Novità: Aurora boreale, Pioggia al neon, Bioluminescenza e Orizzonte degli eventi. 20 loop che partono quando riattivi l’iPhone."),
 "pt-BR": ("• 4 novas cenas criadas com código: Aurora boreal, Chuva neon, Bioluminescência e Horizonte de eventos.\n• 20 loops cinematográficos no app e nas suas Live Photos.\n• No modo mesa de cabeceira, escolha qualquer cena enquanto carrega.\n• Uma página Pro mais clara com teste grátis no plano anual.\n• Correções e melhorias.",
           "Novo: Aurora boreal, Chuva neon, Bioluminescência e Horizonte de eventos. 20 loops que tocam quando você desperta o iPhone."),
 "nl-NL": ("• 4 nieuwe scènes uit code: Noorderlicht, Neonregen, Bioluminescentie en Waarnemingshorizon.\n• 20 filmische loops in de app en in je Live Photos.\n• In de nachtkastjesmodus kies je elke scène tijdens het opladen.\n• Een duidelijkere Pro-pagina met gratis proefperiode op het jaarabonnement.\n• Verbeteringen en oplossingen.",
           "Nieuw: Noorderlicht, Neonregen, Bioluminescentie en Waarnemingshorizon. 20 loops die spelen als je je iPhone wekt."),
 "sv": ("• 4 nya kodskapade scener: Norrsken, Neonregn, Bioluminiscens och Händelsehorisont.\n• 20 filmiska loopar i appen och i dina Live Photos.\n• I nattduksläget väljer du valfri scen medan du laddar.\n• En tydligare Pro-sida med gratis provperiod på årsplanen.\n• Rättningar och förbättringar.",
        "Nytt: Norrsken, Neonregn, Bioluminiscens och Händelsehorisont. 20 loopar som spelas när du väcker din iPhone."),
 "da": ("• 4 nye kodede scener: Nordlys, Neonregn, Bioluminescens og Begivenhedshorisont.\n• 20 filmiske loops i appen og i dine Live Photos.\n• I natbordstilstand vælger du enhver scene, mens du lader op.\n• En tydeligere Pro-side med gratis prøveperiode på årsplanen.\n• Rettelser og forbedringer.",
        "Nyt: Nordlys, Neonregn, Bioluminescens og Begivenhedshorisont. 20 loops, der afspilles, når du vækker din iPhone."),
 "no": ("• 4 nye kodede scener: Nordlys, Neonregn, Bioluminescens og Hendelseshorisont.\n• 20 filmatiske looper i appen og i Live Photos.\n• I nattbordmodus velger du hvilken som helst scene mens du lader.\n• En tydeligere Pro-side med gratis prøveperiode på årsplanen.\n• Rettelser og forbedringer.",
        "Nytt: Nordlys, Neonregn, Bioluminescens og Hendelseshorisont. 20 looper som spilles når du vekker iPhonen."),
 "pl": ("• 4 nowe sceny stworzone kodem: Zorza polarna, Neonowy deszcz, Bioluminescencja i Horyzont zdarzeń.\n• 20 filmowych pętli w aplikacji i w Live Photos.\n• W trybie szafki nocnej wybierzesz dowolną scenę podczas ładowania.\n• Czytelniejsza strona Pro z darmowym okresem próbnym w planie rocznym.\n• Poprawki i ulepszenia.",
        "Nowość: Zorza polarna, Neonowy deszcz, Bioluminescencja i Horyzont zdarzeń. 20 pętli, które ożywają po wybudzeniu iPhone’a."),
 "ru": ("• 4 новые сцены, созданные кодом: Северное сияние, Неоновый дождь, Биолюминесценция и Горизонт событий.\n• 20 кинематографичных циклов в приложении и в Live Photo.\n• В режиме прикроватных часов можно выбрать любую сцену во время зарядки.\n• Более понятная страница Pro с бесплатным пробным периодом в годовом плане.\n• Исправления и улучшения.",
        "Новое: Северное сияние, Неоновый дождь, Биолюминесценция и Горизонт событий. 20 циклов оживают, когда ты будишь iPhone."),
 "ja": ("• コードで描いた新シーン4つ：オーロラ、ネオンレイン、生物発光、事象の地平面。\n• アプリでもLive Photoでも再生される20本のシネマティックループ。\n• ナイトスタンドモードで、充電中に好きなシーンを選べます。\n• 年額プランの無料トライアル付きで、Proページがわかりやすくなりました。\n• 不具合の修正と改善。",
        "新登場：オーロラ、ネオンレイン、生物発光、事象の地平面。iPhoneを起こすと動き出す20本のシネマティックループ。"),
 "ko": ("• 코드로 만든 새 장면 4개: 오로라, 네온 레인, 생물 발광, 사건의 지평선.\n• 앱과 Live Photo에서 재생되는 시네마틱 루프 20개.\n• 나이트스탠드 모드에서 충전 중 원하는 장면을 고르세요.\n• 연간 플랜 무료 체험이 포함된 더 명확한 Pro 페이지.\n• 버그 수정 및 개선.",
        "새로운 장면: 오로라, 네온 레인, 생물 발광, 사건의 지평선. iPhone을 깨우면 재생되는 시네마틱 루프 20개."),
 "zh-Hans": ("• 4 个代码创作的新场景：北极光、霓虹雨、生物荧光和事件视界。\n• 20 段电影级循环，在 App 和实况照片中播放。\n• 床头模式下，充电时可选择任意场景。\n• 更清晰的 Pro 页面，年度方案提供免费试用。\n• 问题修复与改进。",
             "全新：北极光、霓虹雨、生物荧光和事件视界。唤醒 iPhone 即播放的 20 段电影级循环。"),
 "zh-Hant": ("• 4 個以程式碼打造的新場景：北極光、霓虹雨、生物螢光和事件視界。\n• 20 段電影級循環，在 App 和原況照片中播放。\n• 床頭模式下，充電時可選擇任意場景。\n• 更清楚的 Pro 頁面，年度方案提供免費試用。\n• 問題修正與改進。",
             "全新：北極光、霓虹雨、生物螢光和事件視界。喚醒 iPhone 即播放的 20 段電影級循環。"),
 "ar-SA": ("• 4 مشاهد جديدة مصنوعة بالبرمجة: الشفق القطبي ومطر النيون والضياء الحيوي وأفق الحدث.\n• 20 حلقة سينمائية تعمل في التطبيق وفي Live Photo.\n• في وضع السرير اختر أي مشهد أثناء الشحن.\n• صفحة Pro أوضح مع تجربة مجانية في الخطة السنوية.\n• إصلاحات وتحسينات.",
           "جديد: الشفق القطبي ومطر النيون والضياء الحيوي وأفق الحدث. 20 حلقة سينمائية تتحرك عند إيقاظ iPhone."),
 "hi": ("• कोड से बने 4 नए सीन: नॉर्दर्न लाइट्स, नियॉन बारिश, जैव-प्रकाश और इवेंट होराइज़न।\n• ऐप और आपकी Live Photo में चलने वाले 20 सिनेमैटिक लूप।\n• नाइटस्टैंड मोड में चार्जिंग के दौरान कोई भी सीन चुनें।\n• सालाना प्लान पर मुफ़्त ट्रायल के साथ साफ़ Pro पेज।\n• सुधार और बेहतरी।",
        "नया: नॉर्दर्न लाइट्स, नियॉन बारिश, जैव-प्रकाश और इवेंट होराइज़न। iPhone जगाते ही चलने वाले 20 सिनेमैटिक लूप।"),
 "id": ("• 4 adegan baru buatan kode: Cahaya Utara, Hujan Neon, Bioluminesensi, dan Cakrawala Peristiwa.\n• 20 loop sinematik di aplikasi dan di Live Photo Anda.\n• Mode meja samping kini bisa memilih adegan apa pun saat mengisi daya.\n• Halaman Pro lebih jelas dengan uji coba gratis untuk paket tahunan.\n• Perbaikan dan penyempurnaan.",
        "Baru: Cahaya Utara, Hujan Neon, Bioluminesensi, dan Cakrawala Peristiwa. 20 loop sinematik yang hidup saat iPhone dibangunkan."),
 "th": ("• 4 ฉากใหม่ที่สร้างด้วยโค้ด: แสงเหนือ ฝนนีออน การเรืองแสงชีวภาพ และขอบฟ้าเหตุการณ์\n• 20 ลูปแบบภาพยนตร์ที่เล่นในแอปและใน Live Photo\n• โหมดข้างเตียงเลือกฉากใดก็ได้ขณะชาร์จ\n• หน้า Pro ที่ชัดเจนขึ้นพร้อมทดลองใช้ฟรีสำหรับแผนรายปี\n• แก้ไขและปรับปรุง",
        "ใหม่: แสงเหนือ ฝนนีออน การเรืองแสงชีวภาพ และขอบฟ้าเหตุการณ์ 20 ลูปที่เคลื่อนไหวเมื่อปลุก iPhone"),
 "vi": ("• 4 cảnh mới tạo bằng mã: Bắc cực quang, Mưa neon, Phát quang sinh học và Chân trời sự kiện.\n• 20 vòng lặp điện ảnh phát trong ứng dụng và trong Live Photo.\n• Chế độ đầu giường cho phép chọn bất kỳ cảnh nào khi sạc.\n• Trang Pro rõ ràng hơn với dùng thử miễn phí cho gói năm.\n• Sửa lỗi và cải tiến.",
        "Mới: Bắc cực quang, Mưa neon, Phát quang sinh học và Chân trời sự kiện. 20 vòng lặp sống động khi bạn đánh thức iPhone."),
}

APP_INFO = {
    "en-US": ("Live Wallpaper: Video to Live", "Live Photo Maker & Lock Screen"),
    "tr": ("Canlı Duvar Kağıdı: Live Photo", "Hareketli Kilit Ekranı, Widget"),
}
KEYWORDS = {
    "en-US": "moving,animated,background,aesthetic,nightstand,standby,clock,widget,spatial,tilt,pixel,gif,car",
    "tr": "hareketli,arka plan,tema,video,animasyonlu,estetik,saat,komodin,uzamsal,eğme,piksel,araba,uzay",
}

def main():
    out = root / "metadata/version/1.0.4"
    out.mkdir(parents=True, exist_ok=True)
    for path in sorted((source / "version/1.0.3").glob("*.json")):
        locale = path.stem
        data = json.loads(path.read_text())
        description = data["description"]
        for old, new in FIXES[locale]:
            if old not in description:
                raise SystemExit(f"{locale}: live text changed, missing: {old}")
            description = description.replace(old, new)
        data["description"] = description
        data["whatsNew"], data["promotionalText"] = NEWS[locale]
        if locale in KEYWORDS:
            data["keywords"] = KEYWORDS[locale]
        assert len(data["keywords"]) <= 100, f"{locale} keywords {len(data['keywords'])}"
        assert len(data["promotionalText"]) <= 170, f"{locale} promo {len(data['promotionalText'])}"
        assert len(data["whatsNew"]) <= 4000 and len(description) <= 4000
        (out / path.name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    info = root / "metadata/app-info"
    info.mkdir(parents=True, exist_ok=True)
    for path in sorted((source / "app-info").glob("*.json")):
        data = json.loads(path.read_text())
        if path.stem in APP_INFO:
            data["name"], data["subtitle"] = APP_INFO[path.stem]
        assert len(data["name"]) <= 30 and len(data.get("subtitle", "")) <= 30, path.stem
        (info / path.name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print(f"prepared {len(list(out.glob('*.json')))} version and {len(list(info.glob('*.json')))} app-info locales")

if __name__ == "__main__":
    main()
