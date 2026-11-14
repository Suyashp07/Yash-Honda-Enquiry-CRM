import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding initial Yash Honda CRM data...');

  // 1. Initial 6 Branches in Pune
  const branches = [
    { code: 'BWH', name: 'Bhosari Workshop / Showroom', address: 'Bhosari, Pune' },
    { code: 'RWPHUR', name: 'RedWing Phugewadi', address: 'Phugewadi, Pune' },
    { code: 'RWWKD', name: 'RedWing Wakad', address: 'Wakad, Pune' },
    { code: 'BWHD', name: 'BigWing Hadapsar', address: 'Hadapsar, Pune' },
    { code: 'BWSNR', name: 'BigWing Sinhagad Road', address: 'Sinhagad Road, Pune' },
    { code: 'BWSB', name: 'BigWing Senapati Bapat Rd', address: 'SB Road, Pune' },
  ];

  for (const b of branches) {
    await prisma.branch.upsert({
      where: { code: b.code },
      update: {},
      create: b,
    });
  }

  // 2. Model Groups
  const modelGroups = [
    { name: 'RedWing', quotePrefix: 'RWQ' },
    { name: 'BigWing', quotePrefix: 'BWQ' },
  ];

  for (const mg of modelGroups) {
    await prisma.modelGroup.upsert({
      where: { name: mg.name },
      update: {},
      create: mg,
    });
  }

  console.log('Seed completed successfully.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
