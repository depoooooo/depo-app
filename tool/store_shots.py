"""يلتقط صور شاشة للمتجر (1080x1920) من نسخة الويب المبنية محلياً."""
import asyncio, sys, os
from playwright.async_api import async_playwright

BASE = 'http://localhost:8099/depo-app/'
OUT = sys.argv[1]

CLICK = """(txt) => { const all=[...document.querySelectorAll('flt-semantics')];
 const ex=all.filter(e=>(e.getAttribute('aria-label')||e.innerText||'').trim()===txt);
 const el=(ex.length?ex:all.filter(e=>(e.getAttribute('aria-label')||e.innerText||'').includes(txt))).pop();
 if(!el) return false; el.click(); return true; }"""

async def sem(p):
    await p.evaluate("() => { const b=document.querySelector('flt-semantics-placeholder'); if(b) b.click(); }")
    await p.wait_for_timeout(600)

async def main():
    os.makedirs(OUT, exist_ok=True)
    async with async_playwright() as pw:
        b = await pw.chromium.launch()
        ctx = await b.new_context(viewport={'width': 360, 'height': 640}, device_scale_factor=3, locale='ar')
        p = await ctx.new_page()
        await p.goto(BASE, wait_until='load')
        await p.wait_for_timeout(14000)
        await p.screenshot(path=f'{OUT}/shot1.png')
        await sem(p)
        steps = [('الماركت', 'shot2'), ('الأقسام', 'shot3'), ('حسابي', 'shot4')]
        for t, n in steps:
            await sem(p)
            ok = await p.evaluate(CLICK, t)
            print(t, ok)
            await p.wait_for_timeout(3500)
            await p.screenshot(path=f'{OUT}/{n}.png')
        await sem(p)
        await p.evaluate(CLICK, 'الرئيسية'); await p.wait_for_timeout(2500)
        await p.mouse.wheel(0, 700); await p.wait_for_timeout(2500)
        await p.screenshot(path=f'{OUT}/shot5.png')
        await b.close()

asyncio.run(main())
