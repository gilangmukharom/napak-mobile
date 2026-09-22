// Logo Tourvella: sumber SVG + seluruh ikon aplikasi Android/iOS.
//
// Jalankan dari tourvella-api (yang punya sharp):
//   node ../tourvella-mobile/branding/buat-logo.mjs
//
// Konsep: huruf T. Palangnya horizon, batangnya jalan berkelok yang menyempit
// ke arah horizon (perspektif — jalan yang datang ke arah kita), dengan marka
// putus-putus di tengah. Matahari tujuan terbit di belakang horizon, punggungan
// rimba di bawahnya. Warna: malam, ember, rimba (+ emberRedup untuk mataharinya).
//
// Geometrinya sama persis dengan `LogoTourvella`
// (lib/core/widgets/tourvella_logo.dart). Ubah di satu tempat, ubah juga di
// tempat lain.
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(join(process.cwd(), 'package.json'));
const sharp = require('sharp');

const di = dirname(fileURLToPath(import.meta.url));
const akar = join(di, '..');

const W = {
  malam: '#17202B',
  malamNaik: '#212C3A',
  ember: '#D98A4E',
  emberRedup: '#E8C4A0',
  rimba: '#2C5F52',
  base: '#F5F9FC',
};

// --- Geometri (kotak 1024) ---
// Garis tengah jalan: satu kubik S dari bawah kanvas ke horizon.
const P0 = [540, 1080];
const P1 = [446, 872];
const P2 = [680, 600];
const P3 = [512, 336];
const LEBAR_BAWAH = 210;
const LEBAR_ATAS = 64;
const HORIZON_Y = 330;
const PALANG = { x1: 244, x2: 780, tebal: 96 };
const MATAHARI = { cx: 512, cy: 238, r: 64 };

function titikKubik(t) {
  const u = 1 - t;
  const a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t;
  return [
    a * P0[0] + b * P1[0] + c * P2[0] + d * P3[0],
    a * P0[1] + b * P1[1] + c * P2[1] + d * P3[1],
  ];
}

function turunanKubik(t) {
  const u = 1 - t;
  return [
    3 * u * u * (P1[0] - P0[0]) + 6 * u * t * (P2[0] - P1[0]) + 3 * t * t * (P3[0] - P2[0]),
    3 * u * u * (P1[1] - P0[1]) + 6 * u * t * (P2[1] - P1[1]) + 3 * t * t * (P3[1] - P2[1]),
  ];
}

/** Badan jalan sebagai poligon: tepi kiri naik, tepi kanan turun. */
function badanJalan(n = 64) {
  const kiri = [], kanan = [];
  for (let i = 0; i <= n; i++) {
    const t = i / n;
    const [x, y] = titikKubik(t);
    const [dx, dy] = turunanKubik(t);
    const pj = Math.hypot(dx, dy) || 1;
    const nx = -dy / pj, ny = dx / pj;
    // Menyempit tidak linear — lebih cepat di kejauhan, seperti mata melihat.
    const w = (LEBAR_BAWAH - (LEBAR_BAWAH - LEBAR_ATAS) * Math.pow(t, 0.8)) / 2;
    kiri.push([x + nx * w, y + ny * w]);
    kanan.push([x - nx * w, y - ny * w]);
  }
  const semua = [...kiri, ...kanan.reverse()];
  return 'M ' + semua.map(([x, y]) => `${x.toFixed(1)} ${y.toFixed(1)}`).join(' L ') + ' Z';
}

const GARIS_TENGAH = `M ${P0.join(' ')} C ${P1.join(' ')}, ${P2.join(' ')}, ${P3.join(' ')}`;
const BUKIT_JAUH = 'M 0 1024 L 0 690 C 150 632, 270 696, 390 660 C 520 620, 650 688, 790 646 C 890 618, 966 634, 1024 624 L 1024 1024 Z';
const BUKIT_DEKAT = 'M 0 1024 L 0 820 C 170 770, 300 836, 460 806 C 640 772, 800 846, 1024 796 L 1024 1024 Z';

function tanda({ latar, jalan, marka, matahari, bukitJauh, bukitDekat, kontur }) {
  return `
    ${latar ? `<rect width="1024" height="1024" fill="${latar}"/>` : ''}
    ${kontur ? `
    <g fill="none" stroke="${W.malamNaik}" stroke-width="7">
      <path d="M -40 150 C 200 96, 420 196, 640 140 C 820 96, 960 130, 1080 104"/>
      <path d="M -40 470 C 180 430, 330 520, 520 486 C 700 454, 880 520, 1080 480"/>
    </g>` : ''}
    <circle cx="${MATAHARI.cx}" cy="${MATAHARI.cy}" r="${MATAHARI.r}" fill="${matahari}"/>
    ${bukitJauh ? `<path d="${BUKIT_JAUH}" fill="${bukitJauh}" opacity="0.55"/>` : ''}
    ${bukitDekat ? `<path d="${BUKIT_DEKAT}" fill="${bukitDekat}"/>` : ''}
    <path d="${badanJalan()}" fill="${jalan}" stroke="${jalan}" stroke-width="6" stroke-linejoin="round"/>
    <path d="${GARIS_TENGAH}" fill="none" stroke="${marka}" stroke-width="13" stroke-linecap="round" stroke-dasharray="40 44"/>
    <line x1="${PALANG.x1}" y1="${HORIZON_Y}" x2="${PALANG.x2}" y2="${HORIZON_Y}" stroke="${jalan}" stroke-width="${PALANG.tebal}" stroke-linecap="round"/>
  `;
}

const svg = (isi, bulat = 0) => `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  ${bulat ? `<defs><clipPath id="k"><rect width="1024" height="1024" rx="${bulat}"/></clipPath></defs><g clip-path="url(#k)">` : '<g>'}
  ${isi}
  </g>
</svg>`;

const penuh = {
  latar: W.malam, jalan: W.ember, marka: W.malam, matahari: W.emberRedup,
  bukitJauh: W.rimba, bukitDekat: W.rimba, kontur: true,
};
// Ikon iOS: kanvas penuh; iOS memasang topeng sudutnya sendiri.
const ikon = svg(tanda(penuh));
// Android (ikon lama, belum adaptive): sudutnya dibulatkan sendiri.
const ikonAndroid = svg(tanda(penuh), 230);
// Tanda tanpa latar — di atas kanvas gelap dan di atas latar terang.
const tandaGelap = svg(tanda({ jalan: W.ember, marka: W.malam, matahari: W.emberRedup, bukitDekat: W.rimba }));
const tandaTerang = svg(tanda({ jalan: W.malam, marka: W.base, matahari: W.ember, bukitDekat: W.rimba }));

mkdirSync(join(di, 'hasil'), { recursive: true });
writeFileSync(join(di, 'tourvella-ikon.svg'), ikon);
writeFileSync(join(di, 'tourvella-tanda-gelap.svg'), tandaGelap);
writeFileSync(join(di, 'tourvella-tanda-terang.svg'), tandaTerang);

const png = (s, n, opsi = {}) => {
  let p = sharp(Buffer.from(s), { density: 300 }).resize(n, n);
  if (opsi.tanpaAlfa) p = p.flatten({ background: W.malam });
  return p.png();
};

// Pratinjau untuk dilihat dengan mata, termasuk ukuran terkecil.
await png(ikon, 1024).toFile(join(di, 'hasil', 'ikon-1024.png'));
await png(tandaTerang, 512).toFile(join(di, 'hasil', 'tanda-terang-512.png'));
await png(ikonAndroid, 48).toFile(join(di, 'hasil', 'ikon-48.png'));

const android = { mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 };
for (const [nama, n] of Object.entries(android)) {
  await png(ikonAndroid, n).toFile(
    join(akar, `android/app/src/main/res/mipmap-${nama}/ic_launcher.png`),
  );
}

// iOS: semua ukuran di Contents.json. App Store menolak ikon beralfa.
const folderIos = join(akar, 'ios/Runner/Assets.xcassets/AppIcon.appiconset');
const isi = JSON.parse(readFileSync(join(folderIos, 'Contents.json'), 'utf8'));
for (const g of isi.images) {
  if (!g.filename) continue;
  const n = Math.round(parseFloat(g.size) * parseInt(g.scale));
  await png(ikon, n, { tanpaAlfa: true }).toFile(join(folderIos, g.filename));
}

console.log('logo & ikon Tourvella selesai');
