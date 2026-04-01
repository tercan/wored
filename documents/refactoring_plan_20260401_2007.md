# Wored v0.3.0 - Mimari İyileştirme Planı

## Mevcut Durum

| Dosya | Satır | Sorumluluk |
| --- | ---: | --- |
| AudioPlayerViewModel.swift | 1604 | Model'ler, Enum'lar, ViewModel (audio, playlist, favorites, history, persistence) |
| ContentView.swift | 1296 | PlayerView, PlaylistView, SettingsPanel, SquareSlider, MarqueeText, ScrollableView vb. |
| woredApp.swift | 523 | App entry, Color palette, WindowManager, WindowAccessor'lar, MenuBarView |
| Localization.swift | 138 | Lokalizasyon |
| **Toplam** | **3561** | |

## Refactoring Stratejisi

**Temel Kural:** Arayüzde (UI) sıfır değişiklik. Sadece dosya bölme ve import düzenleme.

### Adım 1: Model dosyalarını ayır

`Models/` klasörü oluştur ve AudioPlayerViewModel.swift'teki struct/enum tanımlarını taşı.

| Yeni Dosya | İçerik | Kaynak Satırlar |
| --- | --- | --- |
| Models/Song.swift | `Song`, `SavedSong`, `SavedPlaylist`, `PlayerError`, `CachedMetadata` | 9-133 |
| Models/Enums.swift | `RepeatMode`, `EQPreset`, `AppTheme`, `AppLanguage` | 39-112 |

### Adım 2: View dosyalarını ayır

ContentView.swift'teki bağımsız bileşenleri ayrı dosyalara taşı.

| Yeni Dosya | İçerik | Kaynak Satırlar |
| --- | --- | --- |
| Views/PlayerView.swift | `PlayerView` struct | 6-288 |
| Views/PlaylistView.swift | `PlaylistView`, `SongDropDelegate` | 290-600 |
| Views/SettingsPanelView.swift | `SettingsPanelView`, `SectionHeader`, `SettingsRow`, `InfoPanelController`, `InfoPanelButton` | 684-1015 |
| Views/Components/SquareSlider.swift | `TrackingSlider`, `SquareSliderCell`, `SquareSlider` | 1018-1139 |
| Views/Components/MarqueeText.swift | `MarqueeWidthPreferenceKey`, `MarqueeText` | 1142-1222 |
| Views/Components/TooltippedView.swift | `TooltipHostingView`, `TooltippedView` | 648-681 |
| Views/Components/ScrollableView.swift | `ScrollableView`, `ScrollableHostingView`, `PopoverWindowAccessor` | 1224-1295 |
| Views/ContentView.swift | `ContentView` (legacy uyumluluk), `InfoRow`, `InfoLinkRow` | 602-646 |

### Adım 3: woredApp.swift'i ayır

| Yeni Dosya | İçerik | Kaynak Satırlar |
| --- | --- | --- |
| Extensions/Color+App.swift | Color extension, NSColor extension, hex init | 12-86 |
| App/WindowManager.swift | `WindowManager` class | 88-370 |
| App/WindowAccessors.swift | `PlayerWindowAccessor`, `PlaylistWindowAccessor` | 402-473 |
| Views/MenuBarView.swift | `MenuBarView` | 475-523 |

### Adım 4: woredApp.swift temizle

woredApp.swift'te sadece `@main struct woredApp: App` kalacak (satır 372-400).

## Dosya Yapısı (Hedef)

```
wored/
├── App/
│   ├── woredApp.swift          (sadece App entry point)
│   ├── WindowManager.swift     (pencere yönetimi)
│   └── WindowAccessors.swift   (NSViewRepresentable'lar)
├── Models/
│   ├── Song.swift              (Song, SavedSong, SavedPlaylist, PlayerError)
│   └── Enums.swift             (RepeatMode, EQPreset, AppTheme, AppLanguage)
├── ViewModels/
│   └── AudioPlayerViewModel.swift (sadece ViewModel logic)
├── Views/
│   ├── PlayerView.swift
│   ├── PlaylistView.swift
│   ├── SettingsPanelView.swift
│   ├── MenuBarView.swift
│   ├── ContentView.swift       (legacy uyumluluk)
│   └── Components/
│       ├── SquareSlider.swift
│       ├── MarqueeText.swift
│       ├── TooltippedView.swift
│       └── ScrollableView.swift
├── Extensions/
│   └── Color+App.swift
├── Localization/
│   └── Localization.swift
└── Assets.xcassets/
```

## Uygulama Sırası

1. Model dosyalarını oluştur (`Song.swift`, `Enums.swift`)
2. Extension dosyası oluştur (`Color+App.swift`)
3. WindowManager ve WindowAccessors dosyalarını oluştur
4. View bileşenlerini oluştur (Components/ altındakiler)
5. Ana view dosyalarını oluştur (PlayerView, PlaylistView, SettingsPanel, MenuBar)
6. Orijinal dosyaları temizle (taşınan kodu kaldır)
7. Xcode project dosyasını güncelle
8. Build ve test

## Riskler

- Xcode `.pbxproj` dosyasına yeni dosyaları eklemek gerekiyor
- `private` erişim belirleyicileri dosya değiştiğinde `internal` veya dosya-seviyesi erişime dönüştürülmeli
- Circular dependency riski yok (tek yönlü bağımlılık: View → ViewModel → Model)
