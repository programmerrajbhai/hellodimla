'use strict';

const {
  initializeApp,
  applicationDefault,
} = require('firebase-admin/app');

const {
  getFirestore,
  Timestamp,
} = require('firebase-admin/firestore');

const projectId = process.env.GCLOUD_PROJECT;

if (!projectId) {
  throw new Error('Set GCLOUD_PROJECT to your TEST project ID.');
}

initializeApp({
  credential: applicationDefault(),
  projectId,
});

const db = getFirestore();
const now = Timestamp.now();

const store = {
  enabled: true,
  demoMode: true,
  name: 'Hello Store',
  bannerTitle: 'পরীক্ষামূলক কেনাকাটা',
  bannerSubtitle: 'DEMO • শুধু নিজের test project-এর জন্য',
  supportPhone: '',
  discountBps: 0,
  policyVersion: 'demo-1',
  returnWindowDays: 7,
  deliveryPolicy:
    'পরীক্ষামূলক delivery। বাস্তব delivery নয়। '
    + 'প্রকাশের আগে বাস্তব সময়, চার্জ ও এলাকা দিন।',
  returnPolicy:
    'ডেমো policy: delivered হওয়ার ৭ দিনের মধ্যে আবেদন। '
    + 'Review এবং refund status আলাদা।',
  deliveryZones: [
    {
      id: 'dimla_test',
      label: 'ডিমলা — পরীক্ষা এলাকা',
      enabled: true,
      chargeMinor: 4000,
      minSubtotalMinor: 0,
      maxSubtotalMinor: 10000000,
    },
  ],
};

const products = [
  {
    id: 'demo_rice',
    name: 'ডেমো চাল',
    categoryId: 'grocery',
    categoryName: 'মুদি',
    unit: '১ কেজি প্যাকেট',
    priceMinor: 7500,
    originalPriceMinor: 8000,
    stockQty: 20,
    variants: [],
    featured: true,
  },
  {
    id: 'demo_tea',
    name: 'ডেমো চা',
    categoryId: 'grocery',
    categoryName: 'মুদি',
    unit: 'প্যাকেট',
    priceMinor: 12000,
    stockQty: 15,
    variants: [
      {
        id: '100g',
        name: '১০০ গ্রাম',
        unit: 'প্যাকেট',
        priceMinor: 12000,
        stockQty: 15,
        inStock: true,
      },
      {
        id: '200g',
        name: '২০০ গ্রাম',
        unit: 'প্যাকেট',
        priceMinor: 22000,
        stockQty: 10,
        inStock: true,
      },
    ],
    featured: true,
  },
  {
    id: 'demo_bottle',
    name: 'ডেমো পানির বোতল',
    categoryId: 'home',
    categoryName: 'ঘর ও জীবন',
    unit: 'পিস',
    priceMinor: 18000,
    stockQty: 12,
    variants: [],
    featured: false,
  },
  {
    id: 'demo_unavailable',
    name: 'ডেমো stock নেই',
    categoryId: 'home',
    categoryName: 'ঘর ও জীবন',
    unit: 'পিস',
    priceMinor: 9000,
    stockQty: 0,
    variants: [],
    featured: false,
  },
];

async function run() {
  await db.runTransaction(async transaction => {
    const storeRef = db.doc('app_config/store');

    const refs = products.map(
      product => db.doc(`products/${product.id}`),
    );

    const documents = await transaction.getAll(
      storeRef,
      ...refs,
    );

    if (!documents[0].exists) {
      transaction.create(storeRef, store);
    }

    products.forEach((product, index) => {
      if (documents[index + 1].exists) return;

      const { id, ...fields } = product;

      transaction.create(refs[index], {
        ...fields,
        published: true,
        inStock: product.stockQty > 0,
        imageUrl: '',
        images: [],
        description: 'শুধু app testing-এর ডেমো পণ্য।',
        createdAt: now,
      });
    });
  });

  console.log('Demo seed complete. Existing data preserved.');
}

run().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});