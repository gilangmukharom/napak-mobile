# tourvella-mobile

Aplikasi Tourvella — setiap perjalanan punya cerita.

Flutter · Riverpod · go_router · MapLibre GL · drift

## Menjalankan

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # kode drift
flutter run
```

Pastikan [`tourvella-api`](../tourvella-api) sudah jalan lebih dulu, dan sudah disemai
data contohnya (`npm run seed`). Emulator Android otomatis menunjuk ke
`10.0.2.2:3000` — jalan tembus menuju localhost komputernya.

**HP sungguhan tidak punya jalan tembus seperti itu.** Buka tunnel di sisi
backend, lalu pakai alamat yang dicetaknya:

```bash
# di tourvella-api
npm run tunnel

# lalu, dengan alamat yang tadi tercetak
flutter run --dart-define=TOURVELLA_API_URL=https://<acak>.trycloudflare.com/api
```

### Gaya peta

Bawaannya mengambil gaya pastel Tourvella dari backend (`GET /api/map/style`) —
bukan ditanam di aplikasi, supaya paletnya bisa diperbaiki tanpa menunggu orang
memperbarui aplikasinya, dan supaya kunci penyedia tile tidak ikut masuk APK.

Itu berarti backend perlu punya sumber tile (lihat README `tourvella-api`). Untuk
mengembangkan tanpa tile server sama sekali:

```bash
flutter run --dart-define=TOURVELLA_MAP_STYLE=https://demotiles.maplibre.org/style.json
```

## Susunan

```
lib/
  core/
    config/       alamat backend, jeda tracking, ambang jarak
    network/      klien HTTP + rotasi token otomatis
    storage/      token di Keystore/Keychain
    theme/        tourvella_colors (palet) + tourvella_motion (durasi & kurva)
    widgets/      shell tab, pressable, skeleton, angka berjalan
    router/       go_router + pengalihan sesi
    providers.dart
  features/
    splash/       layar pembuka: jejak yang menggambar dirinya
    auth/         masuk dengan OTP, profil, hapus akun
    trips/        beranda feed, detail, peta rute, pratinjau rute
    recording/    mulai & jalannya perekaman, antrean offline, sinkron
    groups/       Trip Bareng: anggota, undangan, posisi langsung
    render/       minta video, pratinjau, bagikan
    recap/        Tourvella Recap tahunan
```

## Gerak

Gerak punya palet, sama seperti warna. Semua durasi dan kurva berasal dari
[`lib/core/theme/tourvella_motion.dart`](lib/core/theme/tourvella_motion.dart) — kalau
tiap layar memilih sendiri, aplikasinya terasa gelisah: satu tombol memantul,
tombol sebelahnya meluncur, dan tidak ada yang terasa satu keluarga.

Satu pertimbangan mendasarinya: gerak di Tourvella harus terasa seperti sesuatu
yang **mengalir**, bukan yang **melompat**. Perjalanan tidak melompat.

| | |
|---|---|
| `kilat` 120 ms | umpan balik sentuhan, lebih cepat dari yang disadari mata |
| `cepat` 220 ms | perubahan kecil dalam satu layar |
| `sedang` 380 ms | bawaan, termasuk perpindahan halaman |
| `lambat` 520 ms | yang perlu diikuti mata |
| `mengalir` | kurva utama: mulai tegas, berhenti lembut |
| `memantul` | dipakai hemat, hanya untuk momen yang pantas dirayakan |

Tiga hal yang paling menentukan rasa "enak dipakai":

- **`TourvellaPressable`** membungkus apa pun yang bisa ditekan. Saat kartu
  menyusut sedikit di bawah jari lalu kembali, otak membacanya sebagai benda,
  bukan gambar. Turunnya lebih cepat daripada naiknya — benda nyata memang
  begitu.
- **`TourvellaSkeleton`** menggantikan lingkaran berputar. Kerangka memberi tahu
  bentuk apa yang sedang datang, jadi halamannya tidak melompat saat isinya
  masuk. Lingkaran berputar tidak memberi tahu apa-apa selain "tunggu".
- **`MunculBertahap`** membuat daftar muncul satu per satu. Serentak terasa
  seperti halaman yang di-refresh; bertahap terasa seperti sesuatu yang
  sedang disusun.

## Tata letak

Empat tab di bawah dengan tombol rekam di tengah, meminjam bentuk yang ibu
jari orang sudah hafal. Menaruh "Mulai merekam" di pojok kanan atas berarti
meminta orang memindahkan genggaman di atas motor.

Yang dipinjam hanya mekanikanya — warnanya tetap Tourvella: latar nyaris putih,
aksen biru pastel, tanpa satu pun titik merah pemberitahuan.

Beranda disusun seperti feed: **bentuk rute tampil besar dan lebih dulu**,
angka jarak dan tanggal menyusul sebagai keterangan. Yang dilihat orang di
sana bukan data, melainkan kenangan.

Pratinjau rute di kartu digambar dengan `CustomPaint`, bukan MapLibre.
Sepuluh kartu berarti sepuluh konteks GL, tile yang diunduh, dan memorinya
masing-masing — beranda akan tersendat hanya untuk digulir. Di ukuran
sekecil itu yang dibutuhkan mata memang cuma bentuknya.

## Warna

Seluruh warna berasal dari
[`lib/core/theme/tourvella_colors.dart`](lib/core/theme/tourvella_colors.dart).
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

## Menjalankan di iOS

Kompilasi iOS butuh Xcode, dan Xcode hanya ada di macOS — Flutter di Windows
bahkan tidak menampilkan `ios` maupun `ipa` di daftar target `flutter build`.
Jalan keluarnya: runner macOS di GitHub Actions membuat IPA-nya,
[Sideloadly](https://sideloadly.io) di Windows yang memasangnya.

### Sekali jalan

```
1. di tourvella-api:  npm run tunnel          → salin URL yang tercetak
2. di GitHub:     Actions ▸ Build iOS ▸ Run workflow
                  tempel URL tadi ke kolom "api_url"
3. tunggu ±10 menit, unduh artefak Tourvella-unsigned-ipa
4. buka Sideloadly, sambungkan iPhone, jatuhkan IPA-nya, masuk Apple ID
5. di iPhone: Pengaturan ▸ Umum ▸ VPN & Manajemen Perangkat ▸ percayai
```

Workflow-nya membangun **tanpa tanda tangan**, dan itu disengaja: Sideloadly
sudah mengurus sertifikat dan provisioning profile-nya sendiri lewat Apple ID,
jadi tidak ada satu pun kunci pribadi yang perlu dititipkan ke GitHub Secrets.
Kunci penandatangan adalah benda yang paling tidak enak kalau sampai bocor,
dan cara paling aman menjaganya adalah tidak menaruhnya di mana-mana.

### Yang perlu diketahui

- **Sideloadly butuh iTunes dan iCloud versi dari apple.com**, bukan yang dari
  Microsoft Store — yang dari Store tidak membawa driver perangkatnya.
- **Apple ID gratis: aplikasinya berhenti berlaku setelah 7 hari**, dan
  maksimal tiga aplikasi sideload sekaligus. Pasang ulang dengan cara yang
  sama untuk memperpanjang.
- **Alamat backend tertanam di dalam IPA.** URL tunnel berganti tiap kali
  `npm run tunnel` dijalankan ulang, jadi tunnel-nya harus tetap hidup selama
  kamu mencoba. Kalau mati, jalankan lagi dan bangun ulang dengan URL barunya.
- Perekaman latar belakang (`UIBackgroundModes: location`) hanya butuh kunci
  di Info.plist, bukan entitlement berbayar — jadi tetap jalan dengan Apple ID
  gratis.

### Yang sudah disiapkan dari sisi proyek

| Hal | Keadaan |
|---|---|
| `NSLocationWhenInUseUsageDescription` | terisi, Bahasa Indonesia |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | terisi |
| `NSPhotoLibraryAddUsageDescription` | terisi |
| `UIBackgroundModes` | `location`, `fetch` |
| Deployment target | 13.0 — sesuai syarat MapLibre |
| Bundle ID | `id.tourvella.app` |
| App Transport Security | tanpa `NSAllowsArbitraryLoads` |

Teks izinnya muncul apa adanya di dialog iOS, jadi ditulis dengan bahasa yang
sama dengan isi aplikasi: menjelaskan apa gunanya, bukan sekadar meminta.

Workflow-nya memeriksa ketiga teks izin itu **sebelum** membangun. iOS menutup
paksa aplikasi yang meminta izin tanpa teks penjelasannya, dan kegagalan
seperti itu jauh lebih enak ketahuan di CI daripada di HP.

### Kalau punya akses Mac

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
cd ios && pod install && cd ..
flutter run --dart-define=TOURVELLA_API_URL=https://<acak>.trycloudflare.com/api
```

Simulator iOS tidak butuh Apple ID, tapi tidak punya GPS sungguhan —
perekaman harus disimulasikan lewat Debug ▸ Location di Simulator.

## Android lewat Actions

`Actions ▸ Build Android ▸ Run workflow`, isi `api_url` yang sama. Hasilnya
APK rilis yang tinggal dipindah ke HP.

## Catatan lingkungan

**SDK Flutter di path bersepasi.** Kalau SDK terpasang di `D:\Program Files\flutter`,
`flutter test` gagal dengan `'D:\Program' is not recognized` — hook native-assets
milik paket `objective_c` memanggil compiler Dart tanpa tanda kutip. Pindahkan
SDK ke path tanpa spasi (`D:\flutter`) untuk menyelesaikannya.

**`kotlin.incremental=false`** di `android/gradle.properties` bukan pilihan gaya:
tanpanya, Kotlin 2.3 + AGP 9 gagal menutup cache incremental di Windows dan
menggagalkan `compileDebugKotlin` milik plugin pihak ketiga.

**Sisi iOS belum pernah dikompilasi.** Konfigurasinya sudah disiapkan dan
diperiksa, tapi kompilasi sungguhannya menunggu mesin macOS. Wajar kalau masih
ada yang perlu dirapikan saat `pod install` pertama.

## Yang belum dikerjakan

- Lampiran foto pada titik singgah — backend baru menyiapkan bentuk kontraknya
- Pratinjau video di dalam aplikasi; sekarang langsung ke lembar berbagi
- Notifikasi saat render selesai kalau aplikasinya sedang ditutup
