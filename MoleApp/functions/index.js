const functions = require("firebase-functions");
const admin = require("firebase-admin");
const Stripe = require("stripe");
const { Resend } = require("resend");
const ed25519 = require("@noble/ed25519");
const crypto = require("crypto");

admin.initializeApp();

// --- Config (set via: firebase functions:config:set stripe.secret="sk_..." stripe.webhook_secret="whsec_..." resend.key="re_..." license.private_key="BASE64_PRIVATE_KEY") ---
const stripeSecret = process.env.STRIPE_SECRET_KEY;
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
const resendKey = process.env.RESEND_API_KEY;
const privateKeyB64 = process.env.LICENSE_PRIVATE_KEY;

// @noble/ed25519 v2 needs a sync sha512 — use node crypto
ed25519.etc.sha512Sync = (...msgs) => {
  const hash = crypto.createHash("sha512");
  for (const m of msgs) hash.update(m);
  return hash.digest();
};

// --- Helpers ---

function base64urlEncode(buf) {
  return Buffer.from(buf)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function generateLicenseKey(email, privateKeyBytes) {
  const id = crypto.randomUUID().slice(0, 8);
  const exp = new Date();
  exp.setFullYear(exp.getFullYear() + 1);
  const expStr = exp.toISOString().split("T")[0];

  const payload = JSON.stringify({
    email,
    plan: "pro",
    exp: expStr,
    id,
  });

  const payloadBytes = new Uint8Array(Buffer.from(payload, "utf8"));
  const signature = ed25519.sign(payloadBytes, privateKeyBytes);

  return {
    key: base64urlEncode(payloadBytes) + "." + base64urlEncode(signature),
    exp: expStr,
  };
}

async function sendLicenseEmail(email, licenseKey, expDate) {
  const resend = new Resend(resendKey);

  await resend.emails.send({
    from: "MacMartin <noreply@krakelabsindia.com>",
    to: email,
    subject: "Your MacMartin Pro License Key",
    html: `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 600px; margin: 0 auto; padding: 40px 20px;">
        <h1 style="color: #1a1a1a; font-size: 24px;">Thank you for purchasing MacMartin Pro!</h1>
        <p style="color: #444; font-size: 16px; line-height: 1.6;">Here is your license key:</p>
        <div style="background: #f5f5f5; border: 1px solid #e0e0e0; border-radius: 8px; padding: 16px; margin: 20px 0; word-break: break-all; font-family: monospace; font-size: 14px;">
          ${licenseKey}
        </div>
        <p style="color: #444; font-size: 16px; line-height: 1.6;">
          <strong>To activate:</strong> Open MacMartin &rarr; click the paywall/upgrade prompt &rarr; paste the key above.
        </p>
        <p style="color: #888; font-size: 14px;">
          Valid until: ${expDate}<br>
          Licensed to: ${email}
        </p>
        <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
        <p style="color: #aaa; font-size: 12px;">Krake Labs India &mdash; krakelabsindia.com</p>
      </div>
    `,
  });
}

// --- Stripe Checkout Session Creator ---

exports.createCheckout = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const stripe = new Stripe(stripeSecret);

  const session = await stripe.checkout.sessions.create({
    payment_method_types: ["card"],
    line_items: [
      {
        price_data: {
          currency: "usd",
          product_data: {
            name: "MacMartin Pro",
            description: "Lifetime license for MacMartin — all-in-one Mac maintenance",
          },
          unit_amount: 999, // $9.99
        },
        quantity: 1,
      },
    ],
    mode: "payment",
    customer_email: req.body.email || undefined,
    success_url: "https://krakelabsindia.com/macmartin/success",
    cancel_url: "https://krakelabsindia.com/macmartin",
  });

  res.json({ url: session.url });
});

// --- Stripe Webhook Handler ---

exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const stripe = new Stripe(stripeSecret);

  let event;
  try {
    event = stripe.webhooks.constructEvent(
      req.rawBody,
      req.headers["stripe-signature"],
      webhookSecret
    );
  } catch (err) {
    console.error("Webhook signature verification failed:", err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object;
    const email = session.customer_email || session.customer_details?.email;

    if (!email) {
      console.error("No email found in checkout session");
      res.status(400).send("No email");
      return;
    }

    // Generate license key
    const privateKeyBytes = Buffer.from(privateKeyB64, "base64");
    const { key: licenseKey, exp } = generateLicenseKey(email, privateKeyBytes);

    // Store in Firestore for records
    await admin.firestore().collection("licenses").add({
      email,
      licenseKey,
      exp,
      stripeSessionId: session.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send email
    await sendLicenseEmail(email, licenseKey, exp);

    console.log(`License issued to ${email}, expires ${exp}`);
  }

  res.json({ received: true });
});
