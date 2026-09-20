# napak-mobile

Aplikasi Napak — setiap perjalanan meninggalkan jejak.

Flutter · Riverpod · go_router · MapLibre GL · drift

## Menjalankan

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # kode drift
flutter run
```

Pastikan [`napak-api`](../napak-api) sudah jalan lebih dulu. Emulator Android
otomatis menunjuk ke `10.0.2.2:3000` (jalan tembus menuju localhost host).
Untuk perangkat asli:

```bash
flutter run --dart-define=NAPAK_API_URL=http://192.168.1.10:3000/api
```

### Gaya peta

Bawaannya mengambil gaya pastel Napak dari backend (`GET /api/map/style`) —
bukan ditanam di aplikasi, supaya paletnya bisa diperbaiki tanpa menunggu orang
memperbarui aplikasinya, dan supaya kunci penyedia tile tidak ikut masuk APK.

Itu berarti backend perlu punya sumber tile (lihat README `napak-api`). Untuk
mengembangkan tanpa tile server sama sekali:

```bash
flutter run --dart-define=NAPAK_MAP_STYLE=https://demotiles.maplibre.org/style.json
```

## Susunan

```
lib/
  core/
    config/       alamat backend, jeda tracking, ambang jarak
    network/      klien HTTP + rotasi token otomatis
    storage/      token di Keystore/Keychain
    theme/        palet dan tema — satu-satunya sumber warna
    router/       go_router + pengalihan sesi
    providers.dart
  features/
    auth/         masuk dengan OTP, pengaturan, hapus akun
    trips/        daftar, detail, peta rute
    recording/    perekaman GPS, antrean offline (drift), sinkron
    groups/       Trip Bareng: anggota, undangan, posisi langsung
    render/       minta video animasi rute lalu bagikan
    recap/        Napak Tilas tahunan
```

## Warna

Seluruh warna berasal dari
[`lib/core/theme/napak_colors.dart`](lib/core/theme/napak_colors.dart).
Kalau sebuah komponen butuh warna yang belum ada, warnanya ditambahkan ke file
itu dulu — bukan dituliskan langsung di widget. Begitu satu `Color(0xFF...)`
lepas berkeliaran di halaman, ketenangan paletnya mulai bocor.

| Token | Hex | Dipakai untuk |
|---|---|---|
| `primary` | `#A8C8E8` | tombol utama, elemen aktif, garis rute |
| `deepAccent` | `#5C87B0` | teks penting, ikon aktif, border |
| `softSky` | `#D6E8F5` | background kartu |
| `base` | `#F5F9FC` | background aplikasi |
| `warmNeutral` | `#F0E9DE` | aksen hangat, sesekali saja |
| `textPrimary` | `#2E3B4E` | teks utama |

Heading memakai Plus Jakarta Sans — buatan perancang Indonesia, dan itu bukan
kebetulan. Body memakai Inter.

## Tiga hal yang dijaga

**Baterai.** Aliran lokasi disaring oleh jarak (25 m), bukan hanya waktu —
berdiam di lampu merah tidak menghasilkan puluhan titik kembar. Yang dipakai
adalah stream milik sistem operasi, bukan timer yang membangunkan GPS sendiri
setiap beberapa detik.

**Jejak tidak boleh hilang.** Setiap titik ditulis ke database lokal (drift)
lebih dulu, baru dicoba dikirim. Sinyal putus di jalur Sumatra bukan alasan
kehilangan cerita. Setiap titik membawa `clientId` buatan perangkat, jadi
sinkron ulang tidak menggandakan jejak.

**Peta tidak digambar ulang.** `PetaRute` dibuat sekali; titik baru ditambahkan
dengan memperbarui isi sumber GeoJSON-nya lewat `PetaRuteController.tambahTitik`.
Tidak ada `setState`, tidak ada `MapLibreMap` yang dibangun ulang tiap 30 detik.
Garis rutenya memakai `line-gradient` di atas sumber ber-`lineMetrics`, memberi
gradasi `#5C87B0` → `#A8C8E8`: jejak yang mengalir, bukan garis datar. Hal yang
sama berlaku untuk penanda posisi langsung di Trip Bareng — rombongan yang ramai
berarti pembaruan tiap beberapa detik.

## Trip Bareng

Rute tiap anggota digambar dengan warnanya sendiri, dan warnanya **datang dari
server** — bukan diundi di HP — supaya biru yang kamu lihat untuk si A sama
dengan yang dilihat semua orang.

Berbagi posisi mati secara bawaan dan izinnya melekat pada satu sesi perjalanan,
bukan setelan global yang menyala diam-diam di perjalanan berikutnya. Yang tidak
menyalakan tetap kelihatan sebagai anggota dan rutenya tetap tergambar;
posisinya saja yang tidak.

Sambungan WebSocket dibuka saat layar Trip Bareng dibuka dan ditutup saat
ditinggalkan (`autoDispose`). Socket yang menganggur sepanjang aplikasi hidup
berarti radio HP menyala tanpa alasan. Posisi yang dikirim diambil dari
perekaman yang sedang berjalan, jadi tidak ada pembacaan GPS tambahan.

## Perintah

```bash
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs
flutter build apk --debug
```

## Catatan lingkungan

**SDK Flutter di path bersepasi.** Kalau SDK terpasang di `D:\Program Files\flutter`,
`flutter test` gagal dengan `'D:\Program' is not recognized` — hook native-assets
milik paket `objective_c` memanggil compiler Dart tanpa tanda kutip. Pindahkan
SDK ke path tanpa spasi (`D:\flutter`) untuk menyelesaikannya.

**`kotlin.incremental=false`** di `android/gradle.properties` bukan pilihan gaya:
tanpanya, Kotlin 2.3 + AGP 9 gagal menutup cache incremental di Windows dan
menggagalkan `compileDebugKotlin` milik plugin pihak ketiga.

## Yang belum dikerjakan

- Lampiran foto pada titik singgah — backend baru menyiapkan bentuk kontraknya
- Pratinjau video di dalam aplikasi; sekarang langsung ke lembar berbagi
- Notifikasi saat render selesai kalau aplikasinya sedang ditutup
