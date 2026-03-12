# BankBuddy
## What is BankBuddy
BankBuddy is an Android app that lets you upload your UOB eStatement and get a financial summary, including net cashflow (e.g. +$99.32, -$31.49), allowances, reimbursements, and outgoing expenses. 
Inspect daily balance changes on the Candlestick screen — green means you gained money, red means you spent more. See your current balance at the top to know how much more money you have at the end of the month compared to the start. 
Hover or tap on specific candles (days) to view a tooltip showing balance at the start and end of the day, as well as the highest and lowest balance. 
The Spending Heatmap shows which days you spent the most.

### Home & Analytics Pages
<img width="1611" height="981" alt="BankBuddy pages" src="https://github.com/user-attachments/assets/45128e9c-a422-4555-8438-89def2da833e" />

### In-depth: Candlestick Page
<img width="1723" height="1059" alt="Candlestick page Demo static" src="https://github.com/user-attachments/assets/5edeeaf8-f4e7-4e63-a408-6de03a936bf3" />

## Why?
I often spend without keeping track and have no easy way to reflect on my spending. 
For example, I might have spent nearly $300 on Pool in Jan 2026 without realizing it. 
BankBuddy helps me see what I spend most on, which days I tend to spend a lot, and how much I saved that month.

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

* FastAPI Backend: Processes uploaded eStatements (PDF → CSV), cleans data, and generates analytics (candlestick plot, spending heatmap, summary data).

* Railway: Makes the FastAPI backend publicly accessible so the Flutter client can retrieve data.

* Flutter App (Dart): Makes API calls and displays the information with interactive elements.

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

## Known Limitations
1. Outgoing minus reimbursements on the home page may not always equal total spend on the heatmap page. Working to fix this ASAP.
2. Only supports UOB eStatement PDF format (camelot table extraction is tuned to UOB's layout)
3. Session data is in-memory — restarting the backend clears all uploaded data
4. Month selector is manual — must match the period shown on the statement cover
