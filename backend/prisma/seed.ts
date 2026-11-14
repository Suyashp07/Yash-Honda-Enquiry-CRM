import { PrismaClient, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('--- Starting Yash Honda Seeding ---');

  // 1. Initial 6 Branches in Pune
  const branchesData = [
    { code: 'BWH', name: 'Bhosari Workshop / Showroom', address: 'Plot 12, Ind Area, Bhosari, Pune' },
    { code: 'RWPHUR', name: 'RedWing Phugewadi', address: 'Old Mumbai-Pune Hwy, Phugewadi, Pune' },
    { code: 'RWWKD', name: 'RedWing Wakad', address: 'Dutt Mandir Rd, Wakad, Pune' },
    { code: 'BWHD', name: 'BigWing Hadapsar', address: 'Magarpatta Road, Hadapsar, Pune' },
    { code: 'BWSNR', name: 'BigWing Sinhagad Road', address: 'Near Bramha Hotel, Sinhagad Rd, Pune' },
    { code: 'BWSB', name: 'BigWing Senapati Bapat Rd', address: 'ICC Trade Tower, SB Road, Pune' },
  ];

  const branches: Record<string, any> = {};
  for (const b of branchesData) {
    branches[b.code] = await prisma.branch.upsert({
      where: { code: b.code },
      update: {},
      create: b,
    });
  }
  console.log(`✓ Seeded ${Object.keys(branches).length} branches`);

  // 2. Model Groups
  const mgRedWing = await prisma.modelGroup.upsert({
    where: { name: 'RedWing' },
    update: {},
    create: { name: 'RedWing', quotePrefix: 'RWQ' },
  });

  const mgBigWing = await prisma.modelGroup.upsert({
    where: { name: 'BigWing' },
    update: {},
    create: { name: 'BigWing', quotePrefix: 'BWQ' },
  });
  console.log('✓ Seeded model groups: RedWing (RWQ), BigWing (BWQ)');

  // 3. Colours
  const coloursData = [
    { name: 'Pearl Siren Blue', hex: '#1E3A8A' },
    { name: 'Decent Blue Metallic', hex: '#2563EB' },
    { name: 'Rebel Red Metallic', hex: '#DC2626' },
    { name: 'Matte Axis Grey Metallic', hex: '#4B5563' },
    { name: 'Pearl Nightstar Black', hex: '#111827' },
    { name: 'Pearl Night White', hex: '#F9FAFB' },
  ];

  const colours: Record<string, any> = {};
  for (const c of coloursData) {
    colours[c.name] = await prisma.colour.upsert({
      where: { name: c.name },
      update: {},
      create: c,
    });
  }
  console.log(`✓ Seeded ${Object.keys(colours).length} colours`);

  // 4. Vehicles
  const vehiclesData = [
    {
      code: 'ACT6G',
      name: 'Activa 6G DLX',
      category: 'Scooter',
      modelGroupId: mgRedWing.id,
      exShowroomPrice: 79000,
      onRoadPrice: 94500,
      colours: ['Pearl Siren Blue', 'Rebel Red Metallic', 'Pearl Night White', 'Pearl Nightstar Black'],
    },
    {
      code: 'DIO125',
      name: 'Dio 125 Smart',
      category: 'Scooter',
      modelGroupId: mgRedWing.id,
      exShowroomPrice: 85000,
      onRoadPrice: 101000,
      colours: ['Matte Axis Grey Metallic', 'Pearl Siren Blue', 'Rebel Red Metallic'],
    },
    {
      code: 'SHN125',
      name: 'Shine 125 Disc',
      category: 'MC',
      modelGroupId: mgRedWing.id,
      exShowroomPrice: 84000,
      onRoadPrice: 99500,
      colours: ['Pearl Nightstar Black', 'Decent Blue Metallic', 'Rebel Red Metallic'],
    },
    {
      code: 'SP125',
      name: 'SP 125 Disc',
      category: 'MC',
      modelGroupId: mgRedWing.id,
      exShowroomPrice: 90000,
      onRoadPrice: 106000,
      colours: ['Matte Axis Grey Metallic', 'Pearl Siren Blue', 'Pearl Nightstar Black'],
    },
    {
      code: 'CB350H',
      name: 'Hness CB350 DLX Pro',
      category: 'BigBike',
      modelGroupId: mgBigWing.id,
      exShowroomPrice: 215000,
      onRoadPrice: 262000,
      colours: ['Pearl Nightstar Black', 'Rebel Red Metallic', 'Decent Blue Metallic'],
    },
  ];

  for (const v of vehiclesData) {
    const { colours: vColours, ...vData } = v;
    const vehicle = await prisma.vehicle.upsert({
      where: { code: vData.code },
      update: {},
      create: vData,
    });

    for (const colourName of vColours) {
      const colour = colours[colourName];
      if (colour) {
        await prisma.vehicleColour.upsert({
          where: {
            vehicleId_colourId: {
              vehicleId: vehicle.id,
              colourId: colour.id,
            },
          },
          update: {},
          create: {
            vehicleId: vehicle.id,
            colourId: colour.id,
          },
        });
      }
    }
  }
  console.log(`✓ Seeded ${vehiclesData.length} vehicles with colour mappings`);

  // 5. Accessories (fixed vs. editable prices)
  const accessoriesData = [
    { name: 'Helmet (Studds/Honda ISI)', defaultPrice: 1250, isPriceEditable: false },
    { name: 'Ceramic Coating (2-Year)', defaultPrice: 3500, isPriceEditable: true },
    { name: 'RSA (Roadside Assistance - 1 Yr)', defaultPrice: 1499, isPriceEditable: false },
    { name: 'Designer Seat Cover', defaultPrice: 650, isPriceEditable: true },
    { name: 'Floor Mat Premium', defaultPrice: 450, isPriceEditable: false },
    { name: 'Grip Covers & Lever Sleeves', defaultPrice: 250, isPriceEditable: false },
    { name: 'Extended Warranty (3+3 Yrs)', defaultPrice: 2200, isPriceEditable: true },
  ];

  for (const acc of accessoriesData) {
    await prisma.accessory.upsert({
      where: { name: acc.name },
      update: {},
      create: acc,
    });
  }
  console.log(`✓ Seeded ${accessoriesData.length} accessories`);

  // 6. Financiers
  const financiers = ['HDFC Bank', 'ICICI Bank', 'Honda Finance (IDFC)', 'Tata Capital', 'Bajaj Finance'];
  for (const f of financiers) {
    await prisma.financier.upsert({
      where: { name: f },
      update: {},
      create: { name: f },
    });
  }
  console.log(`✓ Seeded ${financiers.length} financiers`);

  // 7. Lead Sources
  const leadSources = ['Walk-in Showroom', 'Telephonic Enquiry', 'BikeDekho / CarDekho', 'Meta Ads (Facebook/Instagram)', 'Google Search / Maps', 'Customer Referral'];
  for (const ls of leadSources) {
    await prisma.leadSource.upsert({
      where: { name: ls },
      update: {},
      create: { name: ls },
    });
  }
  console.log(`✓ Seeded ${leadSources.length} lead sources`);

  // 8. Areas (Pune Localities)
  const areas = ['Wakad', 'Hinjewadi', 'Bhosari', 'Pimpri-Chinchwad', 'Baner', 'Kothrud', 'Hadapsar', 'Sinhagad Road', 'Shivajinagar'];
  for (const a of areas) {
    await prisma.area.upsert({
      where: { name: a },
      update: {},
      create: { name: a },
    });
  }
  console.log(`✓ Seeded ${areas.length} Pune areas`);

  // 9. Users & Roles with user_branches M:N mappings
  const defaultPassword = await bcrypt.hash('YashHonda@2026', 10);

  // Super Admin (all branches)
  const superAdmin = await prisma.user.upsert({
    where: { mobile: '9999999999' },
    update: {},
    create: {
      name: 'Owner / Super Admin',
      mobile: '9999999999',
      passwordHash: defaultPassword,
      role: Role.SUPER_ADMIN,
    },
  });

  for (const branch of Object.values(branches)) {
    await prisma.userBranch.upsert({
      where: { userId_branchId: { userId: superAdmin.id, branchId: branch.id } },
      update: {},
      create: { userId: superAdmin.id, branchId: branch.id },
    });
  }

  // Branch Manager (Wakad + Phugewadi)
  const branchManager = await prisma.user.upsert({
    where: { mobile: '9888888888' },
    update: {},
    create: {
      name: 'Wakad Branch Manager',
      mobile: '9888888888',
      passwordHash: defaultPassword,
      role: Role.BRANCH_MANAGER,
    },
  });

  await prisma.userBranch.upsert({
    where: { userId_branchId: { userId: branchManager.id, branchId: branches['RWWKD'].id } },
    update: {},
    create: { userId: branchManager.id, branchId: branches['RWWKD'].id },
  });
  await prisma.userBranch.upsert({
    where: { userId_branchId: { userId: branchManager.id, branchId: branches['RWPHUR'].id } },
    update: {},
    create: { userId: branchManager.id, branchId: branches['RWPHUR'].id },
  });

  // Sales Executive (Wakad only)
  const salesExec = await prisma.user.upsert({
    where: { mobile: '9777777777' },
    update: {},
    create: {
      name: 'Rahul Sharma (Sales Exec)',
      mobile: '9777777777',
      passwordHash: defaultPassword,
      role: Role.SALES_EXEC,
    },
  });

  await prisma.userBranch.upsert({
    where: { userId_branchId: { userId: salesExec.id, branchId: branches['RWWKD'].id } },
    update: {},
    create: { userId: salesExec.id, branchId: branches['RWWKD'].id },
  });

  console.log('✓ Seeded initial staff accounts:');
  console.log('  - Super Admin: 9999999999 (mapped to all 6 branches)');
  console.log('  - Branch Manager: 9888888888 (mapped to RWWKD, RWPHUR)');
  console.log('  - Sales Executive: 9777777777 (mapped to RWWKD)');
  console.log('  - Default password for all: YashHonda@2026');

  // 10. Company Settings
  const settingsCount = await prisma.companySettings.count();
  if (settingsCount === 0) {
    await prisma.companySettings.create({
      data: {
        companyName: 'Yash Honda Two-Wheelers Pvt Ltd',
        gstNumber: '27AABCY1234F1Z5',
        address: 'Plot 12, Pimpri-Chinchwad Ind Area, Pune - 411019',
        bankName: 'HDFC Bank Ltd',
        accountNumber: '50200012345678',
        ifsc: 'HDFC0001234',
        upiId: 'yashhonda@hdfcbank',
        hypothecationCharge: 1500,
        applyHypothecationDefault: true,
      },
    });
    console.log('✓ Seeded Company Settings default profile');
  }

  console.log('--- Yash Honda Seeding Completed Successfully ---');
}

main()
  .catch((e) => {
    console.error('Error during seeding:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
