import { PrismaClient, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('--- Starting Yash Honda Seeding ---');

  // 1. Initial 6 Branches in Pune grouped by Wing:
  // BigWing: Phursungi
  // RedWing: Wadki, Saswad, Uruli Kanchan, BT Kawade, Sasane Nagar
  const branchesData = [
    // 1 BigWing Branch
    {
      code: 'BWPHUR',
      name: 'Phursungi',
      wing: 'BigWing',
      address: 'Near Phursungi IT Park, Pune - Saswad Road, Phursungi, Pune 412308',
    },
    // 5 RedWing Branches
    {
      code: 'RWWDK',
      name: 'Wadki',
      wing: 'RedWing',
      address: 'Saswad Road, Wadki, Pune 412308',
    },
    {
      code: 'RWSAS',
      name: 'Saswad',
      wing: 'RedWing',
      address: 'Main Chowk, Pune - Saswad Road, Saswad, Pune 412301',
    },
    {
      code: 'RWURL',
      name: 'Uruli Kanchan',
      wing: 'RedWing',
      address: 'Pune - Solapur Highway, Uruli Kanchan, Pune 412202',
    },
    {
      code: 'RWBTK',
      name: 'BT Kawade',
      wing: 'RedWing',
      address: 'BT Kawade Road, Ghorpadi, Pune 411001',
    },
    {
      code: 'RWSSN',
      name: 'Sasane Nagar',
      wing: 'RedWing',
      address: 'Sasane Nagar, Hadapsar, Pune 411028',
    },
  ];

  const branches: Record<string, any> = {};
  for (const b of branchesData) {
    branches[b.code] = await prisma.branch.upsert({
      where: { code: b.code },
      update: {
        name: b.name,
        wing: b.wing,
        address: b.address,
      },
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
    { name: 'Black', hex: '#000000' },
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
      code: 'ACT110DLX',
      name: 'Activa 110 Dlx',
      category: 'Scooter',
      modelGroupId: mgRedWing.id,
      exShowroomPrice: 82450,
      onRoadPrice: 100380,
      colours: ['Black', 'Pearl Siren Blue', 'Rebel Red Metallic', 'Pearl Night White'],
    },
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
    { name: 'Ceramic Coating', defaultPrice: 3500, isPriceEditable: true },
    { name: 'Extended Warranty', defaultPrice: 2200, isPriceEditable: true },
    { name: 'Helmet', defaultPrice: 1250, isPriceEditable: false },
    { name: 'Optional Accessories', defaultPrice: 1500, isPriceEditable: true },
    { name: 'PDI Charges', defaultPrice: 850, isPriceEditable: false },
    { name: 'RSA', defaultPrice: 1499, isPriceEditable: false },
    { name: 'TESTONE', defaultPrice: 500, isPriceEditable: true },
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
  const leadSources = ['BikeWale', 'Walk-in Showroom', 'Telephonic Enquiry', 'BikeDekho / CarDekho', 'Meta Ads (Facebook/Instagram)', 'Google Search / Maps', 'Customer Referral'];
  for (const ls of leadSources) {
    await prisma.leadSource.upsert({
      where: { name: ls },
      update: {},
      create: { name: ls },
    });
  }
  console.log(`✓ Seeded ${leadSources.length} lead sources`);

  // 8. Areas (Pune Localities)
  const areas = ['PHURSUNGI', 'Wakad', 'Hinjewadi', 'Bhosari', 'Pimpri-Chinchwad', 'Baner', 'Kothrud', 'Hadapsar', 'Sinhagad Road', 'Shivajinagar'];
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

  // Branch Manager (Phursungi BigWing + Wadki RedWing)
  const branchManager = await prisma.user.upsert({
    where: { mobile: '9888888888' },
    update: {},
    create: {
      name: 'Branch Manager',
      mobile: '9888888888',
      passwordHash: defaultPassword,
      role: Role.BRANCH_MANAGER,
    },
  });

  await prisma.userBranch.upsert({
    where: { userId_branchId: { userId: branchManager.id, branchId: branches['BWPHUR'].id } },
    update: {},
    create: { userId: branchManager.id, branchId: branches['BWPHUR'].id },
  });
  await prisma.userBranch.upsert({
    where: { userId_branchId: { userId: branchManager.id, branchId: branches['RWWDK'].id } },
    update: {},
    create: { userId: branchManager.id, branchId: branches['RWWDK'].id },
  });

  // Sales Executive (Wadki)
  const salesExec = await prisma.user.upsert({
    where: { mobile: '9777777777' },
    update: {},
    create: {
      name: 'Rahul Sharma',
      mobile: '9777777777',
      passwordHash: defaultPassword,
      role: Role.SALES_EXEC,
    },
  });

  await prisma.userBranch.upsert({
    where: { userId_branchId: { userId: salesExec.id, branchId: branches['RWWDK'].id } },
    update: {},
    create: { userId: salesExec.id, branchId: branches['RWWDK'].id },
  });

  // Additional Sales Executives across Pune Showrooms
  const moreReps = [
    { name: 'Aditya Deshmukh', mobile: '9765432100', branchCode: 'BWPHUR' }, // BigWing Phursungi
    { name: 'Ajay Shinde', mobile: '9777777771', branchCode: 'RWWDK' },     // RedWing Wadki
    { name: 'Sneha Kulkarni', mobile: '9777777772', branchCode: 'RWSAS' },  // RedWing Saswad
    { name: 'Vikram Jadhav', mobile: '9777777773', branchCode: 'RWURL' },   // RedWing Uruli Kanchan
    { name: 'Priya Joshi', mobile: '9777777774', branchCode: 'RWBTK' },     // RedWing BT Kawade
    { name: 'Sachin Rep', mobile: '9777777775', branchCode: 'RWSSN' },      // RedWing Sasane Nagar
  ];

  for (const rep of moreReps) {
    const u = await prisma.user.upsert({
      where: { mobile: rep.mobile },
      update: {},
      create: {
        name: rep.name,
        mobile: rep.mobile,
        passwordHash: defaultPassword,
        role: Role.SALES_EXEC,
      },
    });

    const targetBranch = branches[rep.branchCode] || branches['RWWDK'];
    await prisma.userBranch.upsert({
      where: { userId_branchId: { userId: u.id, branchId: targetBranch.id } },
      update: {},
      create: { userId: u.id, branchId: targetBranch.id },
    });
  }

  // Create sample active floor customer sessions for today
  let sampleCustomer1 = await prisma.customer.findFirst({ where: { mobile: '9822011223' } });
  if (!sampleCustomer1) {
    sampleCustomer1 = await prisma.customer.create({
      data: {
        name: 'Sachin Patil',
        mobile: '9822011223',
        email: 'sachin.patil@gmail.com',
        address: 'Wakad, Pune',
      },
    });
  }

  let sampleCustomer2 = await prisma.customer.findFirst({ where: { mobile: '9822099887' } });
  if (!sampleCustomer2) {
    sampleCustomer2 = await prisma.customer.create({
      data: {
        name: 'Amit Deshmukh',
        mobile: '9822099887',
        email: 'amit.d@gmail.com',
        address: 'Pimple Nilakh, Pune',
      },
    });
  }

  const activa = await prisma.vehicle.findFirst({ where: { code: 'ACT6G' } });
  const sp125 = await prisma.vehicle.findFirst({ where: { code: 'SP125' } });

  const enq1Count = await prisma.enquiry.count({ where: { customerId: sampleCustomer1.id } });
  if (enq1Count === 0 && activa) {
    const enq = await prisma.enquiry.create({
      data: {
        branchId: branches['RWWKD'].id,
        customerId: sampleCustomer1.id,
        createdById: salesExec.id,
        assignedToId: salesExec.id,
        enquiryType: 'Walk-in',
        purchaseMode: 'Finance',
        status: 'ACTIVE',
      },
    });

    await prisma.quotation.create({
      data: {
        branchId: branches['RWWKD'].id,
        enquiryId: enq.id,
        vehicleId: activa.id,
        quoteNumber: 'RWQ-RWWKD-00101',
        colourName: 'Pearl Siren Blue',
        exShowroom: activa.exShowroomPrice,
        roadTax: 9480,
        insurance: 6020,
        grandTotal: 94500,
        pdfR2Key: '',
      },
    });
  }

  const enq2Count = await prisma.enquiry.count({ where: { customerId: sampleCustomer2.id } });
  const ajayUser = await prisma.user.findUnique({ where: { mobile: '9777777771' } });
  if (enq2Count === 0 && sp125 && ajayUser) {
    const enq = await prisma.enquiry.create({
      data: {
        branchId: branches['RWWKD'].id,
        customerId: sampleCustomer2.id,
        createdById: ajayUser.id,
        assignedToId: ajayUser.id,
        enquiryType: 'Walk-in',
        purchaseMode: 'Cash',
        status: 'CUSTOMER_BOUGHT',
      },
    });

    await prisma.quotation.create({
      data: {
        branchId: branches['RWWKD'].id,
        enquiryId: enq.id,
        vehicleId: sp125.id,
        quoteNumber: 'RWQ-RWWKD-00102',
        colourName: 'Matte Axis Grey Metallic',
        exShowroom: sp125.exShowroomPrice,
        roadTax: 10600,
        insurance: 5400,
        grandTotal: 106000,
        pdfR2Key: '',
      },
    });
  }

  console.log('✓ Seeded initial staff accounts:');
  console.log('  - Super Admin: 9999999999 (mapped to all 6 branches)');
  console.log('  - Branch Manager: 9888888888 (mapped to RWWKD, RWPHUR)');
  console.log('  - Sales Executive: 9777777777 (mapped to RWWKD)');
  console.log('  - Default password for all: YashHonda@2026');

  // 10. Company Settings
  const settingsFirst = await prisma.companySettings.findFirst();
  if (!settingsFirst) {
    await prisma.companySettings.create({
      data: {
        companyName: 'Yash Honda',
        gstNumber: '24XXXXXXXXXXZ5',
        address: 'Suryaloknagri Society Pune Hadapsar Pune 411013',
        bankName: 'HDFC Bank',
        accountNumber: '50200098765432',
        ifsc: 'HDFC0001234',
        upiId: 'yashhonda@hdfcbank',
        hypothecationCharge: 1500,
        applyHypothecationDefault: true,
      },
    });
    console.log('✓ Seeded Company Settings default profile');
  } else {
    await prisma.companySettings.update({
      where: { id: settingsFirst.id },
      data: {
        companyName: 'Yash Honda',
        gstNumber: '24XXXXXXXXXXZ5',
        address: 'Suryaloknagri Society Pune Hadapsar Pune 411013',
        bankName: 'HDFC Bank',
        accountNumber: '50200098765432',
        ifsc: 'HDFC0001234',
        upiId: 'yashhonda@hdfcbank',
      },
    });
    console.log('✓ Updated Company Settings matching dealership profile');
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
