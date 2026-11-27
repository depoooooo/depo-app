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
    s = re.sub(r'android:label="[^"]*"', 'android:label="ديبو"', s, count=1)
    if "POST_NOTIFICATIONS" not in s:
        s = s.replace("<application", '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application', 1)
    for perm in ("ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION"):
        if perm not in s:
            s = s.replace("<application", f'<uses-permission android:name="android.permission.{perm}"/>\n    <application', 1)
    open(man, "w", encoding="utf-8").write(s)

# شاشة النظام قبل ما يفتح التطبيق: فيروزي ويه الأيقونة (بدل الأبيض)
res = os.path.join(ROOT, "android/app/src/main/res")
if os.path.isdir(res):
    os.makedirs(os.path.join(res, "values"), exist_ok=True)
    open(os.path.join(res, "values/depo_colors.xml"), "w", encoding="utf-8").write(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="depo_brand">#4BCDDB</color>\n</resources>\n')
    lb = ('<?xml version="1.0" encoding="utf-8"?>\n<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '    <item android:drawable="@color/depo_brand" />\n'
          '    <item><bitmap android:gravity="center" android:src="@mipmap/ic_launcher" /></item>\n</layer-list>\n')
    for dname in ("drawable", "drawable-v21"):
        dp = os.path.join(res, dname)
        if os.path.isdir(dp):
            open(os.path.join(dp, "launch_background.xml"), "w", encoding="utf-8").write(lb)
    v31 = os.path.join(res, "values-v31")
    os.makedirs(v31, exist_ok=True)
    open(os.path.join(v31, "styles.xml"), "w", encoding="utf-8").write(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">\n'
        '        <item name="android:windowSplashScreenBackground">@color/depo_brand</item>\n'
        '        <item name="android:windowSplashScreenAnimatedIcon">@mipmap/ic_launcher</item>\n'
        '    </style>\n'
        '    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">\n'
        '        <item name="android:windowBackground">@color/depo_brand</item>\n'
        '    </style>\n</resources>\n')

# Firebase يحتاج أندرويد 7 فما فوق (minSdk 24)
for g in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    gp = os.path.join(ROOT, g)
    if os.path.exists(gp):
        s = open(gp, encoding="utf-8").read()
        s = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", "minSdk = 24", s)
        open(gp, "w", encoding="utf-8").write(s)

# الإشعارات المحلية تحتاج desugaring بالأندرويد
gk = os.path.join(ROOT, "android/app/build.gradle.kts")
gg = os.path.join(ROOT, "android/app/build.gradle")
if os.path.exists(gk):
    s = open(gk, encoding="utf-8").read()
    if "isCoreLibraryDesugaringEnabled" not in s:
        s = s.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
        s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        open(gk, "w", encoding="utf-8").write(s)
elif os.path.exists(gg):
    s = open(gg, encoding="utf-8").read()
    if "coreLibraryDesugaringEnabled" not in s:
        s = s.replace("compileOptions {", "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
        s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
        open(gg, "w", encoding="utf-8").write(s)

# توقيع النسخة الرسمية (لمتجر Google Play): يشتغل بس إذا ملف key.properties موجود (ينكتب بالبناء من السر DEPO_KEY_PASS)
if os.path.exists(gk) and os.path.exists(os.path.join(ROOT, "android/key.properties")):
    s = open(gk, encoding="utf-8").read()
    if 'create("release")' not in s:
        cfg = (
            "android {\n"
            "    signingConfigs {\n"
            "        create(\"release\") {\n"
            "            val p = java.util.Properties().apply { load(java.io.FileInputStream(rootProject.file(\"key.properties\"))) }\n"
            "            keyAlias = p.getProperty(\"keyAlias\")\n"
            "            keyPassword = p.getProperty(\"keyPassword\")\n"
            "            storeFile = file(p.getProperty(\"storeFile\"))\n"
            "            storePassword = p.getProperty(\"storePassword\")\n"
            "        }\n"
            "    }\n"
        )
        s = s.replace("android {\n", cfg, 1)
        s = s.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')
        open(gk, "w", encoding="utf-8").write(s)
        print("release signing: ON")

# فحص lint بأندرويد يتعطل ويه إضافات Firebase، نطفيه وقت البناء (ما يأثر على التطبيق)
LINT_OFF = 'subprojects { tasks.matching { it.name.contains("lintVital") }.configureEach { enabled = false } }'
for g in ("android/build.gradle.kts", "android/build.gradle"):
    gp = os.path.join(ROOT, g)
    if os.path.exists(gp):
        s = open(gp, encoding="utf-8").read()
        if "lintVital" not in s:
            open(gp, "a", encoding="utf-8").write("\n" + LINT_OFF + "\n")

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
        m.update({"name": "ديبو", "short_name": "ديبو", "background_color": BRAND,
                  "theme_color": BRAND, "description": "رواجع المطاعم والماركت بأرخص سعر — الموصل",
                  "lang": "ar", "dir": "rtl"})
        json.dump(m, open(mf, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    ix = os.path.join(web, "index.html")
    if os.path.exists(ix):
        s = open(ix, encoding="utf-8").read()
        s = re.sub(r"<title>.*?</title>", "<title>ديبو</title>", s, flags=re.S)
        s = s.replace('content="depo"', 'content="ديبو"').replace('content="Depo"', 'content="ديبو"')
        s = re.sub(r'<meta name="description" content="[^"]*">',
                   '<meta name="description" content="رواجع المطاعم والماركت بأرخص سعر — الموصل">', s)
        if "depo-bg" not in s:
            s = s.replace("<body>", '<body style="background:#4BCDDB" class="depo-bg">', 1)
        if 'name="theme-color"' not in s:
            s = s.replace("</head>", f'  <meta name="theme-color" content="{BRAND}">\n</head>')
        open(ix, "w", encoding="utf-8").write(s)
print("branding applied")
