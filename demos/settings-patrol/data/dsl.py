"""Tiny DSL for the GitHub settings recreation. Each helper returns a control dict; ids are
assigned from the page id plus a slug of the label when the page is built."""
import json, re

def _c(type, label, desc="", **extra):
    c = {"type": type, "label": label, "description": desc}
    c.update({k: v for k, v in extra.items() if v is not None})
    return c

def T(label, desc="", value="", placeholder=""): return _c("text", label, desc, value=value, placeholder=placeholder)
def TA(label, desc="", value="", placeholder=""): return _c("textarea", label, desc, value=value, placeholder=placeholder)
def SEL(label, options, desc="", value=None): return _c("select", label, desc, options=options, value=value or options[0])
def R(label, options, desc="", value=None): return _c("radio", label, desc, options=options, value=value or options[0])
def CB(label, desc="", value=False): return _c("checkbox", label, desc, value=value)
def TG(label, desc="", value=False): return _c("toggle", label, desc, value=value)
def B(label, desc=""): return _c("button", label, desc)
def DB(label, desc=""): return _c("danger-button", label, desc)
def L(label, items, desc=""): return _c("list", label, desc, items=items)
def LK(label, desc=""): return _c("link", label, desc)
def I(label, desc=""): return _c("info", label, desc)

def S(title, controls, desc="", danger=False):
    return {"title": title, "description": desc, "danger": danger, "controls": controls}

def P(id, title, path, icon, sections):
    return {"id": id, "title": title, "path": path, "icon": icon, "sections": sections}

def G(id, title, pages): return {"id": id, "title": title, "pages": pages}

def slug(text): return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:40]

def build(scope, title, groups, out):
    from summaries import ABOUT
    seen = set()
    count = 0
    for g in groups:
        for p in g["pages"]:
            p["about"] = ABOUT.get(p["id"], "")
            if not p["about"]:
                print("missing summary:", p["id"])
            for s in p["sections"]:
                for c in s["controls"]:
                    base = f'{p["id"]}-{slug(c["label"])}'
                    cid, n = base, 2
                    while cid in seen:
                        cid, n = f"{base}-{n}", n + 1
                    seen.add(cid)
                    c["id"] = cid
                    c["section"] = s["title"]
                    count += 1
    doc = {"scope": scope, "title": title, "groups": groups}
    with open(out, "w") as f:
        json.dump(doc, f, indent=1)
    pages = sum(len(g["pages"]) for g in groups)
    print(f"{out}: {pages} pages, {count} controls")
