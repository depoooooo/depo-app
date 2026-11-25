"""فحص تشغيل: يفتح نسخة الويب بمتصفح حقيقي، يتنقّل بالشاشات، ويطبع الأخطاء والنصوص اللي على الشاشة."""
import asyncio, sys
from playwright.async_api import async_playwright

URL = 'https://depoooooo.github.io/depo-app/'

JS_TEXTS = """() => {
  const out = [];
  document.querySelectorAll('flt-semantics').forEach(e => {
    if (e.children.length && e.querySelector('flt-semantics')) return;
    const t = (e.getAttribute('aria-label') || e.innerText || '').trim();
    if (t && !out.includes(t)) out.push(t);
  });
  return out.slice(0, 90);
}"""

JS_CLICK = """(txt) => {
  const all = [...document.querySelectorAll('flt-semantics')];
  const exact = all.filter(e => (e.getAttribute('aria-label') || e.innerText || '').trim() === txt);
  const part = all.filter(e => (e.getAttribute('aria-label') || e.innerText || '').includes(txt));
  const el = (exact.length ? exact : part).pop();
  if (!el) return false;
  el.click();
  return true;
}"""

async def semantics(page):
    await page.evaluate("() => { const b = document.querySelector('flt-semantics-placeholder'); if (b) b.click(); }")
    await page.wait_for_timeout(700)

async def dump(page, label):
    await semantics(page)
    t = await page.evaluate(JS_TEXTS)
    print(f'===== {label}: {len(t)} items')
    for x in t:
        print('   |', x.replace('\n', ' / ')[:150])

async def tap(page, txt, wait=1800):
    await semantics(page)
    ok = await page.evaluate(JS_CLICK, txt)
    print(f'>>> tap «{txt}»: {"ok" if ok else "NOT FOUND"}')
    await page.wait_for_timeout(wait)
    return ok

async def run(phone, steps):
    async with async_playwright() as p:
        b = await p.chromium.launch()
        page = await b.new_page(viewport={'width': 400, 'height': 860})
        if phone:
            await page.add_init_script(f"localStorage.setItem('flutter.depo_phone', JSON.stringify('{phone}'));")
        page.on('console', lambda m: None if 'GL Driver' in m.text or m.type == 'debug' else print(f'[console.{m.type}] {m.text}'[:3000]))
        page.on('pageerror', lambda e: print(f'[PAGEERROR] {e}'[:3000]))
        await page.goto(URL + '?v=' + str(id(page)), wait_until='load')
        await page.wait_for_timeout(9000)
        await dump(page, 'HOME')
        for s in steps:
            if s.startswith('dump:'):
                await dump(page, s[5:])
            else:
                await tap(page, s)
        await b.close()

async def main():
    print('########## guest')
    await run('', [])
    print('########## owner: markets')
    await run('07704720344', ['حسابي', 'الأسواق', 'dump:MARKETS', 'مخلي', 'dump:SHOP PAGE', 'رجوع', 'ديوني عند المحلات', 'dump:MY DEBTS', 'رجوع',
                              'محلي', 'dump:MY SHOP', 'المنتجات', 'dump:PRODUCTS', 'الطلبات', 'dump:ORDERS', 'بيانات المحل', 'dump:SHOP FORM', 'رجوع',
                              'الزبائن والديون', 'طلب جديد', 'dump:NEW DEBT', 'رجوع', 'تسجيل دفعة', 'dump:PAYMENT'])

asyncio.run(main())
