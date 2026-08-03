#!/usr/bin/env python3
import os, sqlite3, hashlib, secrets
from datetime import datetime, timedelta

# ─── Configuration ────────────────────────────────────────────────────────────
storage_path = "/home/user/.nomadMarket"   # ← Set to actual user path
page_path    = ":/page/market"             # ← Node path
site_name        = "nomadMarket"
site_description = "Community Classifieds & Exchange Board"  # Short description
node_homepage = ":/page/index.mu"
EXPIRE_DAYS  = 7
# ──────────────────────────────────────────────────────────────────────────────

DB_PATH = os.path.join(storage_path, "market.db")

TYPES = {
    "offer":    ("OFFER",    "`F1a6"),
    "wanted":   ("WANTED",   "`F4af"),
    "trade":    ("TRADE",    "`Fca4"),
    "free":     ("FREE",     "`Ffaa"),
}

CATEGORIES_DEFAULT = [
    ("food",        "Food & Seeds"),
    ("tools",       "Tools & Equipment"),
    ("clothing",    "Clothing & Textiles"),
    ("electronics", "Electronics"),
    ("services",    "Skills & Services"),
    ("misc",        "Miscellaneous"),
]

def get_db():
    os.makedirs(storage_path, exist_ok=True)
    con = sqlite3.connect(DB_PATH, timeout=10)
    # Every .mu request is its own fresh process; concurrent requests hitting
    # this file would otherwise fail immediately with "database is locked"
    # instead of briefly waiting.
    con.execute("PRAGMA busy_timeout=10000")
    return con

def safe_int(value, default=0):
    """int(value) that never raises — malformed/malicious request params
    fall back to `default` instead of crashing the whole page."""
    try:
        return int(str(value).strip())
    except (ValueError, TypeError):
        return default

def init_db():
    """Initialize database with required tables on first import."""
    c = get_db()
    cur = c.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS listings (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            type         TEXT NOT NULL,
            category     TEXT NOT NULL,
            title        TEXT NOT NULL,
            description  TEXT DEFAULT '',
            price        TEXT DEFAULT '',
            lxmf_address TEXT DEFAULT '',
            contact_info TEXT DEFAULT '',
            edit_token   TEXT NOT NULL,
            is_visible   INTEGER DEFAULT 1,
            created_at   TEXT NOT NULL,
            expires_at   TEXT NOT NULL
        )
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS categories (
            slug        TEXT PRIMARY KEY,
            name        TEXT NOT NULL,
            sort_order  INTEGER DEFAULT 0
        )
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS settings (
            key   TEXT PRIMARY KEY,
            value TEXT
        )
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS admin_sessions (
            token      TEXT PRIMARY KEY,
            expires_at TEXT NOT NULL
        )
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS action_log (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            key        TEXT NOT NULL,
            action     TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
    """)
    # Insert default categories only if empty
    existing = cur.execute("SELECT COUNT(*) FROM categories").fetchone()[0]
    if existing == 0:
        for i, (slug, name) in enumerate(CATEGORIES_DEFAULT):
            cur.execute("INSERT OR IGNORE INTO categories VALUES (?,?,?)", (slug, name, i))
    c.commit()
    c.close()

def cleanup_expired():
    """Delete expired listings and sessions. Called on every page load."""
    now = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S")
    c = get_db()
    c.execute("DELETE FROM listings WHERE expires_at < ?", (now,))
    c.execute("DELETE FROM admin_sessions WHERE expires_at < ?", (now,))
    # Purge stale rate-limit rows (well past any window used below).
    day_ago = (datetime.utcnow() - timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%S")
    c.execute("DELETE FROM action_log WHERE created_at < ?", (day_ago,))
    c.commit()
    c.close()

def get_setting(key, default=""):
    c = get_db()
    row = c.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
    c.close()
    return row[0] if row else default

def set_setting(key, value):
    c = get_db()
    c.execute("INSERT OR REPLACE INTO settings (key,value) VALUES (?,?)", (key, value))
    c.commit()
    c.close()

# ─── Admin login brute-force lockout ───────────────────────────────────────────
# Single shared admin password (no per-user accounts), so this is one
# sitewide lockout rather than per-username.
ADMIN_LOGIN_MAX_ATTEMPTS = 5
ADMIN_LOGIN_LOCKOUT_MINUTES = 15

def is_admin_login_locked():
    locked_until = get_setting("admin_locked_until", "")
    now = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S")
    return bool(locked_until) and locked_until > now

def record_admin_login_failure():
    attempts = int(get_setting("admin_login_attempts", "0") or "0") + 1
    set_setting("admin_login_attempts", str(attempts))
    if attempts >= ADMIN_LOGIN_MAX_ATTEMPTS:
        locked_until = (datetime.utcnow() + timedelta(minutes=ADMIN_LOGIN_LOCKOUT_MINUTES)).strftime("%Y-%m-%dT%H:%M:%S")
        set_setting("admin_locked_until", locked_until)

def clear_admin_login_failures():
    set_setting("admin_login_attempts", "0")
    set_setting("admin_locked_until", "")

# ─── Listing creation rate-limiting ────────────────────────────────────────────
# No accounts here either — only a node identity (when present) or a
# sitewide cap as the real backstop for unidentified submitters.
LISTING_IDENTITY_RATE_LIMIT = (3, 300)   # 3 listings per 5 min, per identity
LISTING_GLOBAL_RATE_LIMIT   = (10, 300)  # 10 listings per 5 min, sitewide

def _rate_limit_ok(key, action, limit, window_seconds):
    cutoff = (datetime.utcnow() - timedelta(seconds=window_seconds)).strftime("%Y-%m-%dT%H:%M:%S")
    c = get_db()
    count = c.execute(
        "SELECT COUNT(*) FROM action_log WHERE key=? AND action=? AND created_at > ?",
        (key, action, cutoff)
    ).fetchone()[0]
    c.close()
    return count < limit

def _record_action(key, action):
    now = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S")
    c = get_db()
    c.execute("INSERT INTO action_log(key,action,created_at) VALUES(?,?,?)", (key, action, now))
    c.commit()
    c.close()

def listing_rate_ok(identity_hash=""):
    if not _rate_limit_ok("global", "listing", *LISTING_GLOBAL_RATE_LIMIT):
        return False
    if identity_hash and not _rate_limit_ok(f"identity:{identity_hash}", "listing", *LISTING_IDENTITY_RATE_LIMIT):
        return False
    return True

def record_listing_action(identity_hash=""):
    _record_action("global", "listing")
    if identity_hash:
        _record_action(f"identity:{identity_hash}", "listing")

def get_remote_identity():
    ident = os.environ.get("remote_identity", "").strip().lower()
    if len(ident) == 32 and all(c in "0123456789abcdef" for c in ident):
        return ident
    return ""

# ─── Listings ─────────────────────────────────────────────────────────────────

def get_listings(category=None, type_filter=None, limit=50):
    """Retrieve active, visible listings with optional filtering."""
    now = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S")
    c = get_db()
    q = "SELECT * FROM listings WHERE is_visible=1 AND expires_at > ? "
    params = [now]
    if category:
        q += "AND category=? "
        params.append(category)
    if type_filter:
        q += "AND type=? "
        params.append(type_filter)
    q += "ORDER BY created_at DESC LIMIT ?"
    params.append(limit)
    rows = c.execute(q, params).fetchall()
    c.close()
    return rows

def get_listing(lid):
    """Get a single listing by ID (if not expired)."""
    now = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S")
    c = get_db()
    row = c.execute(
        "SELECT * FROM listings WHERE id=? AND expires_at > ?", (lid, now)
    ).fetchone()
    c.close()
    return row

def get_listing_by_token(token):
    """Get a listing by its edit token (if not expired)."""
    now = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S")
    c = get_db()
    row = c.execute(
        "SELECT * FROM listings WHERE edit_token=? AND expires_at > ?", (token, now)
    ).fetchone()
    c.close()
    return row

def escape_micron(text):
    """Neutralize Micron's control character so user-submitted text can't
    inject formatting, colors, or fake links into the rendered page."""
    return text.replace("`", "'")

def create_listing(type_, category, title, description, price, lxmf, contact):
    """Create a new listing and return (id, edit_token)."""
    now = datetime.utcnow()
    expires = now + timedelta(days=EXPIRE_DAYS)
    token = secrets.token_hex(16)  # 32 hex chars
    c = get_db()
    cur = c.cursor()
    cur.execute("""
        INSERT INTO listings
        (type,category,title,description,price,lxmf_address,contact_info,edit_token,is_visible,created_at,expires_at)
        VALUES (?,?,?,?,?,?,?,?,1,?,?)
    """, (
        type_, category, escape_micron(title[:60]), escape_micron(description[:400]),
        escape_micron(price[:60]), lxmf[:32], escape_micron(contact[:100]),
        token,
        now.strftime("%Y-%m-%dT%H:%M:%S"),
        expires.strftime("%Y-%m-%dT%H:%M:%S"),
    ))
    lid = cur.lastrowid
    c.commit()
    c.close()
    return lid, token

def update_listing(token, title, description, price, lxmf, contact, extend):
    """Update listing fields. Returns True if successful."""
    now = datetime.utcnow()
    c = get_db()
    row = c.execute("SELECT expires_at FROM listings WHERE edit_token=?", (token,)).fetchone()
    if not row:
        c.close()
        return False
    if extend:
        new_expires = (now + timedelta(days=EXPIRE_DAYS)).strftime("%Y-%m-%dT%H:%M:%S")
    else:
        new_expires = row[0]
    c.execute("""
        UPDATE listings SET title=?,description=?,price=?,lxmf_address=?,contact_info=?,expires_at=?
        WHERE edit_token=?
    """, (escape_micron(title[:60]), escape_micron(description[:400]), escape_micron(price[:60]),
          lxmf[:32], escape_micron(contact[:100]), new_expires, token))
    c.commit()
    c.close()
    return True

def delete_by_token(token):
    """Delete a listing using its edit token."""
    c = get_db()
    c.execute("DELETE FROM listings WHERE edit_token=?", (token,))
    c.commit()
    c.close()

# ─── Categories ───────────────────────────────────────────────────────────────

def get_categories():
    """Get all categories sorted by display order."""
    c = get_db()
    rows = c.execute("SELECT slug, name FROM categories ORDER BY sort_order").fetchall()
    c.close()
    return rows

def get_category_name(slug):
    """Get display name for a category slug."""
    c = get_db()
    row = c.execute("SELECT name FROM categories WHERE slug=?", (slug,)).fetchone()
    c.close()
    return row[0] if row else slug

def get_category_counts():
    """Get all categories with count of active listings in each."""
    now = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S")
    c = get_db()
    rows = c.execute("""
        SELECT cat.slug, cat.name, COUNT(l.id)
        FROM categories cat
        LEFT JOIN listings l ON l.category=cat.slug AND l.is_visible=1 AND l.expires_at > ?
        GROUP BY cat.slug
        ORDER BY cat.sort_order
    """, (now,)).fetchall()
    c.close()
    return rows

def add_category(slug, name):
    """Add a new category. Returns True if successful."""
    c = get_db()
    max_order = c.execute("SELECT MAX(sort_order) FROM categories").fetchone()[0] or 0
    try:
        c.execute("INSERT INTO categories VALUES (?,?,?)", (slug, name, max_order+1))
        c.commit()
        ok = True
    except sqlite3.IntegrityError:
        ok = False
    c.close()
    return ok

def delete_category(slug):
    """Delete a category (only if it has no visible listings)."""
    c = get_db()
    count = c.execute("SELECT COUNT(*) FROM listings WHERE category=? AND is_visible=1", (slug,)).fetchone()[0]
    if count > 0:
        c.close()
        return False
    c.execute("DELETE FROM categories WHERE slug=?", (slug,))
    c.commit()
    c.close()
    return True

# ─── Admin Sessions ───────────────────────────────────────────────────────────

def check_admin_pw(pw):
    """Verify admin password against stored hash."""
    c = get_db()
    row = c.execute("SELECT value FROM settings WHERE key='admin_pw_hash'").fetchone()
    c.close()
    if not row:
        return False
    stored = row[0]
    salt = stored[:32]
    expected = salt + hashlib.sha256((salt + pw).encode()).hexdigest()
    return stored == expected

def create_admin_session():
    """Create a new admin session (6-hour TTL)."""
    token = secrets.token_hex(32)  # 64 hex chars
    expires = (datetime.utcnow() + timedelta(hours=6)).strftime("%Y-%m-%dT%H:%M:%S")
    c = get_db()
    c.execute("INSERT INTO admin_sessions VALUES (?,?)", (token, expires))
    c.commit()
    c.close()
    return token

def check_admin_session(token):
    """Check if an admin session token is valid and not expired."""
    if not token:
        return False
    now = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S")
    c = get_db()
    row = c.execute(
        "SELECT 1 FROM admin_sessions WHERE token=? AND expires_at > ?", (token, now)
    ).fetchone()
    c.close()
    return row is not None

def admin_delete_listing(lid):
    """Delete a listing by ID (admin only)."""
    c = get_db()
    c.execute("DELETE FROM listings WHERE id=?", (lid,))
    c.commit()
    c.close()

def admin_toggle_visible(lid, visible):
    """Hide or show a listing (admin only)."""
    c = get_db()
    c.execute("UPDATE listings SET is_visible=? WHERE id=?", (visible, lid))
    c.commit()
    c.close()

def admin_get_all(include_hidden=True):
    """Get all listings (including hidden ones if requested)."""
    c = get_db()
    q = "SELECT * FROM listings"
    if not include_hidden:
        q += " WHERE is_visible=1"
    q += " ORDER BY created_at DESC"
    rows = c.execute(q).fetchall()
    c.close()
    return rows

# ─── Helper Functions ─────────────────────────────────────────────────────────

def fmt_remaining(expires_at_str):
    """Return human-readable time remaining: 'still 7 days' … 'still 1 day'."""
    try:
        exp = datetime.strptime(expires_at_str, "%Y-%m-%dT%H:%M:%S")
        diff = exp - datetime.utcnow()
        secs = int(diff.total_seconds())
        if secs <= 0:
            return "expired"
        # Ceiling division: partial days count as full days
        days = max(1, -(-secs // 86400))
        if days == 1:
            return "still 1 day"
        return f"still {days} days"
    except Exception:
        return ""

def fmt_date(dt_str):
    """Convert ISO timestamp to dd.mm.yyyy format."""
    try:
        dt = datetime.strptime(dt_str, "%Y-%m-%dT%H:%M:%S")
        return dt.strftime("%d.%m.%Y")
    except Exception:
        return dt_str

def type_badge(t):
    """Return colored type label for display."""
    info = TYPES.get(t, ("?", "`F777"))
    return f"{info[1]}{info[0]}`f"

def validate_lxmf(addr):
    """Validate LXMF address (must be exactly 32 hex chars)."""
    if not addr:
        return ""
    addr = addr.strip().lower()
    if len(addr) == 32 and all(c in "0123456789abcdef" for c in addr):
        return addr
    return ""

def nav_bar(token=""):
    """Render navigation bar (with admin links if token provided)."""
    sep = "  "
    parts = [
        f"`[Market`{page_path}/index.mu]",
        f"`[Post Listing`{page_path}/new.mu]",
        f"`[Help`{page_path}/help.mu]",
    ]
    if token:
        parts.append(f"`[Admin`{page_path}/admin.mu`session={token}]")
        parts.append(f"`[Logout`{page_path}/admin_logout.mu`session={token}]")
    else:
        parts.append(f"`[Admin Login`{page_path}/admin_login.mu]")
    parts.append(f"`Fca4`[← Node Home`{node_homepage}]`f")
    return sep.join(parts)

def print_header(subtitle=None):
    """Print unified header: title + description. Resets alignment after."""
    print(f"`c`!`F0af{site_name}`!")
    print(f"`c`F777{site_description}`f")
    if subtitle:
        print(f"`c`F555{subtitle}`f")
    print("`a")

def print_footer():
    """Print footer with suite attribution."""
    print("-")
    print("`c`F444Off-Grid Community Suite · NomadNet`f")
    print("`a")

def lxmf_link(address):
    """Return clickable LXMF address link (single-segment lxmf@ format)."""
    if address:
        return f"`[lxmf@{address}]"
    return ""

# On import: initialize DB and clean up expired entries
init_db()
cleanup_expired()
