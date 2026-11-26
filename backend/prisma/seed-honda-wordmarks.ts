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

const DEFS = `
  <defs>
    <linearGradient id="obsidian" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#1E293B"/>
      <stop offset="55%" stop-color="#0F172A"/>
      <stop offset="100%" stop-color="#020617"/>
    </linearGradient>
    <linearGradient id="crimson" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#EF4444"/>
      <stop offset="50%" stop-color="#CC0000"/>
      <stop offset="100%" stop-color="#991B1B"/>
    </linearGradient>
    <linearGradient id="gold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#F59E0B"/>
      <stop offset="50%" stop-color="#B45309"/>
      <stop offset="100%" stop-color="#78350F"/>
    </linearGradient>
  </defs>
`;

function buildWordmarkSvg(name: string): string {
  const n = name.trim();
  const lower = n.toLowerCase();

  // 1. ADV 160 — exact angular stencil geometry matching official ADV160 brochure
  if (lower.includes('adv')) {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1400 170" width="1400" height="170">
      ${DEFS}
      <!-- Custom angular ADV vector lettering -->
      <g transform="translate(18, 16)">
        <!-- A -->
        <polygon points="58,0 112,0 132,110 92,110 85,78 46,78 34,110 0,110" fill="url(#obsidian)"/>
        <polygon points="62,28 50,58 80,58 76,28" fill="#FFFFFF"/>
        <!-- D -->
        <path d="M150,0 L236,0 C268,0 282,20 274,55 C266,90 242,110 208,110 L128,110 Z" fill="url(#obsidian)"/>
        <path d="M180,26 L168,84 L208,84 C226,84 238,72 242,55 C246,38 238,26 220,26 Z" fill="#FFFFFF"/>
        <!-- V -->
        <polygon points="292,0 336,0 350,74 398,0 442,0 364,110 318,110" fill="url(#obsidian)"/>
        <!-- Diagonal speed slice across ADV -->
        <polygon points="10,66 430,44 432,52 8,74" fill="#FFFFFF"/>
        <!-- 160 in heavy angular stencil -->
        <text x="454" y="106" font-family="Impact, 'DIN Condensed', sans-serif" font-size="108" font-weight="900" letter-spacing="4" transform="skewX(-16) translate(32,0)" fill="url(#crimson)">160</text>
      </g>
      <polygon points="18,140 650,140 634,150 8,150" fill="url(#crimson)"/>
    </svg>`;
  }

  // 2. Shine series — Brush Script italic + bold geometric numerals + curved red swoosh
  if (lower.includes('shine')) {
    const suffix = n.replace(/shine/i, '').trim();
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1400 170" width="1400" height="170">
      ${DEFS}
      <text x="18" y="108" font-family="'Brush Script MT', 'Snell Roundhand', cursive" font-size="118" font-weight="700" fill="url(#obsidian)">Shine</text>
      <text x="315" y="106" font-family="'DIN Condensed', 'Impact', sans-serif" font-size="84" font-weight="900" transform="skewX(-14) translate(26,0)" letter-spacing="2" fill="url(#crimson)">${escXml(suffix)}</text>
      <path d="M16 132 Q 210 116 540 132 L 522 143 Q 210 128 8 143 Z" fill="url(#crimson)"/>
    </svg>`;
  }

  // 3. Activa series — Avenir Next Heavy Italic + DIN Alternate numerals + red/obsidian bar
  if (lower.includes('activa')) {
    const suffix = n.replace(/activa/i, '').trim();
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1400 170" width="1400" height="170">
      ${DEFS}
      <g transform="skewX(-12) translate(34, 0)">
        <text x="0" y="106" font-family="'Avenir Next', 'Futura', sans-serif" font-size="94" font-weight="900" font-style="italic" letter-spacing="1" fill="url(#obsidian)">Activa</text>
        <text x="318" y="106" font-family="'DIN Alternate', 'DIN Condensed', sans-serif" font-size="68" font-weight="900" letter-spacing="1.5" fill="url(#crimson)">${escXml(suffix)}</text>
      </g>
      <rect x="20" y="128" width="150" height="8" rx="4" fill="url(#crimson)"/>
      <rect x="178" y="128" width="44" height="8" rx="4" fill="url(#obsidian)"/>
    </svg>`;
  }

  // 4. Dio series — bold tilted Futura/Impact street-sport
  if (lower.includes('dio')) {
    const suffix = n.replace(/dio/i, '').trim();
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1400 170" width="1400" height="170">
      ${DEFS}
      <g transform="skewX(-18) translate(46, 0)">
        <text x="0" y="112" font-family="'Futura', 'Impact', sans-serif" font-size="108" font-weight="900" font-style="italic" letter-spacing="2" fill="url(#crimson)">Dio</text>
        <text x="205" y="112" font-family="'DIN Condensed', 'Impact', sans-serif" font-size="82" font-weight="900" letter-spacing="2" fill="url(#obsidian)">${escXml(suffix)}</text>
      </g>
      <polygon points="18,132 390,132 372,143 8,143" fill="url(#obsidian)"/>
    </svg>`;
  }

  // 5. SP 125 / SP 160 — sharp racing Impact/DIN stencil
  if (lower.startsWith('sp ') || lower === 'sp125' || lower === 'sp160') {
    const suffix = n.replace(/sp/i, '').trim();
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1400 170" width="1400" height="170">
      ${DEFS}
      <g transform="skewX(-20) translate(52, 0)">
        <text x="0" y="114" font-family="'Impact', 'DIN Condensed', sans-serif" font-size="112" font-weight="900" letter-spacing="4" fill="url(#crimson)">SP</text>
        <text x="155" y="114" font-family="'DIN Condensed', 'Impact', sans-serif" font-size="102" font-weight="900" letter-spacing="3" fill="url(#obsidian)">${escXml(suffix)}</text>
      </g>
      <polygon points="18,134 380,134 366,144 8,144" fill="url(#crimson)"/>
    </svg>`;
  }

  // 6. Hornet series — aggressive DIN Condensed uppercase with red racing bar
  if (lower.includes('hornet')) {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1400 170" width="1400" height="170">
      ${DEFS}
      <g transform="skewX(-15) translate(42, 0)">
        <text x="0" y="110" font-family="'DIN Condensed', 'Impact', sans-serif" font-size="96" font-weight="900" letter-spacing="3" fill="url(#obsidian)">${escXml(n.toUpperCase())}</text>
      </g>
      <polygon points="18,132 520,132 500,143 8,143" fill="url(#crimson)"/>
    </svg>`;
  }

  // 7. H'ness & CB350 heritage series — Didot / Bodoni 72 classic neo-retro serif + gold/red twin pinstripe
  if (lower.includes('cb350') || lower.includes('h\'ness')) {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1400 170" width="1400" height="170">
      ${DEFS}
      <text x="16" y="106" font-family="'Didot', 'Bodoni 72', 'Baskerville', serif" font-size="88" font-weight="700" letter-spacing="1.5" fill="url(#obsidian)">${escXml(n)}</text>
      <line x1="18" y1="128" x2="290" y2="128" stroke="url(#gold)" stroke-width="6" stroke-linecap="round"/>
      <line x1="302" y1="128" x2="390" y2="128" stroke="url(#crimson)" stroke-width="6" stroke-linecap="round"/>
    </svg>`;
  }

  // 8. Rebel 300 / Rebel 500 — Rockwell / Copperplate custom cruiser slab
  if (lower.includes('rebel')) {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1400 170" width="1400" height="170">
      ${DEFS}
      <text x="16" y="108" font-family="'Rockwell', 'Copperplate', serif" font-size="92" font-weight="900" letter-spacing="3" fill="url(#obsidian)">${escXml(n.toUpperCase())}</text>
      <rect x="18" y="128" width="240" height="7" fill="url(#crimson)"/>
    </svg>`;
  }

  // 9. Gold Wing Tour — luxury Didot + Gold gradient
  if (lower.includes('gold wing')) {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1400 170" width="1400" height="170">
      ${DEFS}
      <text x="16" y="106" font-family="'Copperplate', 'Didot', serif" font-size="86" font-weight="700" letter-spacing="3" fill="url(#obsidian)">${escXml(n.toUpperCase())}</text>
      <line x1="18" y1="128" x2="380" y2="128" stroke="url(#gold)" stroke-width="7" stroke-linecap="round"/>
    </svg>`;
  }

  // 10. Adventure / Supersport (NX, XR, Transalp, CBR, CB500) — DIN Condensed Bold
  if (
    lower.includes('nx') ||
    lower.includes('xr') ||
    lower.includes('transalp') ||
    lower.includes('cbr') ||
    lower.includes('cb500')
  ) {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1400 170" width="1400" height="170">
      ${DEFS}
      <g transform="skewX(-14) translate(38, 0)">
        <text x="0" y="108" font-family="'DIN Condensed', 'Impact', sans-serif" font-size="92" font-weight="900" letter-spacing="3" fill="url(#obsidian)">${escXml(n.toUpperCase())}</text>
      </g>
      <polygon points="18,128 240,128 228,137 10,137" fill="url(#crimson)"/>
      <polygon points="248,128 320,128 308,137 236,137" fill="url(#obsidian)"/>
    </svg>`;
  }

  // 11. Commuter Sport (Unicorn, Livo, CB300R, etc.) — Futura / Avenir Next Heavy Italic
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1400 170" width="1400" height="170">
    ${DEFS}
    <g transform="skewX(-12) translate(32, 0)">
      <text x="0" y="108" font-family="'Futura', 'Avenir Next', sans-serif" font-size="88" font-weight="900" font-style="italic" letter-spacing="1.5" fill="url(#obsidian)">${escXml(n)}</text>
    </g>
    <rect x="18" y="128" width="180" height="7" rx="3.5" fill="url(#crimson)"/>
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
      const svg = buildWordmarkSvg(v.name);
      const trimmed = await sharp(Buffer.from(svg, 'utf8'))
        .trim({ threshold: 5 })
        .toBuffer();

      const webp = await sharp(trimmed)
        .resize({
          width: 760,
          height: 130,
          fit: 'inside',
          withoutEnlargement: false,
        })
        .webp({ quality: 94 })
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
