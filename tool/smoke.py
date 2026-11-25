"""فحص تشغيل: يفتح نسخة الويب بمتصفح حقيقي ويطبع الأخطاء والنصوص اللي على الشاشة."""
import asyncio, sys
from playwright.async_api import async_playwright

URL = sys.argv[1] if len(sys.argv) > 1 else 'https://depoooooo.github.io/depo-app/'

async def texts(page):
    return await page.evaluate("""() => {
      const out = [];
      document.querySelectorAll('flt-semantics, [role], flt-semantics-container *').forEach(e => {
        const t = (e.getAttribute('aria-label') || e.innerText || '').trim();
        if (t && !out.includes(t)) out.push(t);
      });
      return out.slice(0, 80);
    }""")

async def main():
    for phone in ('', '07704720344'):
        print(f'########## SCENARIO phone={phone or "guest"}')
        await run(phone)

async def run(phone):
    async with async_playwright() as p:
        b = await p.chromium.launch()
        page = await b.new_page(viewport={'width': 400, 'height': 860})
        if phone:
            await page.add_init_script(f"localStorage.setItem('flutter.depo_phone', JSON.stringify('{phone}'));")
        page.on('console', lambda m: print(f'[console.{m.type}] {m.text}'[:2000]))
        page.on('pageerror', lambda e: print(f'[PAGEERROR] {e}'[:2000]))
        page.on('requestfailed', lambda r: print(f'[REQFAIL] {r.url[:150]} {r.failure}'))
        await page.goto(URL + '?v=' + str(asyncio.get_event_loop().time()), wait_until='load')
        for sec in (6, 14, 25):
            await page.wait_for_timeout((sec - (0 if sec == 6 else {14: 6, 25: 14}[sec])) * 1000)
            try:
                await page.evaluate("() => { const b = document.querySelector('flt-semantics-placeholder'); if (b) b.click(); }")
            except Exception as e:
                print('semantics click failed', e)
            await page.wait_for_timeout(800)
            t = await texts(page)
            print(f'===== SCREEN after {sec}s: {len(t)} items')
            for x in t:
                print('   |', x.replace('\n', ' / ')[:160])
        await b.close()

asyncio.run(main())
