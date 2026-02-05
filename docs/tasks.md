# Wored - Issue Listesi ve Sprint Planı

Bu doküman, mevcut planın doğrudan issue listesi ve sprint planı formatına dönüştürülmüş halidir.

## Issue Listesi (Backlog)

## UI/UX Kriterleri (Zorunlu)
- Köşe radius maksimum 4px ve sadece gerekli yerlerde kullanılacak
- Ekran kompakt olacak: büyük kapak görselleri, devasa butonlar ve geniş playlist görünümü yok
- Tasarım minimal, fonksiyonel, temiz ve “zekice kurgulanmış” olacak
- Player penceresi mümkün olduğunca küçük olacak
- Playlist penceresi ayrı olacak, istenildiğinde göster/gizle yapılabilecek
- Playlist penceresi yeniden boyutlandırılabilir olacak

### P0 - Stabilite ve Doğruluk
- [x] ISS-001 Security-scoped resource yaşam döngüsü düzeltme (start/stop, stale bookmark yenileme)
- [x] ISS-002 Playlist sonunda playback state düzeltme (isPlaying, currentTime, duration, currentIndex)
- [x] ISS-003 Seek sırasında UI jitter engelleme (isSeeking, timer gating)
- [x] ISS-004 Kullanıcıya hata bildirimi (alert/toast + error state)

### P1 - Temel Özellikler
- [x] ISS-005 Volume slider + mute + kalıcılık (UserDefaults)
- [x] ISS-006 Shuffle/Repeat modları (none/one/all) + UI ikonları
- [x] ISS-007 Şarkı silme + Clear All
- [x] ISS-008 Drag & drop sıralamayı tam aktif etme
- [x] ISS-009 Duration/metadata okuma optimizasyonu (async, cache)

### P2 - Veri Kalıcılığı ve Kütüphane Yönetimi
- [x] ISS-010 Son çalan şarkı ve pozisyonu kaydetme/yükleme
- [x] ISS-011 Bookmark şeması versiyonlama ve migrate akışı
- [x] ISS-012 Klasör ekleme + duplicate filtreleme
- [x] ISS-013 Eksik dosya yönetimi (unavailable flag + cleanup)

### P3 - UX ve Erişilebilirlik
- [x] ISS-014 Arama ve gerçek zamanlı filtreleme
- [x] ISS-015 Context menu (Sil, Finder’da Göster, Bilgi)
- [x] ISS-016 Klavye kısayolları (Space, ⌘O, Delete, oklar)
- [x] ISS-017 Localization (TR/EN strings)
- [x] ISS-019 Menu bar erişimi
- [x] ISS-023 Player pencere boyutunu minimize etme (kompakt layout)
- [x] ISS-024 Playlist göster/gizle akışı (tek tık toggle)
- [x] ISS-025 Playlist pencere yeniden boyutlandırma (resizable)

### P4 - Gelişmiş Audio
- [x] ISS-020 Now Playing / Media Keys entegrasyonu
- [x] ISS-021 Gapless playback (AVAudioEngine)
- [x] ISS-022 Crossfade + EQ (AVAudioEngine)

---

## Sprint Planı

### Sprint 1 - Stabilite ve Doğruluk (1 hafta)
- [x] ISS-001
- [x] ISS-002
- [x] ISS-003
- [x] ISS-004

Kabul Kriterleri:
- [x] Playlist yüklemesinde güvenlik erişimi stabil ve hatasız
- [x] Son şarkı bitince UI doğru state’e geçiyor
- [x] Seek sırasında progress bar jitter yapmıyor
- [x] Hatalar kullanıcıya görünür şekilde iletiliyor

### Sprint 2 - Temel Özellikler + UI/UX (1-2 hafta)
- [x] ISS-005
- [x] ISS-006
- [x] ISS-007
- [x] ISS-008
- [x] ISS-009
- [x] ISS-014
- [x] ISS-015
- [x] ISS-016
- [x] ISS-017
- [x] ISS-018
- [x] ISS-019
- [x] ISS-023
- [x] ISS-024
- [x] ISS-025
- [x] ISS-026

Kabul Kriterleri:
- [x] Ses seviyesi kontrolü kalıcı ve doğru çalışıyor
- [x] Shuffle/Repeat modları UI + davranış olarak tutarlı
- [x] Şarkı silme ve liste temizleme stabil
- [x] Sıralama sonrası currentIndex doğru kalıyor
- [x] Büyük playlist’lerde metadata yükleme UI’yi dondurmuyor
- [x] UI/UX kriterleri birebir uygulanmış (max 4px radius, kompakt layout, minimal/temiz görünüm)
- [x] Arama filtreleri gerçek zamanlı ve performanslı
- [x] Context menu aksiyonları tam ve hatasız
- [x] Klavye kısayolları temel senaryoları kapsıyor
- [x] TR/EN metinler lokalize
- [x] Player penceresi minimum boyutta ve işlevlerini kaybetmiyor
- [x] Playlist penceresi ayrı, göster/gizle akışı çalışıyor
- [x] Playlist penceresi yeniden boyutlandırılabiliyor

### Sprint 3 - Kalıcılık ve Kütüphane (1-2 hafta)
- [x] ISS-010
- [x] ISS-011
- [x] ISS-012
- [x] ISS-013

Kabul Kriterleri:
- [x] Uygulama restart sonrası kaldığı yerden devam ediyor
- [x] Bookmark şeması geriye uyumlu
- [x] Klasör ekleme duplicate üretmiyor
- [x] Eksik dosyalar kullanıcıya net gösteriliyor ve temizlenebiliyor

### Sprint 4 - Gelişmiş Audio (2+ hafta, opsiyonel)
- [x] ISS-020
- [x] ISS-021
- [x] ISS-022

Kabul Kriterleri:
- [x] Media keys ve Now Playing entegrasyonu stabil
- [x] Gapless playback duyulabilir kesinti olmadan çalışıyor
- [x] Crossfade ve EQ ayarları beklendiği gibi uygulanıyor
