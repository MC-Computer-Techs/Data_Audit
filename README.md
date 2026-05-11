# Reservation Data Audit Application

A full-stack application using FastAPI and React to parse, audit, and aggregate Bookings Tool reservation data into reporting matrices for academic year reporting.

## Overview

This application takes the raw reservations export (`All_BT_Reservations.csv`) and automatically groups the data by Space, Department, and School across a user-defined date range. It dynamically identifies the required semesters (Fall, Winter, Spring, Summer) within that range, creates a "Top Sheet" reporting overall metrics, and updates historical tracking datasets ("One Sheet").

## How to Run

1. Make sure you have `uv` and `npm` installed. Use `uv venv` to create a virtual environment for the backend.
2. Clone this repository and navigate to the directory:
   ```bash
   cd DataAudit
   ```
3. Set up and start the **FastAPI Backend**:
   *(Make sure you are in the root `DataAudit` directory, not the `frontend` folder)*
   ```bash
   uv venv
   source .venv/bin/activate
   uv pip install -r requirements.txt
   uvicorn backend.main:app --reload
   ```
   *The backend will run on `http://127.0.0.1:8000`.*
   
4. Set up and start the **React Frontend**:
   Open a new terminal window:
   ```bash
   cd frontend
   npm install
   npm run dev
   ```
   *The frontend will run on `http://localhost:5173`.*

5. The application will be accessible via the frontend URL in your browser.
6. Upload the raw data CSV and (optionally) the historic `One Sheet`.

## Editable Grouping Pairs & Offline Excel Support

Once the data is processed, you can view the detailed grouping pairs in the **Grouping Pairs** tab. These tables are now fully interactive:
- You can directly edit the values (e.g., `Clean School`, `Calc Hours`) within the Grouping Pairs tables.
- When you are ready, press the **Save Changes** button. Any changes made will re-calculate the **Top Sheet Overview** to reflect the updated metrics.
- The underlying CSV files for both the Grouping Pairs and the Top Sheet are immediately re-exported to your local directory.

### Offline Excel Support
If you prefer offline editing:
1. Process your initial Booking Tool CSV file.
2. Under the "Top Sheet Overview" tab, click **Download Full Audit (Excel)** to generate an `.xlsx` copy of your entire audit.
3. Open this Excel file natively using Microsoft Excel or Apple Numbers. You'll find a clear Top Sheet, along with individual editable tabs per Grouping Pair.
4. Modify any grouping pair (e.g., adjust rows in `F24_Schools`).
5. Upload this modified `.xlsx` file into the new **Upload Existing Excel Audit** box at the top of the app and click "Process Data". The app will automatically sync your offline changes back into its core engine and update all internal totals!

### Nicely Formatted PDF Export
You can also generate a nicely formatted, highly polished PDF version of your Top Sheet, Grouping Pairs, and updated One Sheet.
1. Process your initial Booking Tool CSV file.
2. Under the "Top Sheet Overview" tab, click **Download Top Sheet (PDF)** to generate the PDF report, which includes shaded tables, clear gridlines, and bold headers to present clean analytics.

## Data Filtering & Calculation Rules

Based on the required reporting rules, the application alters the raw data mathematically:
* **Status**: ONLY events with an `End Event Status` of `Approved` or `Checked out` are counted. `No shows`, `Canceled`, `Declined`, and `Requested` events are excluded.
* **Maintenance**: Any event with "maintenance" in the Booking Type or Reservation Title is excluded.
* **Hour Cap**: A strict 12-hour per-day maximum cap is enforced on the duration sums to prevent multi-day/week long bookings from breaking the true active usage reporting.
* **Multiple Hosts**: If a single reservation title implies multiple groups (e.g., "IDM & ITP Event"), the script automatically duplicates the event into both groups to ensure the activity is properly attributed to all sponsors. 
* **Missing Departments**: Over 900+ raw entries lack a formal Department assignment. The scripts infer the target Department structurally by searching the `Reservation Title` for common program acronyms (ITP, IDM, Game Center, Music Tech, etc.). If none are found, it falls back to `Other Group(s)`.
* **Missing Schools**: If a department is inferred as `Other Group(s)`, the application takes an extra step to scan the `Reservation Title` for school keywords (e.g., Tisch, Steinhardt, Tandon, CUSP, ECE, CSAW) and assigns them to the correct School metric instead of defaulting to `Other Schools`.
* **Overnight Day Rules**: If a booking is strictly overnight (e.g., its start time is later in the day than its end time), the span of calendar dates is appropriately subtracted by 1 to represent the true number of active nights/days used for the booking. The total hours are then directly multiplied by these actual days.

## Recent Updates

- Fixed missing dependency (`reportlab`) causing PDF export failures. Use `uv pip install -r requirements.txt` within the `.venv` to install all necessary packages.
- Added type coercion to ensure Excel imports containing numbers or empty values do not cause `float64` type errors when parsed against string-based grouping algorithms.
- Fixed Excel round-trip hours drift (~48 hours lost on re-import). Root cause was false-positive change detection from type mismatches (`nan` vs empty string, `list` vs stringified list, float precision noise) that caused split per-room hours to overwrite full `ACTUAL hours` in the raw data. The import now skips derived columns and uses tolerance-based comparison for numerics.
- Improved Grouping Pairs table sorting to always reset to the first page, clarifying that sorting applies globally across the entire dataset rather than just the currently visible page.
- Removed pagination from the Grouping Pairs tables to allow viewing all records at once while maintaining the collapsible section functionality.
- Converted all large tables across the application to be individually scrollable within a fixed-height window, preventing extremely large datasets from stretching the entire page vertically.
- Integrated extended department-to-school mappings directly into the data processor algorithm, improving school categorization accuracy without creating redundant department groupings (e.g., mapping "URPA" to "Community Partner").
- Updated the pipeline to automatically populate the empty "School" column natively in the underlying dataset and Excel exports, copying over the derived "Clean School" categorizations.
- Altered the core time calculation logic so that the "Time In Use, Hours" column reflects the simple, base duration of the reservation (without the room multiplier), while "ACTUAL hours" retains the room multiplier for total allocated time reporting.
- Enforced two-decimal-place rounding on all internal time calculations (`Time In Use, Hours` and `ACTUAL hours`) to prevent floating point inaccuracies and align with reporting standards.
