"""ينسخ أيقونات Depo واسمه لملفات أندرويد والويب بعد ما يولّدها flutter create."""
import json, os, re, shutil

B = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(B)
BRAND = "#4BCDDB"

# أندرويد
for d in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
    dst = os.path.join(ROOT, f"android/app/src/main/res/mipmap-{d}/ic_launcher.png")
    if os.path.isdir(os.path.dirname(dst)):
        shutil.copy(os.path.join(B, f"ic_launcher-{d}.png"), dst)
man = os.path.join(ROOT, "android/app/src/main/AndroidManifest.xml")
if os.path.exists(man):
    s = open(man, encoding="utf-8").read()
    s = re.sub(r'android:label="[^"]*"', 'android:label="Depo"', s, count=1)
    open(man, "w", encoding="utf-8").write(s)

# الويب
web = os.path.join(ROOT, "web")
if os.path.isdir(web):
    os.makedirs(os.path.join(web, "icons"), exist_ok=True)
    for n in ("Icon-192.png", "Icon-512.png", "Icon-maskable-192.png", "Icon-maskable-512.png"):
        shutil.copy(os.path.join(B, n), os.path.join(web, "icons", n))
    shutil.copy(os.path.join(B, "favicon.png"), os.path.join(web, "favicon.png"))
    mf = os.path.join(web, "manifest.json")
    if os.path.exists(mf):
        m = json.load(open(mf, encoding="utf-8"))
        m.update({"name": "Depo — ديبو", "short_name": "Depo", "background_color": BRAND,
                  "theme_color": BRAND, "description": "رواجع المطاعم والماركت بأرخص سعر — الموصل",
                  "lang": "ar", "dir": "rtl"})
        json.dump(m, open(mf, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    ix = os.path.join(web, "index.html")
    if os.path.exists(ix):
        s = open(ix, encoding="utf-8").read()
        s = re.sub(r"<title>.*?</title>", "<title>Depo — ديبو</title>", s, flags=re.S)
        s = s.replace('content="depo"', 'content="Depo"')
        s = re.sub(r'<meta name="description" content="[^"]*">',
                   '<meta name="description" content="رواجع المطاعم والماركت بأرخص سعر — الموصل">', s)
        if 'name="theme-color"' not in s:
            s = s.replace("</head>", f'  <meta name="theme-color" content="{BRAND}">\n</head>')
        open(ix, "w", encoding="utf-8").write(s)
print("branding applied")
