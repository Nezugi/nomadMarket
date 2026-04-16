#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import main as m

print("#!c=0")
print(f">{m.site_name} · Edit Listing")
print(m.nav_bar())
print("-")
print(f"`[<- Back`{m.page_path}/index.mu]")
print()

submitted = "field_token" in os.environ

if submitted:
    try:
        token = os.environ.get("field_token", "").strip()
        
        if not token:
            print("`Ff55Please enter your edit token.`f")
            print()
        else:
            # Validate token exists and isn't expired
            row = m.get_listing_by_token(token)
            if row:
                # Token is valid, redirect to edit page
                print("`F3a3Token accepted. Loading edit form...`f")
                print()
                print(f"`[Continue`{m.page_path}/edit.mu`token={token}]")
                sys.exit()
            else:
                print("`Ff55Invalid token or listing expired.`f")
                print()
    except Exception as ex:
        print(f"`Ff55Error: {ex}`f")
        print()

# ─── Enter Token Form ──────────────────────────────────────────────────────────
print(">>Edit Listing")
print()
print("`F777You received an edit token when you posted your listing.`f")
print("`F777Paste it below to edit or extend your listing.`f")
print()

print(">>Edit Token")
print("`F777Enter the 32-character token you saved:`f")
print("`B333`<40|token`>`b")
print()

print(f"`[Next`{m.page_path}/edit_ask.mu`*|action=submit]")
print()

m.print_footer()
