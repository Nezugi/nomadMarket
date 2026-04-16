#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import main as m

print("#!c=0")
print(f">{m.site_name} · Admin Login")
print(f"`[<- Back`{m.page_path}/index.mu]")
print()

submitted = "field_pw" in os.environ

if submitted:
    try:
        pw = os.environ.get("field_pw", "")
        if m.check_admin_pw(pw):
            token = m.create_admin_session()
            print("`F3a3Login successful.`f")
            print()
            print(f"`[Go to Admin Panel`{m.page_path}/admin.mu`session={token}]")
            sys.exit()
        else:
            print("`Ff55Incorrect password.`f")
            print()
    except Exception as ex:
        print(f"`Ff55Error: {ex}`f")
        print()

print(">>Password")
print("`B333`<!32|pw`>`b")
print()
print(f"`[Login`{m.page_path}/admin_login.mu`*]")
m.print_footer()
