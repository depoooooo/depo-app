// سيرفر ديبو على Cloudflare Workers:
// رمز التحقق عن طريق OTPIQ (واتساب ثم SMS) + هوية رسمية من Firebase (custom token)
// الأسرار (تنحط من لوحة Cloudflare، مو بالكود): OTPIQ_KEY, FB_CLIENT_EMAIL, FB_PRIVATE_KEY, REVIEW_CODE (اختياري)
// التخزين: KV باسم OTP_KV

const CODE_TTL = 5 * 60; // ثانية
const RESEND = 60;
const MAX_PER_HOUR = 5;
const MAX_TRIES = 5;

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};
const json = (obj, status = 200) => new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json; charset=utf-8', ...cors } });
const fail = (msg, status = 400) => json({ error: msg }, status);

function normPhone(p) {
  let s = String(p || '').replace(/[^\d]/g, '');
  if (s.startsWith('00964')) s = '0' + s.slice(5);
  else if (s.startsWith('964')) s = '0' + s.slice(3);
  else if (s.startsWith('7') && s.length === 10) s = '0' + s;
  return /^07\d{9}$/.test(s) ? s : null;
}

async function sha256(text) {
  const d = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function code6() {
  const a = new Uint32Array(1);
  crypto.getRandomValues(a);
  return String(a[0] % 1000000).padStart(6, '0');
}

// ---- Firebase custom token (JWT RS256 بمفتاح حساب الخدمة) ----
const b64url = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const b64urlStr = (s) => b64url(new TextEncoder().encode(s));

async function importKey(pem) {
  const body = pem.replace(/\\n/g, '\n').replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey('pkcs8', der, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
}

async function customToken(env, uid, claims) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: env.FB_CLIENT_EMAIL, sub: env.FB_CLIENT_EMAIL,
    aud: 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
    iat: now, exp: now + 3600, uid, claims,
  };
  const data = `${b64urlStr(JSON.stringify(header))}.${b64urlStr(JSON.stringify(payload))}`;
  const key = await importKey(env.FB_PRIVATE_KEY);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(data));
  return `${data}.${b64url(sig)}`;
}

async function send(env, body) {
  const phone = normPhone(body.phone);
  if (!phone) return fail('رقم الهاتف غير صحيح');
  const channel = body.channel === 'sms' ? 'sms' : 'whatsapp-sms';
  const now = Math.floor(Date.now() / 1000);
  const d = (await env.OTP_KV.get('otp:' + phone, 'json')) || {};
  // حساب مراجعة Google Play: رمز ثابت من الأسرار (REVIEW_CODE)، بدون رسالة وبدون حدود
  if (env.REVIEW_CODE && phone === (env.REVIEW_PHONE || '07500000001')) {
    const rc = String(env.REVIEW_CODE).trim();
    await env.OTP_KV.put('otp:' + phone, JSON.stringify({ codeHash: await sha256(`${phone}:${rc}:${env.FB_CLIENT_EMAIL}`), expiresAt: now + CODE_TTL, tries: 0, sentAt: 0 }), { expirationTtl: 3600 });
    return json({ ok: true, resendAfter: RESEND });
  }
  if (d.sentAt && now - d.sentAt < RESEND) return fail(`انتظر ${RESEND - (now - d.sentAt)} ثانية وجرّب`, 429);
  const hourStart = d.hourStart && now - d.hourStart < 3600 ? d.hourStart : now;
  const hourCount = hourStart === d.hourStart ? (d.hourCount || 0) : 0;
  if (hourCount >= MAX_PER_HOUR) return fail('طلبت رموز هوايه. جرّب بعد ساعة', 429);

  const code = code6();
  const r = await fetch('https://api.otpiq.com/api/sms', {
    method: 'POST',
    headers: { Authorization: `Bearer ${String(env.OTPIQ_KEY || '').trim()}`, 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({ phoneNumber: '964' + phone.slice(1), smsType: 'verification', verificationCode: code, provider: channel }),
  });
  if (!r.ok) {
    console.log('OTPIQ error', r.status, (await r.text()).slice(0, 300));
    return fail('ما كدرنا نرسل الرمز هسه. جرّب بعد شوية', 502);
  }
  await env.OTP_KV.put('otp:' + phone, JSON.stringify({
    codeHash: await sha256(`${phone}:${code}:${env.FB_CLIENT_EMAIL}`), expiresAt: now + CODE_TTL, tries: 0, sentAt: now, hourStart, hourCount: hourCount + 1,
  }), { expirationTtl: 3600 });
  return json({ ok: true, resendAfter: RESEND });
}

async function verify(env, body) {
  const phone = normPhone(body.phone);
  const code = String(body.code || '').replace(/\D/g, '');
  if (!phone) return fail('رقم الهاتف غير صحيح');
  const key = 'otp:' + phone;
  const d = await env.OTP_KV.get(key, 'json');
  const now = Math.floor(Date.now() / 1000);
  if (!d || !d.codeHash || now > d.expiresAt || d.tries >= MAX_TRIES) {
    if (d) await env.OTP_KV.put(key, JSON.stringify({ ...d, codeHash: null }), { expirationTtl: 3600 });
    return fail('الرمز انتهى. اطلب رمز جديد', 410);
  }
  if (d.codeHash !== (await sha256(`${phone}:${code}:${env.FB_CLIENT_EMAIL}`))) {
    await env.OTP_KV.put(key, JSON.stringify({ ...d, tries: d.tries + 1 }), { expirationTtl: 3600 });
    return fail('الرمز غلط', 403);
  }
  await env.OTP_KV.put(key, JSON.stringify({ ...d, codeHash: null }), { expirationTtl: 3600 }); // يستخدم مرة وحدة
  return json({ token: await customToken(env, 'ph_' + phone, { phone }) });
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
    if (request.method !== 'POST') return json({ ok: true, service: 'depo' });
    let body = {};
    try { body = await request.json(); } catch (_) { return fail('طلب غير صالح'); }
    const path = new URL(request.url).pathname;
    try {
      if (path.endsWith('/send')) return await send(env, body);
      if (path.endsWith('/verify')) return await verify(env, body);
      return fail('مسار غير معروف', 404);
    } catch (e) {
      console.log('error', String(e));
      return fail('صار خطأ بالسيرفر', 500);
    }
  },
};
