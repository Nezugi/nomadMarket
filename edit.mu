#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import main as m

print("#!c=0")
print(f">{m.site_name} · Edit Listing")
print(m.nav_bar())
print("-")

token = os.environ.get("var_token", "").strip()

if not token:
    print("`Ff55No token provided.`f")
    print(f"`[<- Back`{m.page_path}/index.mu]")
    sys.exit()

row = m.get_listing_by_token(token)
if not row:
    print("`Ff55Invalid token or listing already expired.`f")
    print(f"`[<- Back`{m.page_path}/index.mu]")
    sys.exit()

lid, typ, cat, title, desc, price, lxmf, contact, etoken, visible, created, expires = row

print(f"`[<- Back to Listing`{m.page_path}/listing.mu`id={lid}]")
print()

# ─── Handle Submit ─────────────────────────────────────────────────────────────
action = os.environ.get("var_action", "")
delete_action = action == "delete"
save_action   = action == "save" or "field_title" in os.environ

if delete_action:
    m.delete_by_token(token)
    print("`F3a3Listing deleted.`f")
    print()
    print(f"`[Back to Market`{m.page_path}/index.mu]")
    sys.exit()

if save_action:
    try:
        new_title   = os.environ.get("field_title", "").strip()
        new_desc    = os.environ.get("field_desc", "").strip()
        new_price   = os.environ.get("field_price", "").strip()
        new_lxmf    = m.validate_lxmf(os.environ.get("field_lxmf", ""))
        new_contact = os.environ.get("field_contact", "").strip()
        extend      = os.environ.get("field_extend", "") == "yes"

        errors = []
        if not new_title:
            errors.append("Title is required.")
        if not new_contact and not new_lxmf:
            errors.append("Please provide LXMF address or contact info.")

        if errors:
            for e in errors:
                print(f"`Ff55{e}`f")
            print()
        else:
            ok = m.update_listing(token, new_title, new_desc, new_price, new_lxmf, new_contact, extend)
            if ok:
                msg = " Expiry extended by 7 days." if extend else ""
                print(f"`F3a3Saved.{msg}`f")
                print()
                print(f"`[View Listing`{m.page_path}/listing.mu`id={lid}]")
                sys.exit()
            else:
                print("`Ff55Save failed.`f")
                print()
    except Exception as ex:
        print(f"`Ff55Error: {ex}`f")
        print()
    # Reload fresh data after save
    row = m.get_listing_by_token(token)
    if row:
        lid, typ, cat, title, desc, price, lxmf, contact, etoken, visible, created, expires = row

# ─── Edit Form (Pre-filled) ───────────────────────────────────────────────────
remaining = m.fmt_remaining(expires)
type_label, type_color = m.TYPES.get(typ, ("?", "`F777"))
cat_name = m.get_category_name(cat)

print(f"`F777Type:`f  {type_color}{type_label}`f  `F777Category:`f  {cat_name}")
print(f"`F777Expires:`f  {remaining}")
print()

print(">>Title")
print(f"`B333`<40|title`{title}>`b")
print()

print(">>Description")
print("`F777max. 400 characters`f")
print(f"`B333`<50|desc`{desc}>`b")
print()

print(">>Price / Offer")
print(f"`B333`<32|price`{price}>`b")
print()

print(">>Contact")
print("`F777LXMF Address:`f")
print(f"`B333`<32|lxmf`{lxmf}>`b")
print()
print("`F777Contact Info:`f")
print(f"`B333`<40|contact`{contact}>`b")
print()

print(">>Expiry")
print(f"`F777Currently: {remaining}`f")
print(f"`<?|extend|yes`>  Extend by {m.EXPIRE_DAYS} days (from now)")
print()

print(">>Actions")
print(f"`[Save Changes`{m.page_path}/edit.mu`*|action=save|token={token}]")
print(f"  `[Delete Listing`{m.page_path}/edit.mu`*|action=delete|token={token}]")
print()

m.print_footer()
