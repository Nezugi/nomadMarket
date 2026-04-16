#!/usr/bin/env python3
"""
nomadMarkt — Admin Password Setup

Usage: python3 setup_admin.py

Sets or resets the admin password for the market.
The password is stored as SHA-256 hash with random 16-byte salt.
"""
import sys, os, hashlib, secrets, sqlite3

sys.path.insert(0, os.path.dirname(__file__))
import main as m

def set_admin_pw(pw):
    """Hash password with random salt and store in database."""
    salt = secrets.token_hex(16)
    pw_hash = salt + hashlib.sha256((salt + pw).encode()).hexdigest()
    c = m.get_db()
    c.execute("INSERT OR REPLACE INTO settings VALUES ('admin_pw_hash', ?)", (pw_hash,))
    c.commit()
    c.close()

if __name__ == "__main__":
    print("nomadMarkt — Admin Password Setup")
    print("=" * 40)
    pw = input("New password (min. 6 characters): ").strip()
    if len(pw) < 6:
        print("Error: Password too short.")
        sys.exit(1)
    pw2 = input("Confirm password: ").strip()
    if pw != pw2:
        print("Error: Passwords do not match.")
        sys.exit(1)
    set_admin_pw(pw)
    print("Admin password set.")
