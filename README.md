# Wored

SwiftUI ve AppKit ile geliştirilmiş, macOS için sade ve kompakt bir müzikçalar.

![Wored ekran görüntüsü](assets/wored-screen.png)

## İndirme ve Kurulum

[Son sürümü GitHub Releases üzerinden indirin](https://github.com/tercan/wored/releases/latest).

- **DMG:** Dosyayı açın ve Wored uygulamasını Applications bağlantısına sürükleyin.
- **ZIP:** Arşivi açın ve Wored.app dosyasını Uygulamalar klasörüne taşıyın.
- Hazır paketler Apple Silicon (arm64) ve macOS 26.2 veya üzeri içindir.
- Paketler ad-hoc imzalıdır; Developer ID imzası ve Apple notarization içermez. macOS ilk açılışta güvenlik uyarısı gösterebilir.
- İndirme bütünlüğünü sürümdeki SHA256SUMS.txt dosyasıyla doğrulayabilirsiniz.

## Özellikler

- Keskin köşeli, düz renkli ve kompakt arayüz
- Player'a bağlı, yüksekliği ayarlanabilir çalma listesi
- Dosya/klasör sürükleyerek ekleme, liste sıralama ve klasörleri yeniden tarama
- Birden fazla çalma listesi, arama, Favoriler ve Geçmiş
- Parça bilgisi; MP3/ID3 metin ve kapak düzenleme
- Menü çubuğundan kontrol ve pencereler gizliyken oynatma
- Açık/koyu/sistem teması, EQ, crossfade ve klavye kısayolları
- Yardımcı panel konumlarını ve etiket paneli yüksekliğini hatırlama
- Aynı anda tek uygulama kopyası çalıştırma

## Kullanım

- Space: oynat/duraklat; metin alanlarında normal boşluk girişi
- Cmd+L: çalma listesini göster/gizle
- Cmd+O: dosya veya klasör ekle
- Cmd+F: çalma listesinde arama
- Cmd+,: ayarlar
- Cmd+W veya Ctrl+W: odaktaki ayarlar/etiket panelini kapat
- Parçaya çift tıklama: oynat; kalp simgesi: favori durumunu değiştir
- Player üzerindeki X: pencereleri gizle; Cmd+Q: uygulamadan çık

## Kaynaktan Derleme

Xcode 26.4 veya üzeri gerekir. wored.xcodeproj dosyasını açıp Wored şemasını derleyin.

```sh
bash scripts/test.sh
bash scripts/package-release.sh 0.7.0
```

Güncel uygulama dist/Wored.app, sürüm paketleri dist/releases/0.7.0 altında oluşturulur.

## Varsayılan Yayın Politikası

Her sürüm güncellemesinde uygulamanın MARKETING_VERSION/CURRENT_PROJECT_VERSION değerleri, README sürümü ve CHANGELOG birlikte güncellenir. Yalnızca commit veya etiket oluşturmak yayın için yeterli değildir: GitHub Releases kaydı, indirilebilir ZIP/DMG paketleri ve SHA-256 özeti de yayımlanmalıdır.

1. Sürüm bilgilerini güncelleyin; testleri ve Release paketlemesini çalıştırın.
2. Kaynak değişikliklerini commit edin.
3. Aynı commit üzerinde vX.Y.Z biçiminde açıklamalı etiket oluşturup dal ve etiketi gönderin.
4. GitHub Actions release akışı testleri/derlemeyi yeniden çalıştırır; Release kaydını ve indirme dosyalarını yayımlar.
5. Akışın başarılı olduğunu, dosyaların indirilebildiğini ve yerel dist/Wored.app çıktısının güncel olduğunu doğrulayın.

Yerel paketleri elle yayımlamak veya aynı etiketin dosyalarını yenilemek için:

```sh
GH_REPO=tercan/wored bash scripts/publish-release.sh 0.7.0
```

Bu komut mevcut etiketi ve paket sürümünü doğrular; paketleme için önce package-release.sh çalıştırılmalıdır. Etiketler başka commit'lere taşınmaz. GitHub workflow_dispatch ile mevcut bir etiketi yeniden paketleyip yayımlamak da mümkündür.

## Sürüm

0.7.0
