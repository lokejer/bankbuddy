# 📊 BankBuddy — UOB eStatement Analyser

A personal finance app that turns raw UOB bank PDF statements into interactive spending insights. Upload a statement, get a visual breakdown of your balance trajectory, spending patterns, and monthly cashflow.

---

## Features

- **Balance Candlestick Chart** — visualise your daily account balance as OHLC candles, with touch interaction and a floating tooltip
- **Spending Heatmap** — see spending intensity across every day of the month, broken down by week and weekday
- **Monthly Summary** — track allowance received, outgoing spend, PayNow reimbursements, and net cashflow at a glance
- **PDF Upload** — upload a UOB eStatement PDF directly from your phone; the backend extracts and processes all transactions automatically
- **Category Detection** — transactions are automatically categorised using a keyword-based merchant classifier

---

## Architecture

```
Flutter App (Mobile)
       │
       │  HTTP (REST)
       ▼
FastAPI Backend (Railway)
       │
       │  camelot PDF extraction
       ▼
pandas pipeline → JSON response
```

The Flutter app handles all UI and visualisation. The FastAPI backend handles PDF parsing, data cleaning, and analytics to return a structured JSON that the app renders natively using custom-built chart widgets.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile Frontend | Flutter / Dart |
| Chart Rendering | Custom Flutter widgets (`fl_chart`-free, hand-built OHLC + heatmap) |
| Backend | Python, FastAPI |
| PDF Extraction | camelot-py |
| Data Processing | pandas, numpy |
| Deployment | Railway |
| State Management | Flutter `setState` + `IndexedStack` |

---

## Project Structure

```
backend/
├── main.py                 # FastAPI app — 4 endpoints
├── process_statement.py    # PDF → cleaned DataFrame pipeline
├── analytics.py            # get_* functions for summary, heatmap, candlestick
├── categories.py           # Merchant categorisation logic
└── requirements.txt

flutter_app/
└── lib/
    ├── main.dart                    # Upload screen + app entry
    └── screens/
        ├── dashboard_screen.dart    # Bottom nav wrapper
        ├── summary_screen.dart      # Monthly cashflow view
        ├── candlestick_screen.dart  # OHLC balance chart
        └── heatmap_screen.dart      # Spending heatmap grid
```

---

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/upload` | Upload PDF statement, parse and store session data |
| `GET` | `/summary` | Monthly cashflow breakdown (allowance, outgoing, reimbursements, nett) |
| `GET` | `/candlestick` | Daily OHLC balance data for chart rendering |
| `GET` | `/heatmap` | Spending totals per weekday per week |

---

## Setup

### Backend

```bash
# Clone and install dependencies
pip install -r requirements.txt

# Run locally
uvicorn main:app --reload
```

> Requires Ghostscript installed for camelot PDF extraction.
> On Railway, add `nixpacks.toml` with `nixPkgs = ["ghostscript"]`.

### Flutter App

```bash
# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Build release APK
flutter build apk --release
```

> Update `baseUrl` in `main.dart` and each screen to point to your deployed backend URL.

---

## How to Use

1. Launch the app on your Android device
2. On the Upload screen, tap the upload zone and select your UOB eStatement PDF from your Documents folder
3. Enter the statement month (e.g. `202601` for January 2026)
4. Tap **Analyse Statement** — the backend processes the PDF and returns data
5. Navigate between three views using the bottom tab bar:
   - **Summary** — nett cashflow, allowance, and spending totals
   - **Balance** — drag across the candlestick chart to inspect daily balance
   - **Heatmap** — spot spending patterns by day of week

---

## Nett Cashflow Definition

```
Nett Cashflow = Allowance received + PayNow reimbursements − Outgoing spend
```

Positive = you saved money. Negative = you overspent.

Allowance is identified as any incoming PayNow transfer above $100 from a known sender. Reimbursements are incoming PayNow transfers from contacts.

---

## Known Limitations

- Supports UOB statement PDF format only (camelot table extraction is tuned to UOB's layout)
- Session data is in-memory — restarting the backend clears all uploaded data
- Month selector is manual — must match the period shown on the statement cover

---

## Future Improvements

- [ ] Multi-month view — overlay or compare multiple statements
- [ ] Category breakdown screen — pie chart of spend by merchant category  
- [ ] Persistent storage — save parsed data so sessions survive backend restarts
- [ ] iOS support
- [ ] Smarter reimbursement matching — auto-match PayNow credits to outgoing payments within a time window
- [ ] Export to CSV
