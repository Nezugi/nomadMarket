#!/usr/bin/env python3
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import main as m

print("#!c=0")

token = os.environ.get("var_session", "")
if token:
    c = m.get_db()
    c.execute("DELETE FROM admin_sessions WHERE token=?", (token,))
    c.commit()
    c.close()

m.print_header()
print("Logged out.")
print()
print(f"`[Back to Market`{m.page_path}/index.mu]")
m.print_footer()
