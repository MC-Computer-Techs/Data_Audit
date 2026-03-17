# Reservation Data Audit Application

A Streamlit application to parse, audit, and aggregate Bookings Tool reservation data into reporting matrices for academic year reporting.

## Overview

This application takes the raw reservations export (`All_BT_Reservations.csv`) and automatically groups the data by Space, Department, and School across an Academic Year (Fall, Winter, Spring, Summer). It creates a "Top Sheet" reporting overall metrics and updates historical tracking datasets ("One Sheet").

## How to Run

1. Make sure you have `uv` installed.
2. Clone this repository and navigate to the directory:
   ```bash
   cd DataAudit
   ```
3. Install dependencies:
   ```bash
   ./setup.sh
   ```
4. To run the application, make sure your environment is activated:
   ```bash
   source .venv/bin/activate
   ```   
5. Run the Streamlit app using `uv`:
   ```bash
   uv run streamlit run src/app.py
   ```
6. The application will open in your browser automatically.
7. Upload the raw data CSV and (optionally) the historic `One Sheet`.

## Data Filtering & Calculation Rules

Based on the required reporting rules, the application alters the raw data mathematically:
* **Status**: ONLY events with an `End Event Status` of `Approved` or `Checked out` are counted. `No shows`, `Canceled`, `Declined`, and `Requested` events are excluded.
* **Maintenance**: Any event with "maintenance" in the Booking Type or Reservation Title is excluded.
* **Hour Cap**: A strict 12-hour per-day maximum cap is enforced on the duration sums to prevent multi-day/week long bookings from breaking the true active usage reporting.
* **Multiple Hosts**: If a single reservation title implies multiple groups (e.g., "IDM & ITP Event"), the script automatically duplicates the event into both groups to ensure the activity is properly attributed to all sponsors. 
* **Missing Departments**: Over 900+ raw entries lack a formal Department assignment. The scripts infer the target Department structurally by searching the `Reservation Title` for common program acronyms (ITP, IDM, Game Center, Music Tech, etc.). If none are found, it falls back to `Other Group(s)`.
* **Missing Schools**: If a department is inferred as `Other Group(s)`, the application takes an extra step to scan the `Reservation Title` for school keywords (e.g., Tisch, Steinhardt, Tandon, CUSP, ECE, CSAW) and assigns them to the correct School metric instead of defaulting to `Other Schools`.
