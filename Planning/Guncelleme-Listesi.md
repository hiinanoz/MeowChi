# Sıradaki güncelleme listesi

Sonraki sürüme kalan işler. Açık maddeler `Tools/release_check.py` çıktısında (ve TestFlight yükleme
iş akışında) hatırlatma olarak görünür. Biten madde `[x]` yapılır.

## Yapılacaklar

- [x] **Çeviriler (tr, es, de, ja, ko, fr).** İki .xcstrings dosyası; şu an yalnızca İngilizce.
- [ ] **Son pixel art ve uygulama simgesi.** Yer tutucu PNG'ler aynı adlarla değişecek (docs/ASSETS.md).
- [x] **Yarn Ball ve Toy Mouse mini oyunları.**
- [x] **Kedi büyümesi** (docs/GROWTH_PLAN.md) ve **kişilikler**. Aşama çizimleri son pixel art ile gelecek.
- [x] **Web sayfalarındaki ayar adları.** Uygulama çevrilince docs/_src altındaki menü adlarını (ör. "Gentle reminders") çevirilerle eşleştir, `python3 Tools/build_docs.py` çalıştır.
- [ ] **Game Center ve iCloud yedeği.** Plan: docs/ONLINE_PLAN.md (onay bekliyor).
- [ ] **Widget'ı gerçek cihazda dene.** "Sev" düğmesi, kalp ve zzz.

## UX geliştirme planı (sırayla; kullanıcı kararları: geçici çizim üret, mevsimler kış/bahar/yaz, dekor ve aksesuar yalnızca mağazada, ad ve görünüm ayarlardan ücretsiz)

- [x] **A. Dokunuş ve hareket:** basılan düğme çöksün, başarısız dokunuşta sallanma ve titreşim, HUD sayaçları yuvarlanarak artsın, altın ve XP uçuşu, pixel iris geçişi.
- [x] **B. Kutlamalar:** seviye atlama kartı (açılan eşyalarla), mini oyun rekorları ve yıldızlar.
- [x] **C. Menüler:** canlı menü kutuları, bölümlü ayarlar (ad ve görünüm değiştirme, hakkında, gizlilik, destek), hareketli ana menü.
- [x] **D. Mağaza:** sekmeler (Mama/Oyuncak/Aksesuar/Dekor), günün fırsatı, satın alma yalnızca mağazada; Dekor yalnızca yerleştirir.
- [x] **E. Kediyle bağ:** kedi kartı (paylaşılabilir), kedi istekleri, kedi günlüğü.
- [x] **F. Oda:** gün saati ve hava, ortam hareketi (kuş, toz, bitki, saat).
- [x] **G. Ses:** yeni efektler, ruh haline göre miyavlar, gece müziği; sesler GitHub'daki Mac'te üretilir.
- [x] **H. Toplama:** yürüyüş buluntuları albümü, mevsimlik içerik.
- [x] **I. Geçici çizimler:** büyüme sahnesi, yeni kedi pozları, ekran temaları, boş durum çizimleri, açılış animasyonu, pixel logo.
- [ ] **J. TestFlight'a yükle.**
