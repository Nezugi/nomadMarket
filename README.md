# nomadMarket

A classifieds board for [NomadNet](https://github.com/markqvist/NomadNet) nodes — post listings without an account, edit them with a token, auto-expiry after 7 days.

Part of the [**Off-Grid Community Suite**](https://github.com/Nezugi/Off-Grid-Community-Suite) for NomadNet nodes.

---

## Features

- **No account required** to post a listing
- **Four listing types** — Offer · Wanted · Trade · Free
- **Categories** — predefined + admin-managed
- **Auto-expiry** — listings disappear after 7 days (configurable, no background process)
- **Edit token** — owners can edit, extend, or delete their listing
- **Extend expiry** — add +7 days via the edit form
- **Remaining time** shown on all overview pages
- **Clickable LXMF addresses** — contact sellers directly
- **Admin panel** — hide/show/delete listings, manage categories
- **No external packages** — only Python standard library

---

## Installation

```bash
cp -r market/ ~/.nomadnetwork/storage/pages/market/
chmod +x ~/.nomadnetwork/storage/pages/market/*.mu
mkdir -p /home/YOUR_USER/.nomadMarket
# edit main.py — set storage_path
python3 ~/.nomadnetwork/storage/pages/market/setup_admin.py
# restart NomadNet
```

---

## Configuration

```python
storage_path     = "/home/YOUR_USER/.nomadMarket"
page_path        = ":/page/market"
site_name        = "nomadMarket"
site_description = "Community classifieds & trading board"
node_homepage    = ":/page/index.mu"
EXPIRE_DAYS      = 7
```

---

## Listing Types

| Type | Meaning | Color |
|---|---|---|
| OFFER | I have something to offer | Green |
| WANTED | I am looking for something | Blue |
| TRADE | I want to trade X for Y | Orange |
| FREE | Free of charge | Apricot |

---

## File Structure

```
market/
├── main.py          ← database, sessions, helpers
├── setup_admin.py   ← CLI: set admin password
├── index.mu         ← start page: categories + recent listings
├── category.mu      ← listings in a category
├── listing.mu       ← listing detail view
├── new.mu           ← post a listing
├── edit_ask.mu      ← enter edit token
├── edit.mu          ← edit listing (token-protected)
├── help.mu          ← user guide
├── admin_login.mu / admin_logout.mu
└── admin.mu         ← admin panel
```

---

## Permissions

| Action | Visitor | Owner (token) | Admin |
|---|---|---|---|
| Read listings | ✓ | ✓ | ✓ |
| Post a listing | ✓ | ✓ | ✓ |
| Edit own listing | — | ✓ | ✓ |
| Extend expiry | — | ✓ | ✓ |
| Delete own listing | — | ✓ | ✓ |
| Delete any listing | — | — | ✓ |
| Hide / show listing | — | — | ✓ |
| Manage categories | — | — | ✓ |

---

## Edit Token

After posting, a **32-character hex token** is shown **once** — save it. With this token the owner can edit all fields, extend the listing, or delete it. Lost tokens can only be resolved by an admin.

---

## Default Categories

| Slug | Name |
|---|---|
| food | Food & Seeds |
| tools | Tools & Equipment |
| clothing | Clothing & Textiles |
| electronics | Electronics |
| services | Skills & Services |
| misc | Miscellaneous |

---

## Database

SQLite at `~/.nomadMarket/market.db` — created automatically. Passive cleanup on every page load — no cron job or daemon needed.

---

## Access

```
YOUR_NODE_HASH:/page/market/index.mu
```

## License

MIT
