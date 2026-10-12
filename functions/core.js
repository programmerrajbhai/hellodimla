'use strict';

const { createHash } = require('node:crypto');

class Problem extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

function fail(message, details) {
  throw new Problem('failed-precondition', message, details);
}

function bad(message) {
  throw new Problem('invalid-argument', message);
}

function id(value) {
  if (
    typeof value !== 'string' ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(value)
  ) {
    bad('Invalid identifier.');
  }

  return value;
}

function text(value, min, max) {
  if (
    typeof value !== 'string' ||
    value.trim().length < min ||
    value.trim().length > max
  ) {
    bad('Invalid text length.');
  }

  return value.trim();
}

function integer(value, min = 0, max = 1000000000) {
  if (
    !Number.isSafeInteger(value) ||
    value < min ||
    value > max
  ) {
    bad('Invalid numeric value.');
  }

  return value;
}

function address(input) {
  if (!input || typeof input !== 'object') {
    bad('Delivery address is required.');
  }

  const phone = String(input.phone ?? '')
    .replace(/[০-৯]/g, n => '০১২৩৪৫৬৭৮৯'.indexOf(n))
    .replace(/[\s()-]/g, '')
    .replace(/^\+88/, '');

  if (!/^01[3-9]\d{8}$/.test(phone)) {
    bad('Enter a valid Bangladesh mobile number.');
  }

  return {
    name: text(input.name, 2, 80),
    phone,
    zoneId: id(input.zoneId),
    address: text(input.address, 8, 400),
    landmark: text(input.landmark ?? '', 0, 160),
    note: text(input.note ?? '', 0, 300),
  };
}

function cart(input) {
  if (
    !Array.isArray(input) ||
    !input.length ||
    input.length > 50
  ) {
    bad('Cart must contain 1–50 lines.');
  }

  const seen = new Set();

  return input
    .map(value => {
      const item = {
        productId: id(value.productId),
        variantId: value.variantId ? id(value.variantId) : '',
        qty: integer(value.qty, 1, 99),
      };

      const key = `${item.productId}:${item.variantId}`;

      if (seen.has(key)) bad('Duplicate cart line.');

      seen.add(key);
      return item;
    })
    .sort((a, b) =>
      `${a.productId}:${a.variantId}`.localeCompare(
        `${b.productId}:${b.variantId}`,
      ),
    );
}

function hash(value) {
  return createHash('sha256')
    .update(JSON.stringify(value))
    .digest('hex');
}

function selection(product, variantId) {
  if (!product || product.published !== true) {
    fail('পণ্যটি এখন পাওয়া যাচ্ছে না।');
  }

  const variants = Array.isArray(product.variants)
    ? product.variants
    : [];

  let selected = product;

  if (variants.length) {
    selected = variants.find(
      variant =>
        variant.id === variantId &&
        variant.published !== false,
    );

    if (!selected) fail('সঠিক variant নির্বাচন করুন।');
  } else if (variantId) {
    fail('এই variant আর পাওয়া যাচ্ছে না।');
  }

  const priceMinor = integer(selected.priceMinor, 1, 100000000);
  const stockQty = integer(selected.stockQty, 0, 10000000);

  if (
    product.inStock === false ||
    selected.inStock === false
  ) {
    fail('পণ্যটি stock-এ নেই।');
  }

  return { selected, priceMinor, stockQty, variants };
}

function line(item, product) {
  const selected = selection(product, item.variantId);

  if (item.qty > selected.stockQty) {
    fail('পর্যাপ্ত stock নেই।');
  }

  return {
    ...item,
    name: text(product.name, 1, 160),
    variantName: item.variantId
      ? text(selected.selected.name, 1, 80)
      : '',
    unit: text(
      selected.selected.unit ?? product.unit ?? 'পিস',
      1,
      30,
    ),
    imageUrl: String(
      selected.selected.imageUrl ?? product.imageUrl ?? '',
    ),
    priceMinor: selected.priceMinor,
    stockQty: selected.stockQty,
    subtotalMinor: selected.priceMinor * item.qty,
  };
}

function validation(items, products) {
  return items.map(item => {
    try {
      return {
        ...line(item, products[item.productId]),
        valid: true,
        message: '',
      };
    } catch (error) {
      if (!(error instanceof Problem)) throw error;

      return {
        ...item,
        valid: false,
        message: error.message,
      };
    }
  });
}

function quote(items, delivery, config, products) {
  if (!config || config.enabled !== true) {
    fail('Store এখন অর্ডার নিচ্ছে না।');
  }

  const zone = (config.deliveryZones ?? []).find(
    entry =>
      entry.id === delivery.zoneId &&
      entry.enabled === true,
  );

  if (!zone) fail('এই এলাকায় delivery চালু নেই।');

  const lines = items.map(item =>
    line(item, products[item.productId]),
  );

  const subtotalMinor = lines.reduce(
    (total, item) => total + item.subtotalMinor,
    0,
  );

  integer(subtotalMinor, 1, 500000000);

  if (subtotalMinor < integer(zone.minSubtotalMinor ?? 0)) {
    fail('Minimum order পূরণ হয়নি।');
  }

  if (
    subtotalMinor >
    integer(zone.maxSubtotalMinor ?? 500000000)
  ) {
    fail('Maximum order অতিক্রম করেছে।');
  }

  const deliveryMinor = integer(zone.chargeMinor, 0, 10000000);

  const discountMinor = Math.floor(
    subtotalMinor *
      integer(config.discountBps ?? 0, 0, 10000) /
      10000,
  );

  const result = {
    lines,
    address: {
      ...delivery,
      zoneLabel: text(zone.label, 1, 80),
    },
    subtotalMinor,
    deliveryMinor,
    discountMinor,
    totalMinor: subtotalMinor + deliveryMinor - discountMinor,
    paymentMethod: 'cod',
    policyVersion: String(config.policyVersion ?? '1'),
    returnWindowDays: integer(
      config.returnWindowDays ?? 7,
      0,
      90,
    ),
    demoMode: config.demoMode === true,
    deliveryPolicy: text(config.deliveryPolicy ?? '', 0, 4000),
    returnPolicy: text(config.returnPolicy ?? '', 0, 4000),
    supportPhone: String(config.supportPhone ?? ''),
  };

  const agreement = {
    ...result,
    lines: lines.map(({ stockQty, ...rest }) => rest),
  };

  return {
    ...result,
    fingerprint: hash(agreement),
  };
}

function mutateStock(product, allocations, direction) {
  const result = {
    ...product,
    variants: (product.variants ?? []).map(
      variant => ({ ...variant }),
    ),
  };

  for (const item of allocations) {
    const selected = item.variantId
      ? result.variants.find(
          variant => variant.id === item.variantId,
        )
      : result;

    if (
      !selected ||
      (item.variantId === '' && result.variants.length)
    ) {
      fail('Stock structure বদলেছে।');
    }

    selected.stockQty =
      integer(selected.stockQty, 0, 10000000) +
      direction * item.qty;

    integer(selected.stockQty, 0, 10000000);

    if (direction < 0 && selected.stockQty === 0) {
      selected.inStock = false;
    }

    if (direction > 0 && selected.stockQty > 0) {
      selected.inStock = true;
    }
  }

  if (result.variants.length) {
    result.inStock = result.variants.some(
      variant =>
        variant.stockQty > 0 &&
        variant.inStock !== false,
    );
  }

  return result;
}

function receiptDecision(receipt, intentHash) {
  if (!receipt) return null;

  if (receipt.state === 'abandoned') {
    fail('Attempt বন্ধ হয়েছে। নতুন করে order করুন।');
  }

  if (receipt.intentHash !== intentHash) {
    bad('Do not reuse a request ID with different data.');
  }

  return receipt.orderId;
}

function issueInput(input) {
  if (!['issue', 'return'].includes(input.type)) {
    bad('Invalid request type.');
  }

  return {
    type: input.type,
    reason: text(input.reason, 2, 120),
    description: text(input.description ?? '', 0, 2000),
  };
}

function canReturn(order, now) {
  return (
    order.status === 'delivered' &&
    order.deliveredAt &&
    now <=
      order.deliveredAt.toMillis() +
        order.returnWindowDays * 86400000
  );
}

module.exports = {
  Problem,
  fail,
  bad,
  id,
  text,
  integer,
  address,
  cart,
  hash,
  line,
  validation,
  quote,
  mutateStock,
  receiptDecision,
  issueInput,
  canReturn,
};