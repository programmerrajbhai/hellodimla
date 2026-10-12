'use strict';

const { initializeApp } = require('firebase-admin/app');
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');

const {
  onCall,
  HttpsError,
} = require('firebase-functions/v2/https');
const {
  setGlobalOptions,
} = require('firebase-functions/v2');

const c = require('./core');

initializeApp();

const db = getFirestore();

setGlobalOptions({
  region: 'asia-south1',
  maxInstances: 5,
});

// Testing configuration.
// Public release requires client App Check setup + enforcement.
const ENFORCE_APP_CHECK = false;

function callable(handler) {
  return onCall(
    {
      enforceAppCheck: ENFORCE_APP_CHECK,
      timeoutSeconds: 60,
    },
    async request => {
      if (!request.auth) {
        throw new HttpsError(
          'unauthenticated',
          'Anonymous authentication প্রয়োজন।',
        );
      }

      try {
        return await handler(
          request.auth.uid,
          request.data ?? {},
          request,
        );
      } catch (error) {
        if (error instanceof c.Problem) {
          throw new HttpsError(
            error.code,
            error.message,
            error.details,
          );
        }

        if (error instanceof HttpsError) throw error;

        console.error(
          'Commerce operation failed',
          error.code ?? error.name,
        );

        throw new HttpsError(
          'internal',
          'Server উত্তর দেয়নি। একই attempt retry করুন।',
        );
      }
    },
  );
}

function productRefs(items) {
  return [...new Set(items.map(item => item.productId))]
    .map(id => db.doc(`products/${id}`));
}

async function readProducts(transaction, items) {
  const refs = productRefs(items);

  const documents = transaction
    ? await transaction.getAll(...refs)
    : await db.getAll(...refs);

  return Object.fromEntries(
    documents.map(document => [
      document.id,
      document.exists ? document.data() : null,
    ]),
  );
}

function intent(input) {
  return {
    requestId: c.id(input.requestId),
    items: c.cart(input.items),
    address: c.address(input.address),
    fingerprint: c.text(input.fingerprint, 64, 64),
  };
}

exports.validateCart = callable(async (_, input) => {
  const items = c.cart(input.items);
  const products = await readProducts(null, items);

  return { lines: c.validation(items, products) };
});

exports.quoteOrder = callable(async (_, input) => {
  const items = c.cart(input.items);
  const address = c.address(input.address);

  return db.runTransaction(
    async transaction => {
      const config = await transaction.get(
        db.doc('app_config/store'),
      );

      return c.quote(
        items,
        address,
        config.data(),
        await readProducts(transaction, items),
      );
    },
    { readOnly: true },
  );
});

exports.placeOrder = callable(async (uid, input) => {
  const payload = intent(input);
  const intentHash = c.hash(payload);

  const receiptRef = db.doc(
    `users/${uid}/order_requests/${payload.requestId}`,
  );

  const orderRef = db.collection('orders').doc(
    c.hash({ uid, requestId: payload.requestId }),
  );

  return db.runTransaction(async transaction => {
    const receipt = await transaction.get(receiptRef);

    const previous = c.receiptDecision(
      receipt.exists ? receipt.data() : null,
      intentHash,
    );

    if (previous) {
      return { orderId: previous, repeated: true };
    }

    const config = await transaction.get(
      db.doc('app_config/store'),
    );

    const products = await readProducts(
      transaction,
      payload.items,
    );

    const quote = c.quote(
      payload.items,
      payload.address,
      config.data(),
      products,
    );

    if (quote.fingerprint !== payload.fingerprint) {
      c.fail(
        'দাম বা delivery charge বদলেছে। নতুন total যাচাই করুন।',
        { quote, safeToAbandon: true },
      );
    }

    const now = Timestamp.now();

    for (const ref of productRefs(payload.items)) {
      const changed = c.mutateStock(
        products[ref.id],
        payload.items.filter(item => item.productId === ref.id),
        -1,
      );

      transaction.update(ref, {
        stockQty: changed.stockQty ?? 0,
        inStock: changed.inStock,
        variants: changed.variants,
        updatedAt: now,
      });
    }

    transaction.create(orderRef, {
      ...quote,
      ownerUid: uid,
      requestId: payload.requestId,
      orderNumber: `HD-${orderRef.id.substring(0, 12).toUpperCase()}`,
      createdAt: now,
      updatedAt: now,
      status: 'placed',
      paymentStatus: 'unpaid',
      statusHistory: [{ status: 'placed', at: now }],
      stockRestored: false,
    });

    transaction.create(receiptRef, {
      state: 'placed',
      orderId: orderRef.id,
      intentHash,
      createdAt: now,
    });

    return { orderId: orderRef.id, repeated: false };
  });
});

exports.abandonOrderAttempt = callable(async (uid, input) => {
  const ref = db.doc(
    `users/${uid}/order_requests/${c.id(input.requestId)}`,
  );

  return db.runTransaction(async transaction => {
    const receipt = await transaction.get(ref);

    if (
      receipt.exists &&
      receipt.data().state === 'placed'
    ) {
      return { orderId: receipt.data().orderId };
    }

    if (!receipt.exists) {
      transaction.create(ref, {
        state: 'abandoned',
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    return { abandoned: true };
  });
});

exports.cancelOrder = callable(async (uid, input) => {
  const ref = db.doc(`orders/${c.id(input.orderId)}`);
  const reason = c.text(input.reason, 2, 300);

  return db.runTransaction(async transaction => {
    const document = await transaction.get(ref);
    const order = document.data();

    if (!order || order.ownerUid !== uid) {
      throw new HttpsError(
        'permission-denied',
        'এই order-এর অনুমতি নেই।',
      );
    }

    if (order.status === 'cancelled') {
      return { cancelled: true };
    }

    if (order.status !== 'placed') {
      c.fail('Processing শুরু হয়েছে। Support-এ যোগাযোগ করুন।');
    }

    const products = await readProducts(
      transaction,
      order.lines,
    );

    const warnings = [];

    for (const productRef of productRefs(order.lines)) {
      const product = products[productRef.id];

      if (!product) {
        warnings.push(productRef.id);
        continue;
      }

      try {
        const changed = c.mutateStock(
          product,
          order.lines.filter(
            item => item.productId === productRef.id,
          ),
          1,
        );

        transaction.update(productRef, {
          stockQty: changed.stockQty ?? 0,
          variants: changed.variants,
          inStock: changed.inStock,
        });
      } catch (error) {
        if (!(error instanceof c.Problem)) throw error;
        warnings.push(productRef.id);
      }
    }

    const now = Timestamp.now();

    transaction.update(ref, {
      status: 'cancelled',
      cancellationReason: reason,
      cancelledAt: now,
      updatedAt: now,
      stockRestored: true,
      restockWarnings: warnings,
      statusHistory: [
        ...order.statusHistory,
        { status: 'cancelled', at: now },
      ],
    });

    return { cancelled: true };
  });
});

exports.createOrderIssue = callable(async (uid, input) => {
  const orderId = c.id(input.orderId);
  const requestId = c.id(input.requestId);
  const payload = c.issueInput(input);

  const ref = db.doc(
    `orders/${orderId}/issues/${requestId}`,
  );

  const attachmentPath = input.attachmentPath
    ? c.text(input.attachmentPath, 1, 500)
    : '';

  const expectedPath =
    `order_issue_images/${uid}/${orderId}/${requestId}/photo`;

  if (attachmentPath && attachmentPath !== expectedPath) {
    c.bad('Invalid photo path.');
  }

  if (attachmentPath) {
    const file = getStorage().bucket().file(attachmentPath);
    const [metadata] = await file.getMetadata();

    if (
      Number(metadata.size) > 5 * 1024 * 1024 ||
      !['image/jpeg', 'image/png', 'image/webp']
        .includes(metadata.contentType)
    ) {
      c.bad('Unsupported photo.');
    }

    const [bytes] = await file.download({
      start: 0,
      end: 11,
    });

    const jpeg =
      bytes[0] === 255 &&
      bytes[1] === 216 &&
      bytes[2] === 255;

    const png = bytes.subarray(0, 8).equals(
      Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    );

    const webp =
      bytes.toString('ascii', 0, 4) === 'RIFF' &&
      bytes.toString('ascii', 8, 12) === 'WEBP';

    if (!(jpeg || png || webp)) c.bad('Invalid image file.');
  }

  return db.runTransaction(async transaction => {
    const existing = await transaction.get(ref);
    const orderDocument = await transaction.get(
      db.doc(`orders/${orderId}`),
    );

    const order = orderDocument.data();

    if (!order || order.ownerUid !== uid) {
      throw new HttpsError(
        'permission-denied',
        'এই order-এর অনুমতি নেই।',
      );
    }

    const requestHash = c.hash({
      ...payload,
      attachmentPath,
    });

    if (existing.exists) {
      if (existing.data().requestHash !== requestHash) {
        c.bad('Request ID was already used.');
      }
      return { requestId };
    }

    if (
      payload.type === 'return' &&
      !c.canReturn(order, Date.now())
    ) {
      c.fail('Return-এর শর্ত পূরণ হয়নি। Support-এ যোগাযোগ করুন।');
    }

    transaction.create(ref, {
      ...payload,
      attachmentPath,
      requestHash,
      ownerUid: uid,
      createdAt: FieldValue.serverTimestamp(),
      requestStatus: 'pending',
      refundStatus: 'not_requested',
      refundMinor: 0,
      response: '',
    });

    return { requestId };
  });
});

// Trusted staff/admin application only.
exports.adminUpdateOrder = callable(async (_, input, request) => {
  if (request.auth.token.admin !== true) {
    throw new HttpsError(
      'permission-denied',
      'Admin access required.',
    );
  }

  const ref = db.doc(`orders/${c.id(input.orderId)}`);

  return db.runTransaction(async transaction => {
    const document = await transaction.get(ref);
    const order = document.data();

    if (!order) c.fail('Order not found.');

    const next = {
      placed: 'confirmed',
      confirmed: 'packing',
      packing: 'out_for_delivery',
      out_for_delivery: 'delivered',
    };

    if (order.status === input.status) {
      return { updated: true };
    }

    if (next[order.status] !== input.status) {
      c.fail('Invalid status transition.');
    }

    const now = Timestamp.now();

    const patch = {
      status: input.status,
      updatedAt: now,
      statusHistory: [
        ...order.statusHistory,
        { status: input.status, at: now },
      ],
    };

    if (input.status === 'delivered') {
      patch.deliveredAt = now;
      patch.paymentStatus =
        input.paymentCollected === true
          ? 'collected'
          : 'unpaid';
    }

    transaction.update(ref, patch);
    return { updated: true };
  });
});

exports.adminUpdateIssue = callable(async (_, input, request) => {
  if (request.auth.token.admin !== true) {
    throw new HttpsError(
      'permission-denied',
      'Admin access required.',
    );
  }

  if (
    !['pending', 'reviewing', 'approved', 'rejected', 'resolved']
      .includes(input.requestStatus)
  ) {
    c.bad('Invalid request status.');
  }

  if (
    !['not_requested', 'pending', 'paid', 'declined']
      .includes(input.refundStatus)
  ) {
    c.bad('Invalid refund status.');
  }

  if (
    ['pending', 'paid'].includes(input.refundStatus) &&
    !['approved', 'resolved'].includes(input.requestStatus)
  ) {
    c.bad('Refund needs approval.');
  }

  const amount = c.integer(input.refundMinor ?? 0);
  const response = c.text(input.response ?? '', 0, 2000);

  return db.runTransaction(async transaction => {
    const order = await transaction.get(
      db.doc(`orders/${c.id(input.orderId)}`),
    );

    const issueRef = db.doc(
      `orders/${input.orderId}/issues/${c.id(input.requestId)}`,
    );

    const issue = await transaction.get(issueRef);

    if (
      !order.exists ||
      !issue.exists ||
      amount > order.data().totalMinor
    ) {
      c.bad('Invalid refund amount.');
    }

    const previous = issue.data();

    if (
      previous.refundStatus === 'paid' &&
      (
        input.refundStatus !== 'paid' ||
        amount !== previous.refundMinor
      )
    ) {
      c.bad('A paid refund cannot be reversed or changed.');
    }

    const reserved = value =>
      ['pending', 'paid'].includes(value.refundStatus)
        ? value.refundMinor
        : 0;

    const committed =
      (order.data().refundCommittedMinor ?? 0) -
      reserved(previous) +
      reserved({
        refundStatus: input.refundStatus,
        refundMinor: amount,
      });

    if (committed < 0 || committed > order.data().totalMinor) {
      c.bad('Total refunds exceed this order payment.');
    }

    if (
      input.refundStatus === 'paid' &&
      order.data().paymentStatus !== 'collected'
    ) {
      c.bad('Confirm payment collection before recording a refund.');
    }

    transaction.update(order.ref, {
      refundCommittedMinor: committed,
    });

    transaction.update(issueRef, {
      requestStatus: input.requestStatus,
      refundStatus: input.refundStatus,
      refundMinor: amount,
      response,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return { updated: true };
  });
});

exports.adminRecordPayment = callable(async (_, input, request) => {
  if (request.auth.token.admin !== true) {
    throw new HttpsError(
      'permission-denied',
      'Admin access required.',
    );
  }

  return db.runTransaction(async transaction => {
    const ref = db.doc(`orders/${c.id(input.orderId)}`);
    const document = await transaction.get(ref);

    if (
      !document.exists ||
      document.data().status !== 'delivered'
    ) {
      c.fail('Record payment only for a delivered COD order.');
    }

    if (document.data().paymentStatus === 'collected') {
      return { recorded: true };
    }

    transaction.update(ref, {
      paymentStatus: 'collected',
      paymentRecordedAt: FieldValue.serverTimestamp(),
    });

    return { recorded: true };
  });
});