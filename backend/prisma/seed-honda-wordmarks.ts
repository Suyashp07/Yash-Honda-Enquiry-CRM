import { PrismaClient } from '@prisma/client';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const sharp = require('sharp');

function escXml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function buildWordmarkSvg(name: string, code: string): string {
  const n = name.trim();
  const lower = n.toLowerCase();

  // 1. ADV 160 — angular italic speed-stencil matching official ADV160 brochure
  if (lower.includes('adv')) {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 160" width="900" height="160">
      <g transform="skewX(-18) translate(48, 0)">
        <text x="0" y="118" font-family="'Arial Black', 'Impact', sans-serif" font-size="112" font-weight="900" letter-spacing="4" fill="#0F172A">ADV</text>
        <text x="295" y="118" font-family="'Arial Black', 'Impact', sans-serif" font-size="82" font-weight="900" letter-spacing="2" fill="#CC0000">160</text>
      </g>
      <path d="M18 134 L465 134 L452 142 L8 142 Z" fill="#CC0000"/>
    </svg>`;
  }

  // 2. Shine series — dynamic italicized sport-sans + bold red/dark numerals
  if (lower.includes('shine')) {
    const parts = n.replace(/shine/i, '').trim();
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 160" width="900" height="160">
      <g transform="skewX(-14) translate(36, 0)">
        <text x="0" y="106" font-family="'Trebuchet MS', 'Arial Black', sans-serif" font-size="94" font-weight="900" font-style="italic" letter-spacing="-1" fill="#0F172A">Shine</text>
        <text x="278" y="106" font-family="'Arial Black', sans-serif" font-size="64" font-weight="900" font-style="italic" letter-spacing="1" fill="#CC0000">${escXml(parts)}</text>
      </g>
      <path d="M20 124 Q 210 112 430 124 L 418 133 Q 210 122 12 133 Z" fill="#CC0000"/>
    </svg>`;
  }

  // 3. Activa series — sleek modern italic + crimson accent bar
  if (lower.includes('activa')) {
    const parts = n.replace(/activa/i, '').trim();
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 160" width="900" height="160">
      <g transform="skewX(-12) translate(32, 0)">
        <text x="0" y="102" font-family="'Helvetica Neue', 'Arial', sans-serif" font-size="88" font-weight="800" font-style="italic" letter-spacing="1" fill="#0F172A">Activa</text>
        <text x="285" y="102" font-family="'Helvetica Neue', 'Arial', sans-serif" font-size="56" font-weight="900" fill="#CC0000">${escXml(parts)}</text>
      </g>
      <rect x="20" y="122" width="120" height="7" rx="3.5" fill="#CC0000"/>
      <rect x="148" y="122" width="38" height="7" rx="3.5" fill="#0F172A"/>
    </svg>`;
  }

  // 4. Dio series — bold youthful street-sport tilt
  if (lower.includes('dio')) {
    const parts = n.replace(/dio/i, '').trim();
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 160" width="900" height="160">
      <g transform="skewX(-16) translate(36, 0)">
        <text x="0" y="108" font-family="'Arial Black', 'Impact', sans-serif" font-size="102" font-weight="900" font-style="italic" letter-spacing="2" fill="#CC0000">Dio</text>
        <text x="195" y="108" font-family="'Arial Black', sans-serif" font-size="66" font-weight="900" fill="#0F172A">${escXml(parts)}</text>
      </g>
      <polygon points="16,126 320,126 306,136 10,136" fill="#0F172A"/>
    </svg>`;
  }

  // 5. SP 125 / SP 160 — sharp racing stencil
  if (lower.startsWith('sp ') || lower === 'sp125' || lower === 'sp160') {
    const parts = n.replace(/sp/i, '').trim();
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 160" width="900" height="160">
      <g transform="skewX(-18) translate(42, 0)">
        <text x="0" y="114" font-family="'Arial Black', 'Impact', sans-serif" font-size="108" font-weight="900" letter-spacing="3" fill="#CC0000">SP</text>
        <text x="172" y="114" font-family="'Arial Black', sans-serif" font-size="88" font-weight="900" letter-spacing="2" fill="#0F172A">${escXml(parts)}</text>
      </g>
      <path d="M18 130 L380 130 L370 138 L10 138 Z" fill="#CC0000"/>
    </svg>`;
  }

  // 6. Hornet series — aggressive geometric uppercase
  if (lower.includes('hornet')) {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 160" width="900" height="160">
      <g transform="skewX(-15) translate(38, 0)">
        <text x="0" y="106" font-family="'Arial Black', 'Impact', sans-serif" font-size="74" font-weight="900" letter-spacing="3" fill="#0F172A">${escXml(n.toUpperCase())}</text>
      </g>
      <polygon points="18,124 440,124 424,134 10,134" fill="#CC0000"/>
    </svg>`;
  }

  // 7. Heritage CB350 / H'ness / CB350C / CB350RS — classic BigWing neo-retro serif
  if (lower.includes('cb350') || lower.includes('h\'ness') || lower.includes('rebel')) {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 160" width="900" height="160">
      <text x="16" y="102" font-family="'Georgia', 'Times New Roman', serif" font-size="76" font-weight="700" letter-spacing="1.5" fill="#0F172A">${escXml(n)}</text>
      <line x1="18" y1="122" x2="260" y2="122" stroke="#CC0000" stroke-width="6" stroke-linecap="round"/>
      <line x1="272" y1="122" x2="340" y2="122" stroke="#94A3B8" stroke-width="6" stroke-linecap="round"/>
    </svg>`;
  }

  // 8. Adventure / BigWing Tour & Supersport (NX, XR, Transalp, CB500, CB1000, CBR, Gold Wing)
  if (
    lower.includes('nx') ||
    lower.includes('xr') ||
    lower.includes('transalp') ||
    lower.includes('cbr') ||
    lower.includes('gold wing') ||
    lower.includes('cb500')
  ) {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 160" width="900" height="160">
      <g transform="skewX(-12) translate(32, 0)">
        <text x="0" y="104" font-family="'Arial Black', 'Impact', sans-serif" font-size="70" font-weight="900" letter-spacing="2.5" fill="#0F172A">${escXml(n.toUpperCase())}</text>
      </g>
      <rect x="18" y="122" width="180" height="6" fill="#CC0000"/>
      <rect x="206" y="122" width="60" height="6" fill="#0F172A"/>
    </svg>`;
  }

  // 9. Default (Unicorn, Livo, CB300R, etc.) — clean bold Honda italic
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 160" width="900" height="160">
    <g transform="skewX(-10) translate(28, 0)">
      <text x="0" y="102" font-family="'Helvetica Neue', 'Arial', sans-serif" font-size="78" font-weight="900" font-style="italic" letter-spacing="0.5" fill="#0F172A">${escXml(n)}</text>
    </g>
    <rect x="18" y="122" width="140" height="6" rx="3" fill="#CC0000"/>
  </svg>`;
}

async function main() {
  const prisma = new PrismaClient();
  try {
    const vehicles = await prisma.vehicle.findMany({
      where: { status: 'Active' },
      orderBy: { name: 'asc' },
    });

    let updated = 0;
    for (const v of vehicles) {
      const svg = buildWordmarkSvg(v.name, v.code);
      const trimmed = await sharp(Buffer.from(svg, 'utf8'))
        .trim({ threshold: 5 })
        .toBuffer();

      // Pad slightly and normalize to crisp transparent WebP
      const webp = await sharp(trimmed)
        .resize({
          width: 720,
          height: 120,
          fit: 'inside',
          withoutEnlargement: false,
        })
        .webp({ quality: 92, lossless: false })
        .toBuffer();

      const dataUri = `data:image/webp;base64,${webp.toString('base64')}`;
      await prisma.vehicle.update({
        where: { id: v.id },
        data: { wordmarkImageUrl: dataUri },
      });
      updated++;
    }
    console.log({ wordmarksGenerated: updated });
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
