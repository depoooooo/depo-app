// سيرفر ديبو: رمز التحقق عن طريق OTPIQ (واتساب ثم SMS) + هوية رسمية من Firebase
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();
const OTPIQ_KEY = defineSecret('OTPIQ_KEY');

const REGION = 'europe-west1';
const CODE_TTL_MS = 5 * 60 * 1000; // الرمز صالح 5 دقايق
const RESEND_MS = 60 * 1000; // دقيقة بين كل إرسال
const MAX_PER_HOUR = 5; // أكثر شي 5 رموز بالساعة لنفس الرقم
const MAX_TRIES = 5; // 5 محاولات غلط وينلغي الرمز

// 07XXXXXXXXX فقط (أرقام العراق)
function normPhone(p) {
  let s = String(p || '').replace(/[^\d]/g, '');
  if (s.startsWith('00964')) s = '0' + s.slice(5);
  else if (s.startsWith('964')) s = '0' + s.slice(3);
  else if (s.startsWith('7') && s.length === 10) s = '0' + s;
  if (!/^07\d{9}$/.test(s)) throw new HttpsError('invalid-argument', 'رقم الهاتف غير صحيح');
  return s;
}
const hash = (phone, code) => crypto.createHash('sha256').update(`${phone}:${code}:depo`).digest('hex');

exports.sendOtp = onCall({ region: REGION, secrets: [OTPIQ_KEY], maxInstances: 5 }, async (req) => {
  const phone = normPhone(req.data && req.data.phone);
  const channel = req.data && req.data.channel === 'sms' ? 'sms' : 'whatsapp-sms';
  const ref = db.collection('otp').doc(phone);
  const now = Date.now();
  const snap = await ref.get();
  const d = snap.exists ? snap.data() : {};
  if (d.sentAt && now - d.sentAt < RESEND_MS) {
    throw new HttpsError('resource-exhausted', `انتظر ${Math.ceil((RESEND_MS - (now - d.sentAt)) / 1000)} ثانية وجرّب`);
  }
  const hour = (d.hourStart && now - d.hourStart < 3600000) ? d : { hourStart: now, hourCount: 0 };
  if (hour.hourCount >= MAX_PER_HOUR) throw new HttpsError('resource-exhausted', 'طلبت رموز هوايه. جرّب بعد ساعة');

  const code = String(crypto.randomInt(0, 1000000)).padStart(6, '0');
  const res = await fetch('https://api.otpiq.com/api/sms', {
    method: 'POST',
    headers: { Authorization: `Bearer ${OTPIQ_KEY.value()}`, 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({ phoneNumber: '964' + phone.slice(1), smsType: 'verification', verificationCode: code, provider: channel }),
  });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    console.error('OTPIQ error', res.status, body.slice(0, 300));
    throw new HttpsError('unavailable', 'ما كدرنا نرسل الرمز هسه. جرّب بعد شوية');
  }
  await ref.set({
    codeHash: hash(phone, code), expiresAt: now + CODE_TTL_MS, tries: 0, sentAt: now,
    hourStart: hour.hourStart, hourCount: hour.hourCount + 1,
  });
  return { ok: true, resendAfter: RESEND_MS / 1000 };
});

exports.verifyOtp = onCall({ region: REGION, maxInstances: 5 }, async (req) => {
  const phone = normPhone(req.data && req.data.phone);
  const code = String((req.data && req.data.code) || '').replace(/\D/g, '');
  const ref = db.collection('otp').doc(phone);
  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return 'none';
    const d = snap.data();
    if (Date.now() > d.expiresAt) { tx.delete(ref); return 'expired'; }
    if (d.tries >= MAX_TRIES) { tx.delete(ref); return 'locked'; }
    if (d.codeHash !== hash(phone, code)) { tx.update(ref, { tries: d.tries + 1 }); return 'wrong'; }
    tx.delete(ref);
    return 'ok';
  });
  if (result === 'wrong') throw new HttpsError('permission-denied', 'الرمز غلط');
  if (result !== 'ok') throw new HttpsError('deadline-exceeded', 'الرمز انتهى. اطلب رمز جديد');
  const token = await admin.auth().createCustomToken('ph_' + phone, { phone });
  return { token };
});
