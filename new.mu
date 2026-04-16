#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import main as m

print("#!c=0")
print(f">{m.site_name} · Post Listing")
print(m.nav_bar())
print("-")
print(f"`[<- Back`{m.page_path}/index.mu]")
print()

submitted = os.environ.get("var_action", "") == "submit" or "field_title" in os.environ

if submitted:
    try:
        typ         = os.environ.get("field_type", "").strip()
        cat         = os.environ.get("field_cat", "").strip()
        title       = os.environ.get("field_title", "").strip()
        description = os.environ.get("field_desc", "").strip()
        price       = os.environ.get("field_price", "").strip()
        lxmf        = m.validate_lxmf(os.environ.get("field_lxmf", ""))
        contact     = os.environ.get("field_contact", "").strip()

        errors = []
        if typ not in m.TYPES:
            errors.append("Please select a type (Offer / Wanted / Trade / Free).")
        cats = [s for s, n in m.get_categories()]
        if cat not in cats:
            errors.append("Please select a category.")
        if not title:
            errors.append("Title is required.")
        if not contact and not lxmf:
            errors.append("Please provide either LXMF address or contact info.")

        if errors:
            for e in errors:
                print(f"`Ff55{e}`f")
            print()
        else:
            lid, token = m.create_listing(typ, cat, title, description, price, lxmf, contact)
            print("`F3a3Listing posted successfully!`f")
            print()
            print(f"`[View Listing`{m.page_path}/listing.mu`id={lid}]")
            print()
            print(">>Save Your Edit Token!")
            print("`Ff55This token is shown only once.`f")
            print("Use it to edit or extend your listing:")
            print()
            print(f"`!{token}`!")
            print()
            print(f"`F777Save it: {m.page_path}/edit_ask.mu`f")
            sys.exit()
    except Exception as ex:
        print(f"`Ff55Error: {ex}`f")
        print()

# ─── Form ──────────────────────────────────────────────────────────────────────
print(">>Type")
for slug, (label, color) in m.TYPES.items():
    print(f"`<^|type|{slug}`>  {color}{label}`f")
print()

print(">>Category")
for slug, name in m.get_categories():
    print(f"`<^|cat|{slug}`>  {name}")
print()

print(">>Title")
print("`F777max. 60 characters`f")
print("`B333`<40|title`>`b")
print()

print(">>Description `F777(optional)`f")
print("`F777max. 400 characters`f")
print("`B333`<50|desc`>`b")
print()

print(">>Price / Offer `F777(optional)`f")
print("`F777e.g. '5kg potatoes', 'OBO', '2h help'`f")
print("`B333`<32|price`>`b")
print()

print(">>Contact")
print("`F777LXMF Address (optional, 32 hex chars):`f")
print("`B333`<32|lxmf`>`b")
print()
print("`F777Contact Info (optional, free text):`f")
print("`F777e.g. node hash, meeting place, time`f")
print("`B333`<40|contact`>`b")
print()

print(f"`[Post Listing`{m.page_path}/new.mu`*|action=submit]")
print()

m.print_footer()
