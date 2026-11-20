import { PrismaClient, Role, EnquiryStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

// Helper to get random item from an array
function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

// Helper to get random number between min and max
function randInt(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

// Indian Customer Names
const firstNames = [
  'Ramesh', 'Aniket', 'Pooja', 'Nikhil', 'Snehal', 'Rohan', 'Rajesh', 'Priya',
  'Vikrant', 'Swati', 'Ganesh', 'Mahesh', 'Pallavi', 'Deepak', 'Sunita', 'Vijay',
  'Amol', 'Kavita', 'Sanjay', 'Manisha', 'Prakash', 'Prashant', 'Sonali', 'Tushar',
  'Kiran', 'Anita', 'Dhananjay', 'Aarti', 'Santosh', 'Shrikant', 'Neha', 'Sachin',
  'Aditi', 'Siddharth', 'Varsha', 'Ajit', 'Shruti', 'Milind', 'Meena', 'Pradeep',
  'Ashwini', 'Akshay', 'Tanvi', 'Abhishek', 'Sheetal', 'Kailash', 'Jyoti', 'Chetan',
  'Sandeep', 'Supriya', 'Omkar', 'Vandana', 'Harish', 'Namrata', 'Nitin', 'Rupali'
];

const lastNames = [
  'Kulkarni', 'Shinde', 'More', 'Joshi', 'Patil', 'Deshpande', 'Pawar', 'Kadam',
  'Chavan', 'Jagtap', 'Gokhale', 'Gaikwad', 'Mane', 'Salunkhe', 'Sawant', 'Kale',
  'Bhosale', 'Bhave', 'Dumbre', 'Jadhav', 'Thorat', 'Bichkar', 'Godbole', 'Khamkar',
  'Phadtare', 'Kashid', 'Gholap', 'Wagh', 'Dumbre', 'Ghongade', 'Kharat', 'Shitole'
];

// Sample follow-up remarks
const followUpRemarksPool = [
  'Customer visited showroom for test ride with family. Very satisfied with ride quality.',
  'Discussed finance options with HDFC Bank. Customer requested quotation on WhatsApp.',
  'Comparing with TVS Jupiter and Suzuki Access. Emphasized Honda engine refinement & resale value.',
  'Quotation breakdown explained over phone. Requested callback over the weekend.',
  'Customer requested home test ride at Baner locality for senior citizen parent.',
  'Booking token advance of ₹5,000 received via UPI. Delivery promised next week.',
  'Customer awaiting bonus payout next month before finalizing booking.',
  'Old Hero Splendor exchange evaluation completed at ₹22,500. Customer agreed on net on-road price.',
  'Customer finalized Matte Axis Grey colour variant. Documents submitted for loan approval.',
  'Follow-up call completed: customer confirmed booking for festive delivery.',
  'Informed customer about festive cashback offer and zero processing fee on Honda Finance.',
  'Customer visited with spouse; decided on Activa 6G DLX with premium accessories package.',
  'Follow-up on loan sanction: ICICI Bank pre-approved. Delivery scheduled for Friday.',
  'Requested exchange quotation for 2018 Bajaj Pulsar 150. Evaluated by pre-owned desk at ₹31,000.',
  'Customer finalized booking for Honda Shine 125 Disc. Preferred Rebel Red Metallic shade.'
];

// Define Staff Structure: 1 Sales/Branch Manager and 3 Sales Reps per branch
interface BranchStaffDef {
  branchCode: string;
  manager: {
    name: string;
    mobile: string;
    email: string;
  };
  reps: Array<{
    name: string;
    mobile: string;
    email: string;
  }>;
}

const branchStaffConfig: BranchStaffDef[] = [
  {
    branchCode: 'BWPHUR', // Phursungi (BigWing)
    manager: {
      name: 'Rohan Deshpande (BM - Phursungi)',
      mobile: '9822100001',
      email: 'bm.phursungi@yashhonda.com',
    },
    reps: [
      { name: 'Kunal Patil', mobile: '9822100011', email: 'kunal.patil@yashhonda.com' },
      { name: 'Rohit Gaikwad', mobile: '9822100012', email: 'rohit.gaikwad@yashhonda.com' },
      { name: 'Pooja More', mobile: '9822100013', email: 'pooja.more@yashhonda.com' },
    ],
  },
  {
    branchCode: 'RWWDK', // Wadki (RedWing)
    manager: {
      name: 'Suresh Kadam (BM - Wadki)',
      mobile: '9822200001',
      email: 'bm.wadki@yashhonda.com',
    },
    reps: [
      { name: 'Rahul Sharma', mobile: '9777777777', email: 'rahul.sharma@yashhonda.com' },
      { name: 'Ajay Shinde', mobile: '9777777771', email: 'ajay.shinde@yashhonda.com' },
      { name: 'Sneha Kulkarni', mobile: '9777777772', email: 'sneha.kulkarni@yashhonda.com' },
    ],
  },
  {
    branchCode: 'RWSAS', // Saswad (RedWing)
    manager: {
      name: 'Nitin Jagtap (BM - Saswad)',
      mobile: '9822300001',
      email: 'bm.saswad@yashhonda.com',
    },
    reps: [
      { name: 'Vikram Jadhav', mobile: '9777777773', email: 'vikram.jadhav@yashhonda.com' },
      { name: 'Sachin Bhosale', mobile: '9822300012', email: 'sachin.bhosale@yashhonda.com' },
      { name: 'Kavita Pawar', mobile: '9822300013', email: 'kavita.pawar@yashhonda.com' },
    ],
  },
  {
    branchCode: 'RWURL', // Uruli Kanchan (RedWing)
    manager: {
      name: 'Amit Chavan (BM - Uruli Kanchan)',
      mobile: '9822400001',
      email: 'bm.uruli@yashhonda.com',
    },
    reps: [
      { name: 'Aditya Deshmukh', mobile: '9765432100', email: 'aditya.deshmukh@yashhonda.com' },
      { name: 'Ganesh Sawant', mobile: '9822400012', email: 'ganesh.sawant@yashhonda.com' },
      { name: 'Priya Kulkarni', mobile: '9822400013', email: 'priya.kulkarni@yashhonda.com' },
    ],
  },
  {
    branchCode: 'RWBTK', // BT Kawade (RedWing)
    manager: {
      name: 'Mahesh Shinde (BM - BT Kawade)',
      mobile: '9822500001',
      email: 'bm.btkawade@yashhonda.com',
    },
    reps: [
      { name: 'Deepak Mane', mobile: '9822500011', email: 'deepak.mane@yashhonda.com' },
      { name: 'Sonali Gholap', mobile: '9822500012', email: 'sonali.gholap@yashhonda.com' },
      { name: 'Prashant Thorat', mobile: '9822500013', email: 'prashant.thorat@yashhonda.com' },
    ],
  },
  {
    branchCode: 'RWSSN', // Sasane Nagar (RedWing)
    manager: {
      name: 'Dhananjay Godbole (BM - Sasane Nagar)',
      mobile: '9822600001',
      email: 'bm.sasanenagar@yashhonda.com',
    },
    reps: [
      { name: 'Amol Wagh', mobile: '9822600011', email: 'amol.wagh@yashhonda.com' },
      { name: 'Tanvi Shitole', mobile: '9822600012', email: 'tanvi.shitole@yashhonda.com' },
      { name: 'Akshay Phadtare', mobile: '9822600013', email: 'akshay.phadtare@yashhonda.com' },
    ],
  },
];

async function main() {
  console.log('=== Starting Yash Honda Multi-Branch Seeder (1 BM + 3 Reps per Branch & 2-Month Data) ===');

  const passwordHash = await bcrypt.hash('123456', 10);

  // 1. Fetch Master Branches
  const allBranches = await prisma.branch.findMany({ where: { status: 'Active' } });
  if (allBranches.length === 0) {
    console.error('No branches found. Please ensure database has branches.');
    return;
  }
  const branchByCode = new Map(allBranches.map((b) => [b.code, b]));

  // 2. Fetch or Add BigWing Vehicles
  const mgBigWing = await prisma.modelGroup.findFirst({ where: { name: 'BigWing' } });
  const mgRedWing = await prisma.modelGroup.findFirst({ where: { name: 'RedWing' } });

  if (mgBigWing) {
    // Ensure CB350RS exists
    await prisma.vehicle.upsert({
      where: { code: 'CB350RS' },
      update: {},
      create: {
        code: 'CB350RS',
        name: 'CB350RS Monotone',
        category: 'Motorcycle',
        modelGroupId: mgBigWing.id,
        exShowroomPrice: 214856,
        onRoadPrice: 254200,
        status: 'Active',
      },
    });

    // Ensure CB300R exists
    await prisma.vehicle.upsert({
      where: { code: 'CB300R' },
      update: {},
      create: {
        code: 'CB300R',
        name: 'CB300R Matte Steel Black',
        category: 'Motorcycle',
        modelGroupId: mgBigWing.id,
        exShowroomPrice: 240000,
        onRoadPrice: 284500,
        status: 'Active',
      },
    });
  }

  // 3. Upsert Super Admin / Owner User
  const superAdmin = await prisma.user.upsert({
    where: { mobile: '9999999999' },
    update: {
      name: 'Owner / Super Admin',
      role: Role.SUPER_ADMIN,
      passwordHash,
    },
    create: {
      name: 'Owner / Super Admin',
      mobile: '9999999999',
      role: Role.SUPER_ADMIN,
      passwordHash,
    },
  });

  // Assign Super Admin to ALL branches
  for (const b of allBranches) {
    await prisma.userBranch.upsert({
      where: {
        userId_branchId: { userId: superAdmin.id, branchId: b.id },
      },
      update: {},
      create: {
        userId: superAdmin.id,
        branchId: b.id,
      },
    });
  }
  console.log('✓ Verified Super Admin / Owner linked to all 6 branches');

  // 4. Create 1 Branch Manager and 3 Sales Reps for EVERY branch
  const createdRepsByBranchId: Map<string, any[]> = new Map();

  for (const staffDef of branchStaffConfig) {
    const branch = branchByCode.get(staffDef.branchCode);
    if (!branch) {
      console.warn(`Branch with code ${staffDef.branchCode} not found in DB. Skipping.`);
      continue;
    }

    // A. Upsert Branch Manager
    const bmUser = await prisma.user.upsert({
      where: { mobile: staffDef.manager.mobile },
      update: {
        name: staffDef.manager.name,
        role: Role.BRANCH_MANAGER,
        passwordHash,
        status: 'Active',
      },
      create: {
        name: staffDef.manager.name,
        mobile: staffDef.manager.mobile,
        role: Role.BRANCH_MANAGER,
        passwordHash,
        status: 'Active',
      },
    });

    // Link BM to this branch (clean other branch links if any)
    await prisma.userBranch.upsert({
      where: {
        userId_branchId: { userId: bmUser.id, branchId: branch.id },
      },
      update: {},
      create: {
        userId: bmUser.id,
        branchId: branch.id,
      },
    });

    console.log(`✓ Configured Branch Manager for ${branch.name}: ${bmUser.name} (${bmUser.mobile})`);

    // B. Upsert 3 Sales Reps
    const branchReps: any[] = [];
    for (const repDef of staffDef.reps) {
      const repUser = await prisma.user.upsert({
        where: { mobile: repDef.mobile },
        update: {
          name: repDef.name,
          role: Role.SALES_EXEC,
          passwordHash,
          status: 'Active',
        },
        create: {
          name: repDef.name,
          mobile: repDef.mobile,
          role: Role.SALES_EXEC,
          passwordHash,
          status: 'Active',
        },
      });

      // Link Rep strictly to this branch
      await prisma.userBranch.upsert({
        where: {
          userId_branchId: { userId: repUser.id, branchId: branch.id },
        },
        update: {},
        create: {
          userId: repUser.id,
          branchId: branch.id,
        },
      });

      branchReps.push(repUser);
      console.log(`  • Sales Rep for ${branch.name}: ${repUser.name} (${repUser.mobile})`);
    }

    createdRepsByBranchId.set(branch.id, branchReps);
  }

  // 5. Load Master Vehicles, Accessories, Financiers, Lead Sources, Areas
  const vehicles = await prisma.vehicle.findMany({
    where: { status: 'Active' },
    include: { colours: { include: { colour: true } }, modelGroup: true },
  });
  const financiers = await prisma.financier.findMany({ where: { status: 'Active' } });
  const leadSources = await prisma.leadSource.findMany({ where: { status: 'Active' } });
  const areas = await prisma.area.findMany({ where: { status: 'Active' } });
  const accessories = await prisma.accessory.findMany({ where: { status: 'Active' } });

  console.log(`\n=== Seeding Branch-Specific Enquiries across past 60 days ===`);

  const now = new Date();
  const totalDays = 60;
  let totalEnquiriesCreated = 0;
  let totalQuotesCreated = 0;
  let totalFollowUpsCreated = 0;

  // Track sequence for quote numbering per branch
  const branchQuoteSeq: Record<string, number> = {};
  for (const b of allBranches) {
    const existingQuotesCount = await prisma.quotation.count({ where: { branchId: b.id } });
    branchQuoteSeq[b.code] = existingQuotesCount + 200;
  }

  // 6. Generate Branch-Specific Data across all 6 branches
  for (const branch of allBranches) {
    const isBigWing = branch.wing === 'BigWing';
    const suitableVehicles = vehicles.filter((v) =>
      isBigWing ? v.modelGroup.name === 'BigWing' : v.modelGroup.name === 'RedWing',
    );
    const branchVehicles = suitableVehicles.length > 0 ? suitableVehicles : vehicles;
    const branchReps = createdRepsByBranchId.get(branch.id) || [];

    if (branchReps.length === 0) {
      console.warn(`No reps found for branch ${branch.name}. Skipping enquiries.`);
      continue;
    }

    console.log(`Generating data for ${branch.name} (${branch.code} • ${branch.wing}) with ${branchReps.length} reps...`);

    // A. Generate Live Data for TODAY (4 to 7 enquiries distributed across the 3 reps)
    const todayCount = randInt(4, 7);
    const todaySlots = [
      { hour: 9, minute: 30 },
      { hour: 10, minute: 15 },
      { hour: 11, minute: 45 },
      { hour: 14, minute: 0 },
      { hour: 15, minute: 30 },
      { hour: 16, minute: 45 },
      { hour: 18, minute: 15 },
    ];

    for (let i = 0; i < todayCount; i++) {
      const rep = branchReps[i % branchReps.length];
      const vehicle = pick(branchVehicles);
      const colourName = vehicle.colours.length > 0 ? pick(vehicle.colours).colour.name : 'Black';
      const slot = todaySlots[i % todaySlots.length];

      const recordDate = new Date(now);
      recordDate.setHours(slot.hour, slot.minute, randInt(0, 50), 0);

      // Customer
      const firstName = pick(firstNames);
      const lastName = pick(lastNames);
      const customerName = `${firstName} ${lastName}`;
      const mobile = `98${randInt(10000000, 99999999)}`;
      const email = `${firstName.toLowerCase()}.${lastName.toLowerCase()}${randInt(10, 99)}@gmail.com`;
      const area = pick(areas);
      const leadSource = pick(leadSources);
      const purchaseMode = Math.random() < 0.6 ? 'Finance' : 'Cash';
      const financier = purchaseMode === 'Finance' && financiers.length > 0 ? pick(financiers) : null;
      const isWalkin = Math.random() < 0.8;
      const enquiryType = isWalkin ? 'Walk-in' : 'Telephonic Enquiry';
      const hasExchange = Math.random() < 0.25;

      // Status: 1 booked, rest active
      const status = i === 0 ? EnquiryStatus.CUSTOMER_BOUGHT : EnquiryStatus.ACTIVE;

      const customer = await prisma.customer.create({
        data: {
          name: customerName,
          mobile,
          email,
          areaId: area?.id,
          address: `${area?.name || 'Hadapsar'}, Pune, Maharashtra`,
          createdAt: recordDate,
          updatedAt: recordDate,
        },
      });

      const enquiry = await prisma.enquiry.create({
        data: {
          branchId: branch.id,
          customerId: customer.id,
          createdById: rep.id,
          assignedToId: rep.id,
          leadSourceId: leadSource?.id,
          enquiryType,
          purchaseMode,
          financierId: financier?.id,
          exchange: hasExchange ? 'Yes' : 'No',
          buyingWhen: pick(['Immediately (Within 3 Days)', 'This Week', 'Within 15 Days']),
          remarks: hasExchange
            ? `Customer exchanging pre-owned two-wheeler at ${branch.name}.`
            : `Customer visited showroom floor interested in ${vehicle.name} in ${colourName}.`,
          status,
          createdAt: recordDate,
          updatedAt: recordDate,
        },
      });
      totalEnquiriesCreated++;

      // Quotation
      const prefix = isBigWing ? 'BWQ' : 'RWQ';
      branchQuoteSeq[branch.code] = (branchQuoteSeq[branch.code] || 100) + 1;
      const seqStr = String(branchQuoteSeq[branch.code]).padStart(5, '0');
      const quoteNumber = `${prefix}-${branch.code}-${seqStr}`;

      const exShowroom = Number(vehicle.exShowroomPrice);
      const roadTax = Math.round(exShowroom * 0.11);
      const insurance = Math.round(exShowroom * 0.058);
      const hypothecation = purchaseMode === 'Finance' ? 1500 : 0;
      const selectedAccs = accessories.slice(0, randInt(2, 4));
      const accessoriesTotal = selectedAccs.reduce((sum, a) => sum + Number(a.defaultPrice), 0);
      const grandTotal = exShowroom + roadTax + insurance + hypothecation + accessoriesTotal;

      await prisma.quotation.create({
        data: {
          quoteNumber,
          enquiryId: enquiry.id,
          branchId: branch.id,
          vehicleId: vehicle.id,
          colourName,
          exShowroom,
          roadTax,
          insurance,
          grandTotal,
          pdfR2Key: `quotes/${quoteNumber}.pdf`,
          createdAt: recordDate,
          items: {
            create: [
              { vehicleId: vehicle.id, label: 'Ex-Showroom Price', amount: exShowroom },
              { vehicleId: vehicle.id, label: 'RTO Road Tax & Registration (MH-12/MH-14)', amount: roadTax },
              { vehicleId: vehicle.id, label: 'Comprehensive Insurance (1 Year OD + 5 Year TP)', amount: insurance },
              ...(hypothecation > 0
                ? [{ vehicleId: vehicle.id, label: 'Bank Hypothecation Endorsement Charge', amount: hypothecation }]
                : []),
            ],
          },
          accessories: {
            create: selectedAccs.map((a) => ({
              accessoryId: a.id,
              amount: a.defaultPrice,
            })),
          },
        },
      });
      totalQuotesCreated++;

      // Follow-up
      const scheduledTime = new Date(now.getTime() + randInt(1, 3) * 24 * 60 * 60 * 1000);
      scheduledTime.setHours(randInt(11, 17), 30, 0, 0);
      await prisma.followUp.create({
        data: {
          enquiryId: enquiry.id,
          scheduledAt: scheduledTime,
          remarks: pick(followUpRemarksPool),
        },
      });
      totalFollowUpsCreated++;
    }

    // B. Generate Historical Data across past 60 days (~30-40 enquiries per branch)
    for (let dayOffset = totalDays; dayOffset >= 1; dayOffset--) {
      // 50% chance of 1 enquiry on a given day for this branch
      if (Math.random() > 0.55) continue;

      const rep = pick(branchReps);
      const vehicle = pick(branchVehicles);
      const colourName = vehicle.colours.length > 0 ? pick(vehicle.colours).colour.name : 'Black';

      const currentDate = new Date(now.getTime() - dayOffset * 24 * 60 * 60 * 1000);
      currentDate.setHours(randInt(9, 19), randInt(0, 59), randInt(0, 59), 0);

      const roll = Math.random();
      let status: EnquiryStatus;
      if (roll < 0.32) status = EnquiryStatus.CUSTOMER_BOUGHT;
      else if (roll < 0.75) status = EnquiryStatus.ACTIVE;
      else if (roll < 0.95) status = EnquiryStatus.CLOSED;
      else status = EnquiryStatus.RESOLVED;

      const firstName = pick(firstNames);
      const lastName = pick(lastNames);
      const customerName = `${firstName} ${lastName}`;
      const mobile = `98${randInt(10000000, 99999999)}`;
      const email = `${firstName.toLowerCase()}.${lastName.toLowerCase()}${randInt(10, 99)}@gmail.com`;
      const area = pick(areas);
      const leadSource = pick(leadSources);
      const purchaseMode = Math.random() < 0.6 ? 'Finance' : 'Cash';
      const financier = purchaseMode === 'Finance' && financiers.length > 0 ? pick(financiers) : null;
      const isWalkin = Math.random() < 0.7;
      const enquiryType = isWalkin ? 'Walk-in' : 'Telephonic Enquiry';
      const hasExchange = Math.random() < 0.25;

      const customer = await prisma.customer.create({
        data: {
          name: customerName,
          mobile,
          email,
          areaId: area?.id,
          address: `${area?.name || 'Hadapsar'}, Pune, Maharashtra`,
          createdAt: currentDate,
          updatedAt: currentDate,
        },
      });

      const enquiry = await prisma.enquiry.create({
        data: {
          branchId: branch.id,
          customerId: customer.id,
          createdById: rep.id,
          assignedToId: rep.id,
          leadSourceId: leadSource?.id,
          enquiryType,
          purchaseMode,
          financierId: financier?.id,
          exchange: hasExchange ? 'Yes' : 'No',
          buyingWhen: pick(['Immediately (Within 3 Days)', 'This Week', 'Within 15 Days', 'Festive Season', 'Next Month']),
          remarks: hasExchange
            ? `Customer exchanging pre-owned vehicle at ${branch.name}.`
            : `Enquiry recorded by ${rep.name} at ${branch.name}.`,
          status,
          createdAt: currentDate,
          updatedAt: currentDate,
        },
      });
      totalEnquiriesCreated++;

      // Quotation
      const prefix = isBigWing ? 'BWQ' : 'RWQ';
      branchQuoteSeq[branch.code] = (branchQuoteSeq[branch.code] || 100) + 1;
      const seqStr = String(branchQuoteSeq[branch.code]).padStart(5, '0');
      const quoteNumber = `${prefix}-${branch.code}-${seqStr}`;

      const exShowroom = Number(vehicle.exShowroomPrice);
      const roadTax = Math.round(exShowroom * 0.11);
      const insurance = Math.round(exShowroom * 0.058);
      const hypothecation = purchaseMode === 'Finance' ? 1500 : 0;
      const selectedAccs = accessories.slice(0, randInt(1, 3));
      const accessoriesTotal = selectedAccs.reduce((sum, a) => sum + Number(a.defaultPrice), 0);
      const grandTotal = exShowroom + roadTax + insurance + hypothecation + accessoriesTotal;

      await prisma.quotation.create({
        data: {
          quoteNumber,
          enquiryId: enquiry.id,
          branchId: branch.id,
          vehicleId: vehicle.id,
          colourName,
          exShowroom,
          roadTax,
          insurance,
          grandTotal,
          pdfR2Key: `quotes/${quoteNumber}.pdf`,
          createdAt: currentDate,
          items: {
            create: [
              { vehicleId: vehicle.id, label: 'Ex-Showroom Price', amount: exShowroom },
              { vehicleId: vehicle.id, label: 'RTO Road Tax & Registration (MH-12/MH-14)', amount: roadTax },
              { vehicleId: vehicle.id, label: 'Comprehensive Insurance (1 Year OD + 5 Year TP)', amount: insurance },
              ...(hypothecation > 0
                ? [{ vehicleId: vehicle.id, label: 'Bank Hypothecation Endorsement Charge', amount: hypothecation }]
                : []),
            ],
          },
          accessories: {
            create: selectedAccs.map((a) => ({
              accessoryId: a.id,
              amount: a.defaultPrice,
            })),
          },
        },
      });
      totalQuotesCreated++;

      // Follow-up
      const pastFollowUpDate = new Date(currentDate.getTime() + 2 * 24 * 60 * 60 * 1000);
      await prisma.followUp.create({
        data: {
          enquiryId: enquiry.id,
          scheduledAt: currentDate,
          completedAt: pastFollowUpDate,
          remarks: pick(followUpRemarksPool),
        },
      });
      totalFollowUpsCreated++;
    }
  }

  console.log(`
=== Multi-Branch Seeding Completed Successfully! ===
✓ Staffing Configured: 6 Branch Managers + 18 Sales Reps (1 BM + 3 Reps per Branch)
✓ PIN / Password for all staff: 123456
✓ Total Enquiries Generated: ${totalEnquiriesCreated}
✓ Total Quotations Generated: ${totalQuotesCreated}
✓ Total Follow-ups Generated: ${totalFollowUpsCreated}
✓ All 6 Branches covered across 60 days (including full live sessions for Today)
`);
}

main()
  .catch((e) => {
    console.error('Error during multi-branch seeding:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
