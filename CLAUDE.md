# BankBuddy — CLAUDE.md

> **Maintenance rule:** Update this file after every code change. Keep it at or under 300 lines.

---

## Overview

BankBuddy is a personal finance app for analysing UOB bank eStatements. The user uploads a PDF statement; the backend parses, cleans, and categorises every transaction; the Flutter frontend visualises the results as an interactive summary, OHLC candlestick chart, and weekly spending heatmap.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter ^3.11.1 (Dart), package name `estatement_app` |
| HTTP client | `package:http ^1.2.0` |
| File picker | `file_picker ^10.3.10` |
| Backend | Python, FastAPI + Uvicorn |
| PDF extraction | Camelot-py (stream flavour) + Ghostscript OCR |
| Data processing | pandas 2.3.3, numpy 2.3.4 |
| Deployment | Railway (nixpacks.toml) |

---

## Repository Layout

### Frontend — `c:\Users\lokej\Projects\bankbuddy`

```
lib/
  main.dart              # app entry point + UploadScreen (~607 lines)
  config.dart            # reads dart-define env vars (2 lines)
  screens/
    dashboard_screen.dart   # tab container with animated bottom nav (148 lines)
    summary_screen.dart     # monthly cashflow cards (297 lines)
    candlestick_screen.dart # OHLC balance chart (763 lines)
    heatmap_screen.dart     # weekly spend grid (404 lines)
assets/
  icon/icon.png          # 1024×1024 app icon
pubspec.yaml
```

### Backend — `C:\Users\lokej\OneDrive\Desktop\dev\estatement-analysis`

```
main.py                  # FastAPI app, CORS, session store, all routes (224 lines)
process_statement.py     # two-phase PDF → DataFrame pipeline (340 lines)
analytics.py             # summary / heatmap / candlestick / categories functions (340 lines)
categories.py            # keyword-based merchant categorisation (190 lines)
requirements.txt
nixpacks.toml            # Railway build config (installs ghostscript)
CLAUDE.md                # backend-specific architecture notes
data/                    # input PDFs (apr2025.pdf … jan2026.pdf)
tables/                  # extracted CSVs (auto-generated, gitignored)
```

> For backend architecture details see the backend's own CLAUDE.md at the path above.

---

## App Workflow

```
1. User launches app → UploadScreen
2. User picks a PDF + enters month ("Jan") → POST /upload
3. Backend: Camelot extracts tables → Phase 1 clean → Phase 2 feature engineering
   (merchant parsing, categorisation, statement_month assignment)
4. Result DataFrame cached in memory keyed by session_id
5. Frontend navigates to DashboardScreen (sessionId + month passed as constructor args)
6. Each tab independently fetches its data on first load:
   Tab 0 Summary  → GET /summary?session_id=...
   Tab 1 Balance  → GET /candlestick?session_id=...&months=...
   Tab 2 Heatmap  → GET /heatmap?session_id=...&month=2026-01
```

---

## API Contract

Base URL injected at Flutter build time via `--dart-define BASE_URL=<url>`.
All requests include `session_id` (build-time constant or user-generated string).

### `POST /upload`
- Content-Type: `multipart/form-data`
- Fields: `file` (PDF bytes), `month` (str e.g. "Jan"), `year` (int), `session_id` (str)
- Response: `{"status": "ok", "session_id": "...", "rows": <int>}`

### `GET /summary?session_id=`
```json
{
  "2025-08": {
    "allowance": 800.0,
    "reimbursements": 42.5,
    "outgoing": -650.0,
    "nett_cashflow": 192.5
  }
}
```

### `GET /candlestick?session_id=&months=` (comma-separated months, optional)
```json
{
  "2025-11": {
    "2025-11-01": {
      "open": 7387.3, "high": 7587.3, "low": 7387.3, "close": 7508.15,
      "has_transactions": true
    }
  }
}
```

### `GET /heatmap?session_id=&month=YYYY-MM`
```json
{
  "Week_2026-01-27": {
    "Monday": -45.0, "Tuesday": 0.0, "Wednesday": -12.5,
    "Thursday": 0.0, "Friday": -88.0, "Saturday": -30.0, "Sunday": 0.0
  }
}
```

### `GET /categories?session_id=&month=YYYY-MM`
```json
{
  "food": {"amount": -842.5, "count": 165},
  "drinks": {"amount": -490.2, "count": 96}
}
```

---

## Frontend Architecture

### Screens

| Screen | File | Role |
|---|---|---|
| UploadScreen | `lib/main.dart` | Entry gate: file picker + month input → POST /upload → navigate |
| DashboardScreen | `screens/dashboard_screen.dart` | Animated bottom-nav tab host (IndexedStack) |
| SummaryScreen | `screens/summary_screen.dart` | Monthly cashflow metric cards |
| CandlestickScreen | `screens/candlestick_screen.dart` | OHLC chart (custom-painted, hover tooltip) |
| HeatmapScreen | `screens/heatmap_screen.dart` | Day-of-week × week grid, colour-coded by spend |

### State Management
- `setState()` only — no BLoC, Provider, Riverpod, or any external library.
- Each screen owns `_data`, `_isLoading`, `_error` as local state.
- `IndexedStack` in DashboardScreen preserves tab state across switches.
- Data passed between screens via constructor parameters.

### Navigation
- `Navigator.pushReplacement` + `MaterialPageRoute` — no GoRouter or auto_route.
- No deep linking or URI-based routing.

### HTTP Calls
- All calls use `package:http` directly inside `initState()` — no service layer abstraction.
- Error handling: HTTP 200 = success; any other status shows `response.body` as error text.
- Network exceptions caught and displayed as "Connection error: $e".

### Theme Tokens (hardcoded as `static const` in each screen — intentional duplication for now)

| Token | Value | Usage |
|---|---|---|
| `_bg` | `#0D0D0D` | Page background |
| `_surface` | `#1A1A1A` | Card/container |
| `_surfaceElevated` | `#222222` | Elevated areas |
| `_border` | `#2A2A2A` | Container borders |
| `_orange` | `#FF6B00` | Primary accent (buttons, highlights) |
| `_textPrimary` | `#FFFFFF` | Main text |
| `_textSecondary` | `#888888` | Muted text |
| `_errorRed` | `#FF3B3B` | Errors / down candles |
| `_candleUp` | `#00C076` | Up candles (balance gain) |
| `_neutral` | `#3A3A3A` | No-activity candle |

Font: Lato (set in `ThemeData`). Charts are fully custom-painted — no `fl_chart` or similar library.

---

## Configuration

### Flutter build-time env vars (required)
```
--dart-define BASE_URL=https://your-backend.railway.app
--dart-define SESSION_ID=some-unique-string
```

### Backend runtime
- Start locally: `python -m uvicorn main:app --reload` → `http://localhost:8000`
- Ghostscript must be installed for Camelot OCR to work.
- Session store is in-memory (`dict[str, pd.DataFrame]`) — restarting the server clears all sessions.

---

## Known Limitations / Production TODOs

- **No auth:** CORS is `allow_origins=["*"]`; session_id is not cryptographically secured.
- **Session persistence:** In-memory store lost on backend restart; needs Redis or DB.
- **Hardcoded allowance detection:** `is_allowance` only flags transfers from "wei keen" ≥ $100 — not flexible.
- **Dropped rows:** Cashback ("Misc CR-Debit Card") and Interest Credit rows are dropped in `process_statement.py` lines 247-253 — must be reconsidered before production.
- **No typed models:** Flutter uses `Map<String, dynamic>` throughout — consider adding model classes for larger feature sets.
- **Color token duplication:** Same palette constants repeated in every screen — consider centralising in a `theme.dart`.
- **Sync PDF processing:** Camelot extraction is synchronous and can be slow on large statements.
