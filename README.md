# Reservation Data Audit Application

A Streamlit application to parse, audit, and aggregate Bookings Tool reservation data into reporting matrices for academic year reporting.

## Overview

This application takes the raw reservations export (`All_BT_Reservations.csv`) and automatically groups the data by Space, Department, and School across an Academic Year (Fall, Winter, Spring, Summer). It creates a "Top Sheet" reporting overall metrics and updates historical tracking datasets ("One Sheet").

## How to Run

1. Make sure you have `uv` installed. Use `uv venv` to create a virtual environment, and use that when developing. If not in the virtual environment, use `source .venv/bin/activate` to get into it.
2. Clone this repository and navigate to the directory:
   ```bash
   cd DataAudit
   ```
3. Install dependencies:
   ```bash
   uv pip install -r requirements.txt
   ```
   *(Alternatively, run `./setup.sh` if it uses uv under the hood).*
   
   *Note: The application uses absolute imports (e.g., `from src.data_processor import ...`) which is resolved correctly when running `streamlit run src/app.py` from the project root.*
4. To run the application, make sure your environment is activated:
   ```bash
   source .venv/bin/activate
   ```
   *Troubleshooting tip: If your python environment gets messed up, try recreating it:*
   ```bash
   rm -rf .venv
   uv venv
   source .venv/bin/activate
   uv pip install -r requirements.txt
   ```
   *If `uv` commands hang or freeze indefinitely without output, macOS Gatekeeper may be blocking the executable in the background. To fix this, remove the quarantine flag and kill stuck instances:*
   ```bash
   xattr -d com.apple.quarantine ~/.local/bin/uv
   killall -9 uv
   ```
5. Run the Streamlit app using `uv`:
   ```bash
   uv run streamlit run src/app.py
   ```
6. The application will open in your browser automatically.
7. Upload the raw data CSV and (optionally) the historic `One Sheet`.

## Editable Grouping Pairs

Once the data is processed, you can view the detailed grouping pairs in the **Grouping Pairs** tab. These tables are now fully interactive:
- You can directly edit the values (e.g., `Clean School`, `Calc Hours`) within the Grouping Pairs tables.
- Any changes made will automatically re-calculate the **Top Sheet Overview** to reflect the updated metrics.
- The underlying CSV files for both the Grouping Pairs and the Top Sheet are automatically re-exported to your local directory.

## Data Filtering & Calculation Rules

Based on the required reporting rules, the application alters the raw data mathematically:
* **Status**: ONLY events with an `End Event Status` of `Approved` or `Checked out` are counted. `No shows`, `Canceled`, `Declined`, and `Requested` events are excluded.
* **Maintenance**: Any event with "maintenance" in the Booking Type or Reservation Title is excluded.
* **Hour Cap**: A strict 12-hour per-day maximum cap is enforced on the duration sums to prevent multi-day/week long bookings from breaking the true active usage reporting.
* **Multiple Hosts**: If a single reservation title implies multiple groups (e.g., "IDM & ITP Event"), the script automatically duplicates the event into both groups to ensure the activity is properly attributed to all sponsors. 
* **Missing Departments**: Over 900+ raw entries lack a formal Department assignment. The scripts infer the target Department structurally by searching the `Reservation Title` for common program acronyms (ITP, IDM, Game Center, Music Tech, etc.). If none are found, it falls back to `Other Group(s)`.
* **Missing Schools**: If a department is inferred as `Other Group(s)`, the application takes an extra step to scan the `Reservation Title` for school keywords (e.g., Tisch, Steinhardt, Tandon, CUSP, ECE, CSAW) and assigns them to the correct School metric instead of defaulting to `Other Schools`.
