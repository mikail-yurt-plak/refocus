# ReFocus - Ürün Özellikleri

**KİŞİYE ÖZEL ODAK & ZAMAN YÖNETİMİ**
iOS ve macOS Uygulaması

---

## 1. Ürün Tanımı

Bu ürün, kullanıcıların odaklanma profillerine göre en uygun zaman yönetimi metodunu otomatik olarak seçen, nazik yönlendirme ile dikkat dağınıklığını azaltan bir odak asistanıdır.

**Bu bir Pomodoro uygulaması değildir.**

Bu ürün şu soruya cevap verir:
**"Bugün en verimli nasıl çalışmalıyım?"**

---

## 2. Çözülen Problem

- Dikkat süreleri kısaldı
- Herkese tek metod (Pomodoro) işe yaramıyor
- Kullanıcılar ayar yapmak istemiyor
- Zorlayıcı ve kısıtlayıcı uygulamalar hızla siliniyor
- Sosyal medya bağımlılığı engelleme ile değil, farkındalıkla azalıyor

---

## 3. Ürün Felsefesi

### Temel İlkeler

- Kullanıcıya karar yükü bindirilmez
- Kişiselleştirme ayarlarla değil, davranışla yapılır
- Uygulama zorlamaz, yargılamaz
- Engelleme yok, farkındalık var
- UI arka planda kalır, odak öne çıkar

**Ürün bir disiplin aracı değil, sakin bir koçtur.**

---

## 4. Hedef Kitle (MVP)

- Bilgi çalışanları (yazılım, tasarım, analiz)
- Üniversite öğrencileri
- Freelance çalışanlar
- Odak problemi yaşayan ama "task app" istemeyen kullanıcılar

---

## 5. Kullanıcı Onboarding & Profil Modeli

### İlk Açılış Soruları (maks. 30 saniye)

**1. Ne tür iş yapıyorsun?**
- Öğrenci
- Bilgi çalışanı
- Yaratıcı
- Yönetici

**2. Bir işe başladıktan sonra ne zaman zorlanırsın?**
- 10–15 dk
- 20–30 dk
- 40+ dk

**3. En zor olan hangisi?**
- Başlamak
- Sürdürmek
- Bitirmek

**4. Çalışırken telefona bakma dürtüsü ne sıklıkta gelir?**
- Çok sık
- Bazen
- Nadiren

### Profil Tipleri (Kullanıcıya Gösterilmez)

- **Kısa Odaklı**
- **Orta Odaklı**
- **Derin Odaklı**
- **Dalgalı Odaklı**

---

## 6. Zaman Yönetimi Metodları (MVP)

- **Pomodoro** (25/5)
- **40/10**
- **52/17**
- **Deep Work** (90 dk)

---

## 7. Metod Seçim Motoru (Rule-Based – MVP)

```
Eğer dikkat < 20 dk → Pomodoro
Eğer Pomodoro kısa geliyorsa → 40/10
Eğer kesintisiz çalışma yüksekse → Deep Work
Eğer gün içinde sık bölünüyorsa → 52/17
```

**MVP'de AI zorunlu değildir.**
Kural tabanlı sistem yeterlidir.

---

## 8. MVP Ekran Yapısı

### Toplam: 6 Ana Ekran

#### 1. Onboarding
- Kart bazlı sorular
- Progress bar
- Minimal metin

#### 2. Günlük Öneri (Ana Ekran)
- "Bugün senin için en uygun yöntem"
- Tek CTA: **Başla**

#### 3. Odak Ekranı
- Büyük sayaç
- Yumuşak animasyon
- Rahatlatıcı arka plan

#### 4. Mola Ekranı
- Geri sayım
- Nazik mola önerileri

#### 5. Seans Sonu Geri Bildirim
- Zor muydu?
- Odaklandın mı?
- Süre uygun muydu?

#### 6. Gün Sonu Özet
- Toplam odak süresi
- Kullanılan metod
- Yarın için öneri

---

## 9. Nazik Uyarı Mikrocopy Sistemi

### Seans Başlarken

```
"Bu seans sırasında dikkatin dağılabilir.
Fark ettiğinde geri dönmen yeterli."
```

### Uygulama Arka Plana Alındığında (30–60 sn)

```
"Bir süreliğine ara verdin.
Hazırsan kaldığın yerden devam edebiliriz."
```

### Uzun Bölünme (2–3 dk)

```
"Dönmek zor olabilir.
İstersen bu seansı kısa tutabiliriz."
```

### Seans Sonu

```
"Bu seans sırasında birkaç kez bölündün.
Bu çok yaygın. Önemli olan geri dönmendi."
```

---

## 10. Bölünme Ölçümü & UX Gösterimi

### Ölçülen Davranışlar

- Uygulamanın arka plana alınması
- Geri dönüş süresi
- Toplam bölünme süresi

### Kullanıcıya Gösterim (Ham Veri Yok)

#### Seans Sonu – Odak Akışı

```
┃█████░░██░████░░░████┃
```

- **Dolu alan:** Odak
- **Boşluk:** Bölünme

**Alt metin:**

```
"Odak akışın genel olarak korundu."
```

#### Gün Sonu Durumları

- 🟢 **Stabil**
- 🟡 **Dalgalı**
- 🔵 **Zor Gün**

**Kırmızı yok. Yargı yok.**

---

## 11. Bildirim Stratejisi

### Asla Yapılmayacaklar

- Sürekli push bildirim
- Rastgele "çalış" hatırlatmaları
- Suçlayıcı dil

### Bildirim Türleri (MVP)

- Günlük başlama hatırlatıcısı
- Seans bitiş bildirimi
- Gün sonu sessiz özet

---

## 12. Rahatlatıcı Sesler

### Karar

✅ **Var**
❌ **Playlist yok**

### Kullanım

- 3–4 adet ambient / white noise
- Varsayılan: **Kapalı**
- Özellikle Deep Work modunda önerilir

**Amaç müzik değil, ortam hissi**

---

## 13. Başarı Haritası (Sessiz Retrospektif)

### Gösterim

- Haftalık / aylık heatmap
- Renk yoğunluğu = odak akışı kalitesi
- Sayı ve karşılaştırma yok

### Metin Örnekleri

```
"Geçen haftaya göre daha hızlı geri dönüyorsun."
```

---

## 14. Tasarım Sistemi

### Renkler

| Renk | Hex Code | Kullanım |
|------|----------|----------|
| Primary (Odak Yeşili) | `#2E7D6F` | Ana tema rengi |
| Arka Plan | `#F6F8F7` | Uygulama arka planı |
| Kart | `#FFFFFF` | Kart arka planları |
| Mola Mavisi | `#E8F1F8` | Mola ekranı |
| Nazik Uyarı | `#FFF4E5` | Uyarı mesajları |

### Typography

- **Font:** SF Pro (iOS) / Inter
- **Başlık:** Semibold
- **Gövde:** Regular
- **Sayaç:** Medium / Semibold

### Stil

- Minimal
- Yuvarlak köşeler
- Bol boşluk
- Hafif animasyon

---

## 15. MVP Kapsam Dışı

Aşağıdaki özellikler MVP'de **OLMAYACAK:**

- ❌ Görev listeleri
- ❌ Takvim entegrasyonu
- ❌ Sosyal özellikler
- ❌ Rozet / leaderboard
- ❌ Zorlayıcı engellemeler

---

## Sürüm Bilgisi

**Doküman Versiyonu:** 1.0
**Tarih:** Ocak 2026
**Durum:** MVP Planlama Aşaması
