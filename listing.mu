#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import main as m

print("#!c=0")

try:
    lid = int(os.environ.get("var_id", "0"))
except ValueError:
    lid = 0

row = m.get_listing(lid) if lid else None

if not row:
    m.print_header()
    print(m.nav_bar())
    print("-")
    print("`Ff55Listing not found or expired.`f")
    print()
    print(f"`[<- Back`{m.page_path}/index.mu]")
    sys.exit()

lid, typ, cat, title, desc, price, lxmf, contact, token, visible, created, expires = row
remaining  = m.fmt_remaining(expires)
type_label, type_color = m.TYPES.get(typ, ("?", "`F777"))
cat_name   = m.get_category_name(cat)

m.print_header()
print(m.nav_bar())
print("-")
print(f"`[<- Back`{m.page_path}/index.mu]")
print()

print(f">>{type_color}{type_label}`f  {title}")
print()

print(f"`F777Category:`f  {cat_name}")
if price:
    print(f"`F777Price/Offer:`f  {price}")
print(f"`F777Posted:`f  {m.fmt_date(created)}")
print(f"`F777Expires:`f  {remaining}")
print()

if desc:
    print(">>Description")
    print(desc)
    print()

print(">>Contact")
if lxmf:
    lxmf_display = m.lxmf_link(lxmf)
    print(f"`F4beLXMF:`f  {lxmf_display}")
if contact:
    print(f"`F777Info:`f  {contact}")
if not lxmf and not contact:
    print("`F777No contact provided.`f")

print()

print(">>Edit This Listing")
print("`F777Have your edit token? Paste it here:`f")
print(f"`[Edit Listing`{m.page_path}/edit_ask.mu]")

print()
m.print_footer()
