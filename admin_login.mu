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
        if m.is_admin_login_locked():
            print(f"`Ff55Too many failed attempts. Try again in up to {m.ADMIN_LOGIN_LOCKOUT_MINUTES} minutes.`f")
            print()
        else:
            pw = os.environ.get("field_pw", "")
            if m.check_admin_pw(pw):
                m.clear_admin_login_failures()
                token = m.create_admin_session()
                print("`F3a3Login successful.`f")
                print()
                print(f"`[Go to Admin Panel`{m.page_path}/admin.mu`session={token}]")
                sys.exit()
            else:
                m.record_admin_login_failure()
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
