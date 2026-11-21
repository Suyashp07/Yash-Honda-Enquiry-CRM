const { Client } = require('pg');

async function seed() {
  const client = new Client({
    connectionString: 'postgresql://neondb_owner:npg_1GCLDp3wscWY@ep-shy-dawn-a14mdx3z-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require'
  });
  await client.connect();

  const branchRes = await client.query('SELECT id FROM "Branch" ORDER BY id ASC LIMIT 1;');
  const branchId = branchRes.rows[0].id;

  const repsRes = await client.query('SELECT id, name FROM "User" WHERE role=\'SALES_EXEC\';');
  const repMap = {};
  repsRes.rows.forEach(r => repMap[r.name] = r.id);

  const customers = [
    { name: 'Aditi Deshpande', mobile: '9822011111' },
    { name: 'Vijay Bhosale', mobile: '9822022222' },
    { name: 'Sanket Kale', mobile: '9822033333' },
    { name: 'Neha Joshi', mobile: '9822044444' },
    { name: 'Amit Deshmukh', mobile: '9822055555' },
    { name: 'Suyash Pandey', mobile: '9822066666' },
    { name: 'Rahul Pawar', mobile: '9822077777' },
  ];

  const custMap = {};
  for (const c of customers) {
    let res = await client.query('SELECT id FROM "Customer" WHERE name=$1;', [c.name]);
    if (res.rows.length === 0) {
      res = await client.query('INSERT INTO "Customer" (id, name, mobile, "createdAt", "updatedAt") VALUES (gen_random_uuid()::text, $1, $2, NOW(), NOW()) RETURNING id;', [c.name, c.mobile]);
    }
    custMap[c.name] = res.rows[0].id;
  }

  const vehRes = await client.query('SELECT id, name FROM "Vehicle";');
  const vehMap = {};
  vehRes.rows.forEach(v => vehMap[v.name] = v.id);

  const getVehId = (namePart) => {
    const k = Object.keys(vehMap).find(n => n.toLowerCase().includes(namePart.toLowerCase()));
    return k ? vehMap[k] : Object.values(vehMap)[0];
  };

  const protoSessions = [
    {
      repName: 'Aditya Deshmukh',
      custName: 'Aditi Deshpande',
      vehicleName: 'Activa 110 Dlx',
      vehSearch: 'Activa 110',
      timeUtc: '2026-11-21T03:30:00.000Z',
      status: 'ACTIVE',
      remarks: 'Quote · Prototype Seeding',
      quoteNum: 'QT-2026-0091'
    },
    {
      repName: 'Ajay Shinde',
      custName: 'Vijay Bhosale',
      vehicleName: 'Activa 110 Dlx',
      vehSearch: 'Activa 110',
      timeUtc: '2026-11-21T03:30:00.000Z',
      status: 'ACTIVE',
      remarks: 'Quote · Prototype Seeding',
      quoteNum: 'QT-2026-0092'
    },
    {
      repName: 'Ganesh Sawant',
      custName: 'Sanket Kale',
      vehicleName: 'Unicorn',
      vehSearch: 'Unicorn',
      timeUtc: '2026-11-21T04:00:00.000Z',
      status: 'CUSTOMER_BOUGHT',
      remarks: 'Booked · Prototype Seeding',
      quoteNum: 'QT-2026-0093'
    },
    {
      repName: 'Akshay Phadtare',
      custName: 'Neha Joshi',
      vehicleName: 'Dio 125',
      vehSearch: 'Dio 125',
      timeUtc: '2026-11-21T04:30:00.000Z',
      status: 'CUSTOMER_BOUGHT',
      remarks: 'Booked · Prototype Seeding',
      quoteNum: 'QT-2026-0094'
    },
    {
      repName: 'Ajay Shinde',
      custName: 'Amit Deshmukh',
      vehicleName: 'Shine 100',
      vehSearch: 'Shine',
      timeUtc: '2026-11-21T05:00:00.000Z',
      status: 'ACTIVE',
      remarks: 'In progress · Prototype Seeding',
      quoteNum: 'QT-2026-0095'
    },
    {
      repName: 'Aditya Deshmukh',
      custName: 'Suyash Pandey',
      vehicleName: 'SP 125 Disc',
      vehSearch: 'SP 125',
      timeUtc: '2026-11-21T06:00:00.000Z',
      status: 'ACTIVE',
      remarks: 'In progress · Prototype Seeding',
      quoteNum: 'QT-2026-0096'
    },
    {
      repName: 'Deepak Mane',
      custName: 'Rahul Pawar',
      vehicleName: 'Activa 110',
      vehSearch: 'Activa',
      timeUtc: '2026-11-21T07:00:00.000Z',
      status: 'ACTIVE',
      remarks: 'In progress · Prototype Seeding',
      quoteNum: 'QT-2026-0097'
    }
  ];

  // Clean old quotations & enquiries with remarks containing 'Prototype Seeding'
  await client.query('DELETE FROM "Quotation" WHERE "enquiryId" IN (SELECT id FROM "Enquiry" WHERE remarks LIKE \'%Prototype Seeding%\');');
  await client.query('DELETE FROM "Enquiry" WHERE remarks LIKE \'%Prototype Seeding%\';');

  for (const s of protoSessions) {
    const repId = repMap[s.repName];
    const custId = custMap[s.custName];
    const vehId = getVehId(s.vehSearch);

    const enqRes = await client.query(
      'INSERT INTO "Enquiry" (id, "branchId", "customerId", "assignedToId", "createdById", "enquiryType", status, "purchaseMode", "buyingWhen", remarks, "createdAt", "updatedAt") VALUES (gen_random_uuid()::text, $1, $2, $3, $3, \'Walk-in\', $4, \'Cash\', \'Immediate\', $5, $6, $6) RETURNING id;',
      [branchId, custId, repId, s.status, s.remarks, s.timeUtc]
    );
    const enqId = enqRes.rows[0].id;

    await client.query(
      'INSERT INTO "Quotation" (id, "quoteNumber", "enquiryId", "branchId", "vehicleId", "colourName", "exShowroom", "roadTax", "insurance", "grandTotal", "createdAt") VALUES (gen_random_uuid()::text, $1, $2, $3, $4, \'Pearl Siren Blue\', 85000, 9500, 6000, 100500, $5);',
      [s.quoteNum, enqId, branchId, vehId, s.timeUtc]
    );
  }

  console.log('Successfully seeded 7 prototype sessions for 2026-11-21 with exact IST slot timestamps!');
  await client.end();
}

seed().catch(console.error);
