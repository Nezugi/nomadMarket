#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import main as m

print("#!c=0")
m.print_header()
print(m.nav_bar())
print("-")

cats     = m.get_category_counts()
listings = m.get_listings(limit=20)

# ─── Categories ───────────────────────────────────────────────────────────────
print(">>Browse by Category")
for slug, name, count in cats:
    if count == 0:
        print(f"`F555{name} (0)`f")
    else:
        print(f"`[{name} ({count})`{m.page_path}/category.mu`cat={slug}]")

print()
print("-")

# ─── Recent Listings ──────────────────────────────────────────────────────────
print(">>Recent Listings")
if not listings:
    print("`F777No listings yet.`f")
else:
    TYPE_ORDER = ["offer", "wanted", "trade", "free"]
    by_type = {t: [] for t in TYPE_ORDER}
    for row in listings:
        t = row[1]
        if t in by_type:
            by_type[t].append(row)

    for t in TYPE_ORDER:
        rows = by_type[t]
        if not rows:
            continue
        label, color = m.TYPES[t]
        print(f">>>{color}{label}`f")
        for row in rows:
            lid, typ, cat, title, desc, price, lxmf, contact, token, visible, created, expires = row
            remaining = m.fmt_remaining(expires)
            cat_name  = m.get_category_name(cat)
            price_str = f"  `F777{price[:30]}`f" if price else ""
            print(f"`[{title}`{m.page_path}/listing.mu`id={lid}]{price_str}  `F555{cat_name} · {remaining}`f")
        print()

print("<")
m.print_footer()
