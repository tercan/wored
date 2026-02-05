# Wored Müzik Çalıcısı - Yol Haritası

## Genel Bakış

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        WORED DEVELOPMENT ROADMAP                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  v0.1 ──► v0.2 ──► v0.3 ──► v0.4 ──► v1.0 ──► v1.1+                   │
│   │        │        │        │        │        │                        │
│   │        │        │        │        │        └─► Entegrasyonlar       │
│   │        │        │        │        └─► Stabil Sürüm                  │
│   │        │        │        └─► Gelişmiş UI                            │
│   │        │        └─► Veri Kalıcılığı                                 │
│   │        └─► Temel Özellikler+                                        │
│   └─► Mevcut (Temel Çalıcı)                                             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## v0.1 - Mevcut Durum ✅

**Durum:** Tamamlandı

| Özellik                                 | Durum |
| --------------------------------------- | :---: |
| SwiftUI + MVVM mimarisi                 |  ✅   |
| Play/Pause/Seek kontrolleri             |  ✅   |
| İleri/Geri şarkı geçişi                 |  ✅   |
| Dosya ekleme (file picker)              |  ✅   |
| Metadata okuma (title, artist, artwork) |  ✅   |
| Playlist görünümü                       |  ✅   |
| Otomatik sonraki şarkıya geçiş          |  ✅   |
| Modern flat UI tasarımı                 |  ✅   |

---

## v0.2 - Temel Özellikler+ 🎯


### Hedefler

- [x] **Volume Control** - Ses seviyesi ayarlama
- [x] **Shuffle Mode** - Karıştırma modu
- [x] **Repeat Modes** - Tekrar modları (one/all)
- [x] **Delete Song** - Şarkı silme
- [x] **Song Duration** - Şarkı süresini listede göster

### Teknik Gereksinimler

```swift
// ViewModel'e eklenecek
@Published var volume: Float = 1.0
@Published var isShuffled: Bool = false
@Published var repeatMode: RepeatMode = .none

enum RepeatMode {
    case none, one, all
}
```

---

## v0.3 - Veri Kalıcılığı 💾


### Hedefler

- [x] **Playlist Persistence** - Playlist'i kaydet/yükle
- [x] **Security Bookmarks** - Dosya erişimini kalıcı yap
- [x] **Resume Playback** - Son kaldığı yerden devam
- [x] **User Preferences** - Ayarları hatırla

### Teknik Gereksinimler

```swift
// Bookmark Manager
class BookmarkManager {
    func saveBookmark(for url: URL)
    func loadBookmarks() -> [URL]
}

// Playlist Model (Codable)
struct PlaylistData: Codable {
    let songs: [SongData]
    let lastPlayedIndex: Int?
    let lastPlayedPosition: TimeInterval?
}
```

---

## v0.4 - Gelişmiş UI 🎨


### Hedefler

- [x] **Context Menu** - Sağ tık menüsü
- [x] **Keyboard Shortcuts** - Klavye kısayolları
- [x] **Drag & Drop** - Sıralama UI'ı
- [ ] **Search Bar** - Arama çubuğu (kaldırıldı, yeniden planlanmıyor)

### Kullanıcı Deneyimi İyileştirmeleri

- Animasyonlar ve geçişler
- Görsel geri bildirimler
- Erişilebilirlik (Accessibility) desteği

---

## v1.0 - Stabil Sürüm 🚀


### Hedefler

- [ ] **Bug Fixes** - Hata düzeltmeleri
- [ ] **Performance** - Performans optimizasyonları
- [ ] **Polish** - UI/UX cilalama
- [ ] **App Icon** - Uygulama ikonu tasarımı
- [ ] **Documentation** - Kullanıcı dokümantasyonu

### Kalite Gereksinimleri

- Tüm kritik senaryolar test edilmiş
- Memory leak yok
- Crash yok
- Tutarlı UI davranışı

---

## v1.1+ - Gelişmiş Özellikler 🌟

**Gelecek Sürümler**

### Audio İyileştirmeleri

| Özellik          | Açıklama         |
| ---------------- | ---------------- |
| Gapless Playback | Kesintisiz çalma |
| Crossfade        | Geçiş efekti     |
| Equalizer        | Ses ekolayzeri   |

### Sistem Entegrasyonları

| Özellik     | Açıklama             |
| ----------- | -------------------- |
| Touch Bar   | MacBook Pro kontrolü |
| Menu Bar    | Hızlı erişim         |
| Now Playing | macOS entegrasyonu   |
| Widgets     | macOS Widgets        |

### Ekstra Özellikler

| Özellik            | Açıklama                      |
| ------------------ | ----------------------------- |
| Multiple Playlists | Çoklu playlist                |
| Smart Playlists    | Akıllı listeler               |
| Audio Visualizer   | Görsel efektler               |
| Lyrics             | Şarkı sözleri                 |
| Last.fm Scrobbling | Dinleme takibi                |
| iCloud Sync        | Cihazlar arası senkronizasyon |

---

## Zaman Çizelgesi

```
2026
├── Ocak
│   ├── Hafta 1-2: v0.2 (Temel Özellikler+)
│   └── Hafta 3-4: v0.3 (Veri Kalıcılığı)
├── Şubat
│   ├── Hafta 1-3: v0.4 (Gelişmiş UI)
│   └── Hafta 4: Test & Bug Fix
└── Mart
    ├── Hafta 1-2: v1.0 (Stabil Sürüm)
    └── Hafta 3+: v1.1+ (Gelişmiş Özellikler)
```

---

## Notlar

> [!TIP]
> Her sürümden önce mevcut özelliklerin stabil çalıştığından emin olun.

> [!IMPORTANT]
> v0.3'teki Security Bookmarks kritik öneme sahiptir. Sandbox ortamında dosya erişimi için gereklidir.

> [!NOTE]
> Yol haritası esnektir ve kullanıcı geri bildirimlerine göre güncellenebilir.

---

## v0.5 - Pencere Davranışları ve Oturum Durumu 🪟


### Hedefler

- [x] **Playlist Docked Mode** - Playlist penceresi Player'a bağlı alt panel
- [x] **Playlist Visible State** - Açık/kapalı durumu oturumlar arası hatırlansın
- [x] **Shuffle/Repeat State** - Shuffle ve repeat modları oturumlar arası hatırlansın
- [ ] **Reset Preferences** - Ayarları sıfırlama (Ayarlar ekranı sonrası)

---

## Ek Backlog (Talep Olasılığı Yüksek)

> Aşağıdakiler kullanıcı ihtiyacına göre önceliklendirilebilir.

- [ ] **Global Media Keys / Hotkeys** - Uygulama arka plandayken de kontrol
- [ ] **Queue Management** - “Play Next”, “Add to Queue” aksiyonları
- [ ] **Favorites** - Favori şarkılar listesi
- [ ] **History** - Son çalınanlar
- [ ] **Playback Speed** - Hız kontrolü (0.5x–2x)
- [ ] **Per-Track Gain** - Ses normalizasyonu (isteğe bağlı)
- [ ] **Mouse Scroll Controls** - Scroll ile ses ve seek kontrolü
