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
  'Ashwini', 'Akshay', 'Tanvi', 'Abhishek', 'Sheetal', 'Kailash', 'Jyoti', 'Chetan'
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
  'Follow-up call completed: customer confirmed booking for Diwali delivery.',
  'Informed customer about festive cashback offer and zero processing fee on Honda Finance.',
  'Customer visited with spouse; decided on Activa 6G DLX with premium accessories package.'
];

async function main() {
  console.log('=== Starting Yash Honda 2-Month Comprehensive Seeder ===');

  // 1. Fetch Master Data
  const branches = await prisma.branch.findMany({ where: { status: 'Active' } });
  if (branches.length === 0) {
    console.error('No branches found. Please run base seed.ts first.');
    return;
  }
  const branchMap = new Map(branches.map((b) => [b.code, b]));

  const vehicles = await prisma.vehicle.findMany({
    include: { colours: { include: { colour: true } }, modelGroup: true },
  });
  if (vehicles.length === 0) {
    console.error('No vehicles found. Please run base seed.ts first.');
    return;
  }

  const salesReps = await prisma.user.findMany({
    where: { role: Role.SALES_EXEC, status: 'Active' },
    include: { userBranches: true },
  });
  if (salesReps.length === 0) {
    console.error('No sales executives found. Please run base seed.ts first.');
    return;
  }

  const financiers = await prisma.financier.findMany({ where: { status: 'Active' } });
  const leadSources = await prisma.leadSource.findMany({ where: { status: 'Active' } });
  const areas = await prisma.area.findMany({ where: { status: 'Active' } });
  const accessories = await prisma.accessory.findMany({ where: { status: 'Active' } });

  console.log(`Loaded Master Data:
  • Branches: ${branches.length}
  • Vehicles: ${vehicles.length}
  • Sales Reps: ${salesReps.length}
  • Financiers: ${financiers.length}
  • Lead Sources: ${leadSources.length}
  • Areas: ${areas.length}
  • Accessories: ${accessories.length}
  `);

  // Target time window: 60 days up to Today
  const now = new Date();
  const totalDays = 60;
  let totalEnquiriesCreated = 0;
  let totalQuotesCreated = 0;
  let totalFollowUpsCreated = 0;

  // Global sequence tracker for unique quote numbers per branch
  const branchQuoteSeq: Record<string, number> = {};
  for (const b of branches) {
    const existingQuotesCount = await prisma.quotation.count({ where: { branchId: b.id } });
    branchQuoteSeq[b.code] = existingQuotesCount + 200;
  }

  // Generate day by day
  for (let dayOffset = totalDays; dayOffset >= 0; dayOffset--) {
    const isToday = dayOffset === 0;
    // For past days, generate 2 to 4 enquiries per day across Pune
    // For today, generate 12 to 16 enquiries so the live showroom floor dashboard is full of activity!
    const dailyCount = isToday ? randInt(12, 16) : randInt(2, 4);

    const currentDate = new Date(now.getTime() - dayOffset * 24 * 60 * 60 * 1000);

    for (let i = 0; i < dailyCount; i++) {
      // Pick branch
      const branch = pick(branches);
      const isBigWing = branch.wing === 'BigWing';

      // Pick suitable vehicle for branch wing
      const suitableVehicles = vehicles.filter((v) =>
        isBigWing ? v.modelGroup.name === 'BigWing' : v.modelGroup.name === 'RedWing',
      );
      const vehicle = suitableVehicles.length > 0 ? pick(suitableVehicles) : pick(vehicles);

      // Pick vehicle colour
      const colourName = vehicle.colours.length > 0 ? pick(vehicle.colours).colour.name : 'Pearl Night White';

      // Pick sales rep assigned to this branch, or any sales rep as fallback
      const branchReps = salesReps.filter((r) => r.userBranches.some((ub) => ub.branchId === branch.id));
      const rep = branchReps.length > 0 ? pick(branchReps) : pick(salesReps);

      // Customer details
      const firstName = pick(firstNames);
      const lastName = pick(lastNames);
      const customerName = `${firstName} ${lastName}`;
      const mobile = `98${randInt(10000000, 99999999)}`;
      const email = `${firstName.toLowerCase()}.${lastName.toLowerCase()}${randInt(10, 99)}@gmail.com`;
      const area = pick(areas);
      const leadSource = pick(leadSources);
      const purchaseMode = Math.random() < 0.6 ? 'Finance' : 'Cash';
      const financier = purchaseMode === 'Finance' && financiers.length > 0 ? pick(financiers) : null;
      const isWalkin = Math.random() < 0.72;
      const enquiryType = isWalkin ? 'Walk-in' : 'Telephonic Enquiry';
      const hasExchange = Math.random() < 0.28;

      // Set timestamp within current day
      let hour: number;
      let minute: number;
      if (isToday) {
        // Today: distribute across morning & afternoon/evening up to current hour
        const currentHour = now.getHours();
        hour = randInt(9, Math.max(10, Math.min(20, currentHour)));
        minute = randInt(0, 59);
      } else {
        hour = randInt(9, 20);
        minute = randInt(0, 59);
      }
      const recordDate = new Date(currentDate);
      recordDate.setHours(hour, minute, randInt(0, 59), 0);

      // Determine Enquiry Status
      let status: EnquiryStatus;
      if (isToday) {
        // Today: mostly ACTIVE with live sessions, plus a few Booked
        status = Math.random() < 0.25 ? EnquiryStatus.CUSTOMER_BOUGHT : EnquiryStatus.ACTIVE;
      } else if (dayOffset <= 7) {
        // Last 7 days: ~25% Booked, ~60% Active in pipeline, ~10% Closed, ~5% other
        const roll = Math.random();
        if (roll < 0.28) status = EnquiryStatus.CUSTOMER_BOUGHT;
        else if (roll < 0.85) status = EnquiryStatus.ACTIVE;
        else status = EnquiryStatus.CLOSED;
      } else {
        // Older than 7 days: ~30% Booked, ~45% Active, ~20% Closed, ~5% Resolved
        const roll = Math.random();
        if (roll < 0.32) status = EnquiryStatus.CUSTOMER_BOUGHT;
        else if (roll < 0.75) status = EnquiryStatus.ACTIVE;
        else if (roll < 0.95) status = EnquiryStatus.CLOSED;
        else status = EnquiryStatus.RESOLVED;
      }

      // Create Customer
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

      // Create Enquiry
      const exchangeVehicles = ['Hero Splendor Plus', 'Honda Activa 3G', 'TVS Jupiter 110', 'Bajaj Pulsar 150', 'Honda Dio BS4'];
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
            ? `Customer exchanging pre-owned ${pick(exchangeVehicles)} in good running condition.`
            : `Customer interested in ${vehicle.name} in ${colourName}.`,
          status,
          createdAt: recordDate,
          updatedAt: recordDate,
        },
      });
      totalEnquiriesCreated++;

      // Create Quotation
      const prefix = isBigWing ? 'BWQ' : 'RWQ';
      branchQuoteSeq[branch.code] = (branchQuoteSeq[branch.code] || 100) + 1;
      const seqStr = String(branchQuoteSeq[branch.code]).padStart(5, '0');
      const quoteNumber = `${prefix}-${branch.code}-${seqStr}`;

      const exShowroom = Number(vehicle.exShowroomPrice);
      const roadTax = Math.round(exShowroom * 0.11); // 11% Pune RTO
      const insurance = Math.round(exShowroom * 0.058); // ~5.8% 1+4 yr comprehensive insurance
      const hypothecation = purchaseMode === 'Finance' ? 1500 : 0;

      // Pick 2-3 random accessories
      const selectedAccs = accessories.slice(0, randInt(2, 4));
      const accessoriesTotal = selectedAccs.reduce((sum, a) => sum + Number(a.defaultPrice), 0);
      const grandTotal = exShowroom + roadTax + insurance + hypothecation + accessoriesTotal;

      const quotation = await prisma.quotation.create({
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

      // Create Follow-ups
      // If today or recent, create a pending follow-up due today or tomorrow
      if (isToday || dayOffset <= 2) {
        const scheduledTime = new Date(now.getTime() + (Math.random() < 0.5 ? 0 : 1) * 24 * 60 * 60 * 1000);
        scheduledTime.setHours(randInt(11, 18), 30, 0, 0);

        await prisma.followUp.create({
          data: {
            enquiryId: enquiry.id,
            scheduledAt: scheduledTime,
            remarks: pick(followUpRemarksPool),
          },
        });
        totalFollowUpsCreated++;
      } else {
        // Historical follow-up (completed)
        const pastFollowUpDate = new Date(recordDate.getTime() + 2 * 24 * 60 * 60 * 1000);
        await prisma.followUp.create({
          data: {
            enquiryId: enquiry.id,
            scheduledAt: recordDate,
            completedAt: pastFollowUpDate,
            remarks: pick(followUpRemarksPool),
          },
        });
        totalFollowUpsCreated++;
      }

      // If telephonic, create a Call record
      if (!isWalkin) {
        await prisma.call.create({
          data: {
            enquiryId: enquiry.id,
            employeeId: rep.id,
            branchId: branch.id,
            employeePhone: rep.mobile,
            customerPhone: customer.mobile,
            startedAt: recordDate,
            endedAt: new Date(recordDate.getTime() + randInt(60, 300) * 1000),
            durationSeconds: randInt(45, 240),
            status: 'completed',
            recordingStatus: 'completed',
            createdAt: recordDate,
          },
        });
      }
    }
  }

  console.log(`
=== Yash Honda 2-Month Seeder Finished Successfully! ===
✓ Total Enquiries Generated: ${totalEnquiriesCreated}
✓ Total Quotations Generated: ${totalQuotesCreated}
✓ Total Follow-ups Generated: ${totalFollowUpsCreated}
✓ Date Span: Last 60 Days (including active sessions for Today)
✓ All 6 Showrooms Covered (BigWing Phursungi + 5 RedWing branches)
✓ Rich mix of Walk-in & Telephonic, Cash & Finance (HDFC, Bajaj, Tata, IDFC, ICICI)
✓ Booking Tokens, Active Pipelines, Lost/Other Dealer, and Trade-in Exchanges
`);
}

main()
  .catch((e) => {
    console.error('Error during 2-month seeding:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
