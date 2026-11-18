#!/usr/bin/env python3
"""Render current Data4 HTML screens to a full-image PowerPoint (visual fidelity)."""
import os, sys, time, pathlib, shutil, json
from pptx import Presentation
from pptx.util import Inches
from pptx.enum.shapes import MSO_SHAPE
from PIL import Image
from playwright.sync_api import sync_playwright

ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT / "exports"
IMAGES=OUT / "screenshots"
OUT.mkdir(exist_ok=True, parents=True)
IMAGES.mkdir(exist_ok=True, parents=True)
W,H=1920,1080
url="https://guillemarley.github.io/data4_reporting_experience/"
P=Presentation()
P.slide_width=Inches(13.333333)
P.slide_height=Inches(7.5)
blank=P.slide_layouts[6]
def addshot(path):
    slide=P.slides.add_slide(blank)
    slide.shapes.add_picture(str(path), 0, 0, width=P.slide_width, height=P.slide_height)
    return slide
def image_slide(path,title,url=None):
    slide=addshot(path)
    if url:
        slide.shapes[0].click_action.hyperlink.address=url
    if title:
        slide.notes_slide.notes_text_frame.text=title

def fit_image(source,dest):
    im=Image.open(source).convert("RGB")
    canvas=Image.new("RGB",(W,H),"#f4f6f9")
    im.thumbnail((W,H),Image.Resampling.LANCZOS)
    canvas.paste(im,((W-im.width)//2,(H-im.height)//2))
    canvas.save(dest,quality=92)

with sync_playwright() as engine:
    browser_exe=shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chromium-browser")
    kwargs={"headless":True,"args":["--no-sandbox","--disable-dev-shm-usage"]}
    if browser_exe: kwargs["executable_path"]=browser_exe
    try: browser=engine.chromium.launch(**kwargs)
    except Exception:
        import subprocess
        subprocess.check_call([sys.executable,"-m","playwright","install","chromium"])
        browser=engine.chromium.launch(headless=True,args=["--no-sandbox"])
    context=browser.new_context(viewport={"width":W,"height":H},device_scale_factor=1,locale="es-ES")
    page=context.new_page()
    path=ROOT/"presentation.html"
    page.goto(path.resolve().as_uri(),wait_until="domcontentloaded",timeout=60000)
    page.wait_for_timeout(1400)
    n=page.locator("section.slide").count()
    assert n>=15, f"Expected 16 HTML slides, found {n}"
    ids=page.locator("section.slide").evaluate_all("(els)=>els.map(e=>e.id)")
    for i in range(n):
        slide=page.locator("section.slide").nth(i)
        slide.scroll_into_view_if_needed(timeout=15000)
        page.wait_for_timeout(350)
        slide.screenshot(path=str(IMAGES/f"presentation_{i+1:02d}.png"),timeout=30000,animations="disabled")
    # Interactive Audience: expose existing phase switcher strictly for static capture
    a=(ROOT/"audience.html").read_text(encoding="utf8")
    a=a.replace("})();\n</script>\n</body>", "window.__export_phase=applyPhase;\n})();\n</script>\n</body>")
    (ROOT/"audience_visual_export.html").write_text(a,encoding="utf8")
    aud=context.new_page()
    aud.set_viewport_size({"width":1440,"height":900})
    aud.goto((ROOT/"audience_visual_export.html").resolve().as_uri(),wait_until="domcontentloaded",timeout=60000)
    aud.wait_for_timeout(850)
    for name,phase in [
        ("01_bienvenida","lobby"),
        ("02_contadores_a_mano","asis"),
        ("03_excel_lecturas","asis"),
        ("04_BMS_manual","improve"),
        ("05_Power_Apps","control"),
        ("06_operation_book_automatico","results")]:
        try:
            aud.evaluate("(p)=>window.__export_phase(p)",phase)
            aud.wait_for_timeout(350)
            if name=="03_excel_lecturas":
                aud.locator("details.asis-optional-excel").evaluate("(e)=>{e.open=true;e.scrollIntoView()}")
            if name=="06_operation_book_automatico":
                aud.locator("#obAutofillBtn").click(timeout=3000)
            if name=="02_contadores_a_mano":
                aud.evaluate("window.scrollTo(0,0)")
            snap=IMAGES/("audience_"+name+".png")
            aud.screenshot(path=str(snap),full_page=True,animations="disabled")
        except Exception as ex:
            print("Audience screenshot failed",name,repr(ex),flush=True)
            # Preserve the stage in the export even if its mock interaction fails
            aud.screenshot(path=str(IMAGES/("audience_"+name+".png")),full_page=True)
    browser.close()

for i in range(n):
    p=IMAGES/f"presentation_{i+1:02d}.png"
    fit_image(p, IMAGES/f"frame_{i+1:02d}.jpg")
    image_slide(IMAGES/f"frame_{i+1:02d}.jpg",f"Presentation HTML · {ids[i]}",url+"presentation.html")
for name,title in [
    ("01_bienvenida","Audience · Bienvenida"),
    ("02_contadores_a_mano","Audience · Lectura manuscrita"),
    ("03_excel_lecturas","Audience · Excel manual"),
    ("04_BMS_manual","Audience · BMS y Operation Book manual"),
    ("05_Power_Apps","Audience · Power Apps"),
    ("06_operation_book_automatico","Audience · Excel automático")]:
    p=IMAGES/("audience_"+name+".png")
    dest=IMAGES/("audience_frame_"+name+".jpg")
    fit_image(p,dest)
    image_slide(dest,title,url+"audience.html")
dest=OUT/"Data4_HTML_replica_visual.pptx"
P.save(dest)
print(json.dumps({"slides":len(P.slides),"output":str(dest),"size":dest.stat().st_size}),flush=True)
