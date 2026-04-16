#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import main as m

print("#!c=0")

cat  = os.environ.get("var_cat", "").strip()
name = m.get_category_name(cat) if cat else "Unknown Category"

print(f">{m.site_name} · {name}")
print(m.nav_bar())
print("-")
print(f"`[<- Back`{m.page_path}/index.mu]")
print()

# Get listings for this category
listings = m.get_listings(category=cat, limit=100)

if not listings:
    print("`F777No listings in this category.`f")
else:
    print(f">>Listings in {name}")
    print()
    
    # Group by type
    TYPE_ORDER = ["offer", "wanted", "trade", "free"]
    by_type = {t: [] for t in TYPE_ORDER}
    for row in listings:
        t = row[1]
        if t in by_type:
            by_type[t].append(row)
    
    # Display by type
    for t in TYPE_ORDER:
        rows = by_type[t]
        if not rows:
            continue
        label, color = m.TYPES[t]
        print(f">>>{color}{label}`f  ({len(rows)} item{'' if len(rows)==1 else 's'})")
        for row in rows:
            lid, typ, cat_slug, title, desc, price, lxmf, contact, token, visible, created, expires = row
            remaining = m.fmt_remaining(expires)
            price_str = f"  `F777{price[:30]}`f" if price else ""
            print(f"`[{title}`{m.page_path}/listing.mu`id={lid}]{price_str}  `F555{remaining}`f")
        print()

print()
m.print_footer()
