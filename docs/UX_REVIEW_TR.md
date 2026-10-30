# Meowchi: UX ve akış değerlendirmesi (Apple HIG'e göre)

Durum: tüm özellikler eklendikten sonra (Faz 5e) yapılan inceleme. **Faz 5f'de 6.1 dışındaki tüm maddeler uygulandı** (aşağıdaki "Uygulama durumu" bölümüne bakın). Öncelik sırası: **P1** yayın öncesi şart, **P2** güçlü öneri, **P3** sonrası için.

## 1. Gezinme ve bilgi mimarisi

| # | Bulgu | Öneri | Öncelik |
|---|---|---|---|
| 1.1 | Ana ekranda 9 ayrı giriş noktası var: HUD'da menü, koleksiyon, ayarlar, görevler ve coin/mağaza; odada kamera ve dekor; altta 5 aksiyon. Yeni oyuncu nereye bakacağını bilemiyor. | İşlevleri gruplayın. **Alt aksiyon çubuğu = kediyle ilgili işler** (Besle, Temizle, Oyna, Uyut, Sağlık). Diğer her şey için tek bir **"Menü" sayfası**: Mağaza, Dekor, Koleksiyon, Görevler, Ayarlar ve Ana menü. HUD'da yalnızca coin ve görev rozeti kalsın. | P1 |
| 1.2 | HUD'daki ikon butonları yaklaşık 26 pt. HIG en az **44×44 pt** dokunma alanı istiyor. | Butonları büyütün ya da `.contentShape` ile görünümü değiştirmeden dokunma alanını 44 pt'ye çıkarın. | P1 |
| 1.3 | Sheet'lerde sol üstte "← Geri" var. HIG'de geri oku **navigasyon yığını** içindir; modal sheet'ler için "Kapat/Bitti" ve aşağı kaydırma beklenir. | Tam ekran oyunlarda ve iç içe sayfalarda **Geri**, sheet'lerde sağ üstte **Kapat (✕)** ve sürükleme tutamacı kullanın. Dekor kategorileri için `NavigationStack` kurun (Dekor → kategori → eşya), böylece Geri gerçekten bir önceki sayfaya döner. | P2 |
| 1.4 | Ana menü her açılışta oyuncuyu odadan önce durduruyor. HIG, uygulamanın açılışta beklettirmemesini öneriyor. | Ana menüde varsayılan buton **"Devam et"** olsun. Ayarlara "Açılışta doğrudan eve git" seçeneği ekleyin. Uzun aradan sonra gelen oyuncuya kısa bir "Mochi seni özledi" kartı gösterin. | P2 |
| 1.5 | Bakım panelleri odanın altını kaplayıp kediyi gizliyor. | Panelleri `.presentationDetents([.height(…)])` ile yarım sheet yapın ya da paneli aksiyon çubuğunun hemen üstünde ince tutun; kedi her zaman görünür kalsın. | P2 |
| 1.6 | "Oyna" paneli 5 satıra çıktı: Cozy, arkadaş, TV, lazer, gezinti. | İki gruba ayırın: **Kediyle vakit** (Cozy, TV, arkadaş) ve **Oyunlar ve gezintiler** (lazer, yürüyüş). Kilitli ya da bekleme süresindeki satırlar soluk görünsün ve kalan süreyi göstersin. | P3 |

## 2. Geçişler ve hareket

| # | Bulgu | Öneri | Öncelik |
|---|---|---|---|
| 2.1 | Ekran geçişleri (opacity, sheet, fullScreenCover) karışık; aralarında bir bağ hissi yok. | Odadan oyuna geçerken kısa bir "kapı" geçişi kullanın: oda kararır, sonra oyun açılır. Panelden ekrana geçişte `matchedGeometryEffect` ile panelin büyüyüp ekrana dönüşmesini sağlayın. | P2 |
| 2.2 | Hareketi azalt (Reduce Motion) ayarına uyulmuyor: kedi zıplıyor, baloncuk sallanıyor, fotoğrafta flaş patlıyor. | `@Environment(\.accessibilityReduceMotion)` açıkken flaşı, sallanmayı ve parıltı efektlerini kapatın ya da yumuşatın. | P1 |
| 2.3 | İlk açılışta (shader derlenirken) birkaç saniye boş ya da gri ekran oluşabiliyor. | Açılış ekranının arkasında shader'ları önceden ısıtın. Ana menüde küçük bir "kedi uyanıyor" animasyonu gösterin. | P2 |
| 2.4 | Haptik kullanılıyor, ama SwiftUI tarafında yok. | iOS 17'nin `.sensoryFeedback` özelliğini satın alma, ödül alma ve seviye atlamada kullanın. | P3 |

## 3. Erişilebilirlik

| # | Bulgu | Öneri | Öncelik |
|---|---|---|---|
| 3.1 | Yazılar sabit punto; Dinamik Yazı (Dynamic Type) ile büyümüyor. | `PixelFont`'u `@ScaledMetric` ya da `Font.custom(…, relativeTo:)` ile Dinamik Yazı'ya bağlayın. En büyük erişilebilirlik boyutlarında yerleşimi test edin. | P1 |
| 3.2 | SpriteKit sahnesi VoiceOver'a görünmüyor; kediyi sevmek yalnızca hareketle yapılabiliyor. | Sahneye `accessibilityElement` ekleyin ve "Kediyi sev", "Kediyi tara" gibi `accessibilityActions` tanımlayın. Durum metni de verin, örneğin "Mochi mutlu, aç". | P1 |
| 3.3 | Kontrast: krem üzerindeki turuncu küçük yazı (accentShade) 4,5:1 oranının altında kalabilir. | Küçük yazılarda koyu mürekkep rengini kullanın; turuncuyu yalnızca büyük yazılarda tutun. | P1 |
| 3.4 | Stat çubukları renge dayanıyor. Yüzde yazısı var, iyi. | Kritik düzeyde çubuğa bir ikon ya da desen ekleyin. | P3 |

## 4. Geri bildirim, hata ve güven

| # | Bulgu | Öneri | Öncelik |
|---|---|---|---|
| 4.1 | Pahalı alımlar (250 coin ve üstü) tek dokunuşla yapılıyor. | 200 coin üzerindeki alımlarda onay isteyin, ya da 5 saniyelik "Geri al" bandı gösterin. | P2 |
| 4.2 | Bildirim bantları 2 saniyede kayboluyor ve VoiceOver bunları okumuyor. | Bantlarda `AccessibilityNotification.Announcement` kullanın. Önemli bantları (rozet, seviye) biraz daha uzun gösterin. | P2 |
| 4.3 | Kayıt bozulursa çıkan uyarı teknik bir dil kullanıyor. | Uyarı sakin ve somut olsun; "Yardım" bağlantısı içersin. | P3 |
| 4.4 | Fotoğraf paylaşımı ve silme çalışıyor; "Fotoğraflar'a kaydet" yok. | ShareLink yeterli. Ayrı bir kayıt seçeneği eklenecekse yalnızca ekleme izni (`NSPhotoLibraryAddUsageDescription`) isteyin. | P3 |

## 5. İlk deneyim ve alışkanlık döngüsü

| # | Bulgu | Öneri | Öncelik |
|---|---|---|---|
| 5.1 | Onboarding iyi: kısa, atlanabilir ve oynayarak öğretiyor (HIG'e uygun). | Yeni özellikler (TV, tırnak, gezinti) ilk kez açıldığında tek cümlelik bir ipucu kartı gösterin. Bu ipuçları bir kez çıksın. | P2 |
| 5.2 | Günlük giriş, görevler ve widget alışkanlık döngüsü kuruyor. | Bildirimleri Faz 6'da ekleyin. İzni oyuncu ilk günlük ödülünü aldıktan sonra, nedenini açıklayan bir kartla isteyin. | P2 |

## 6. Platform

| # | Öneri | Öncelik |
|---|---|---|
| 6.1 | Widget için App Group imzası gerekiyor; Developer Team ID ile imzalanmadan widget yalnızca "Meowchi'yi aç" gösterir. | P1 |
| 6.2 | iPad: odayı ortada büyük gösterin; paneller yan sütunda (sidebar) dursun. Yatay yönü de destekleyin. | P3 |
| 6.3 | Yerelleştirme: Almanca ve Fransızca metinler daha uzun. Pseudo-localization ile taşan butonları önceden bulun. | P1 (Faz 6) |

## Önerilen uygulama sırası

1. 1.1 Menü sadeleştirme, 1.2 dokunma alanları, 3.1 Dinamik Yazı, 3.2 VoiceOver eylemleri, 3.3 kontrast, 2.2 Hareketi azalt
2. 1.3 Kapat/Geri ayrımı ve NavigationStack, 1.5 yarım paneller, 1.4 "Devam et", 4.1–4.2
3. Geçiş animasyonları (2.1), ilk kez ipuçları (5.1), iPad

## Uygulama durumu (Faz 5f)

| Madde | Durum |
|---|---|
| 1.1 Menü sadeleştirme | ✅ HUD'da coin, görevler ve Menü; geri kalan her şey Menü sayfasında |
| 1.2 Dokunma alanları | ✅ `.hitTarget()` ile 44 pt |
| 1.3 Kapat / Geri | ✅ Sheet'lerde ✕ ve kaydırma; tam ekranda ve iç sayfalarda Geri; Dekor `NavigationStack` |
| 1.4 Devam et | ✅ "Devam et", "açılışta doğrudan eve git" ayarı, 8 saatten sonra "hoş geldin" bandı |
| 1.5 Paneller | ✅ Panel açıkken kedi arka tarafa yürüyor ve görünür kalıyor |
| 1.6 Oyna paneli | ✅ İki gruba ayrıldı; bekleme süresindeki satırlar soluk |
| 2.1 Geçişler | ✅ Odadan oyuna kararan "kapı" geçişi (panelden ekrana geometri animasyonu yerine) |
| 2.2 Hareketi azalt | ✅ Sallanma, flaş, parıltı ve kayan geçişler kapatıldı |
| 2.3 Shader ısıtma | ✅ Açılışta görünmez önden çizim |
| 2.4 Haptik | ✅ `sensoryFeedback`: seviye, rozet, satın alma |
| 3.1 Dinamik Yazı | ✅ accessibility1 boyutuna kadar |
| 3.2 VoiceOver | ✅ Oda tek bir öğe: isim ve ruh hali; sev, tara, fotoğraf çek ve tırmalama eylemleri |
| 3.3 Kontrast | ✅ Küçük yazılar için koyu tonlar |
| 3.4 Kritik işaret | ✅ "!" işareti |
| 4.1 Pahalı alım onayı | ✅ 200 coin ve üstü |
| 4.2 Sesli bildirim | ✅ Bantlar VoiceOver ile okunuyor; önemli olanlar 3,5 sn kalıyor |
| 4.3 Kayıt hatası | ✅ Sakin metin ve "Yardım al" bağlantısı |
| 4.4 Fotoğraflar | ✅ ShareLink yeterli bulundu; ek izin istenmiyor |
| 5.1 İlk kez ipuçları | ✅ Cozy, gezinti, tırnak, dekor, koleksiyon, TV |
| 5.2 Hatırlatıcılar | ✅ İsteğe bağlı; ilk ödülden sonra bir kez soruluyor; günde en fazla 1, gece yok |
| 6.1 İmza ve App Group | ⏳ Team ID gerekiyor |
| 6.2 iPad | ✅ Dikeyde üst üste (2×), yatayda yan yana |
| 6.3 Uzun metin testi | ✅ Çift uzunlukta metinle kontrol edildi; taşan butonlar ve satırlar düzeltildi |
