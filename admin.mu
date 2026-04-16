#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import main as m

print("#!c=0")

token = os.environ.get("var_session", "")
if not m.check_admin_session(token):
    print(f">{m.site_name} · Admin")
    print("`Ff55Not logged in.`f")
    print(f"`[Login`{m.page_path}/admin_login.mu]")
    sys.exit()

print(f">{m.site_name} · Admin Panel")
print(m.nav_bar(token))
print("-")

# ─── Handle Actions ───────────────────────────────────────────────────────────
action = os.environ.get("var_action", "")

if action == "delete":
    try:
        lid = int(os.environ.get("var_id", "0"))
        m.admin_delete_listing(lid)
        print("`F3a3Listing deleted.`f")
        print()
    except Exception as ex:
        print(f"`Ff55Error: {ex}`f")

elif action == "hide":
    try:
        lid = int(os.environ.get("var_id", "0"))
        m.admin_toggle_visible(lid, 0)
        print("`F777Listing hidden.`f")
        print()
    except Exception as ex:
        print(f"`Ff55Error: {ex}`f")

elif action == "show":
    try:
        lid = int(os.environ.get("var_id", "0"))
        m.admin_toggle_visible(lid, 1)
        print("`F3a3Listing shown.`f")
        print()
    except Exception as ex:
        print(f"`Ff55Error: {ex}`f")

elif action == "add_cat":
    try:
        slug = os.environ.get("field_slug", "").strip().lower().replace(" ", "_")
        name = os.environ.get("field_catname", "").strip()
        if slug and name:
            ok = m.add_category(slug, name)
            if ok:
                print("`F3a3Category created.`f")
            else:
                print("`Ff55Slug already exists.`f")
        else:
            print("`Ff55Slug and name are required.`f")
        print()
    except Exception as ex:
        print(f"`Ff55Error: {ex}`f")

elif action == "del_cat":
    try:
        slug = os.environ.get("var_slug", "")
        ok = m.delete_category(slug)
        if ok:
            print("`F3a3Category deleted.`f")
        else:
            print("`Ff55Category has listings — delete them first.`f")
        print()
    except Exception as ex:
        print(f"`Ff55Error: {ex}`f")

# ─── All Listings ──────────────────────────────────────────────────────────────
print(">>All Listings")
all_rows = m.admin_get_all(include_hidden=True)
if not all_rows:
    print("`F777No listings.`f")
else:
    for row in all_rows:
        lid, typ, cat, title, desc, price, lxmf, contact, etoken, visible, created, expires = row
        remaining = m.fmt_remaining(expires)
        type_label, type_color = m.TYPES.get(typ, ("?", "`F777"))
        vis_str = "" if visible else "  `Ff55[hidden]`f"
        print(f"{type_color}[{type_label}]`f  {title}{vis_str}  `F555{remaining}`f")

        # Admin actions — keep token in links
        print(f"`[Delete`{m.page_path}/admin.mu`action=delete|id={lid}|session={token}]")
        if visible:
            print(f"  `[Hide`{m.page_path}/admin.mu`action=hide|id={lid}|session={token}]")
        else:
            print(f"  `[Show`{m.page_path}/admin.mu`action=show|id={lid}|session={token}]")
        print(f"  `[View`{m.page_path}/listing.mu`id={lid}]")
        print()

print("-")
print(">>Manage Categories")

cats = m.get_categories()
if cats:
    for slug, name in cats:
        print(f"{name}")
        print(f"`[Delete`{m.page_path}/admin.mu`action=del_cat|slug={slug}|session={token}]")
        print()

print(">>Add Category")
print("`F777Slug (lowercase, no spaces):`f")
print("`B333`<24|slug`>`b")
print()
print("`F777Name (display name):`f")
print("`B333`<32|catname`>`b")
print()
print(f"`[Create`{m.page_path}/admin.mu`*|action=add_cat|session={token}]")
print()

m.print_footer()
