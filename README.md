# Reservation Data Audit Application

A full-stack application using FastAPI and React to parse, audit, and aggregate Bookings Tool reservation data into reporting matrices for academic year reporting.

## Overview

This application takes the raw reservations export (`All_BT_Reservations.csv`) and automatically groups the data by Space, Department, and School across a user-defined date range. It dynamically identifies the required semesters (Fall, Winter, Spring, Summer) within that range, creates a "Top Sheet" reporting overall metrics, and updates historical tracking datasets ("One Sheet").

## Installation & Setup from Scratch

If you are setting this up on a fresh computer, follow these steps to install the necessary system dependencies before running the app.

### 1. Install System Dependencies

**Install Node.js (via NVM):**
You will need Node.js and `npm` to run the React frontend. It is recommended to install it via NVM (Node Version Manager).
```bash
# Install NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash

# Refresh your terminal profile (or restart your terminal window)
source ~/.bashrc  # or source ~/.zshrc

# Install and use the latest LTS version of Node.js
nvm install --lts
nvm use --lts
```

**Install UV (Python Package Manager):**
UV is a blazingly fast Python package and environment manager. We use it to handle our backend environment.
```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Refresh your terminal profile (or restart your terminal window)
source ~/.bashrc  # or source ~/.zshrc
```

### 2. Set Up the Application

Navigate to the project directory (or clone the repository if you haven't already):
```bash
cd DataAudit
```

#### Start the FastAPI Backend:
*(Make sure you are in the root `DataAudit` directory)*
```bash
# Create a Python virtual environment using uv
uv venv

# Activate the virtual environment BEFORE installing dependencies
source .venv/bin/activate

# Install the required Python packages into the virtual environment
uv pip install -r requirements.txt

# Start the backend server
uvicorn backend.main:app --reload
```
*The backend will run on `http://127.0.0.1:8000`.*

#### Start the React Frontend:
Open a **new** terminal window, navigate to the frontend folder, and start the app:
```bash
# Navigate to the frontend directory
cd DataAudit/frontend

# Install node dependencies
npm install

# Start the frontend development server
npm run dev
```
*The frontend will run on `http://localhost:5173`.*

**3. Using the App:** 
The application will be accessible via the frontend URL (`http://localhost:5173`) in your browser. Upload the raw data CSV and (optionally) the historic `One Sheet`.

## Editable Grouping Pairs & Offline Excel Support

Once the data is processed, you can view the detailed grouping pairs in the **Grouping Pairs** tab. These tables are now fully interactive:
- **Manual Filter Overrides**: You will see an `Include` checkbox on every single booking row across both the `Grouping Pairs` and `Filtered Bookings` tabs. Unchecking a box allows you to manually filter a booking out of the dataset (bypassing automated rules), while checking a box in the filtered tab manually reinstates a rejected booking into the active dataset!
- You can directly edit the text values (e.g., `Clean School`, `Calc Hours`) within the Grouping Pairs tables.
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
* **Status**: ONLY events with an `End Event Status` containing `Approved` or `Checked out` are counted. However, because statuses are listed chronologically as a comma-separated history, the application actively scans the entire string. If the history contains `No show`, `Canceled`, or `Declined` at any point, the event is automatically excluded, even if it was previously approved. Additionally, if an event was `Checked In`, it MUST also be `Checked Out` to be considered valid; otherwise, it is excluded.
* **Maintenance**: Any event with "maintenance" in the Booking Type or Reservation Title is excluded.
* **Hour Cap**: A strict 12-hour per-day maximum cap is enforced on the duration sums to prevent multi-day/week long bookings from breaking the true active usage reporting.
* **Multiple Hosts**: If a single reservation title implies multiple groups (e.g., "IDM & ITP Event"), the script automatically duplicates the event into both groups to ensure the activity is properly attributed to all sponsors. 
* **Missing Departments**: Over 900+ raw entries lack a formal Department assignment. The scripts infer the target Department structurally by searching the `Reservation Title` for common program acronyms (ITP, IDM, Game Center, Music Tech, etc.). If none are found, it falls back to `Other Group(s)`.
* **Missing Schools**: If a department is inferred as `Other Group(s)`, the application takes an extra step to scan the `Reservation Title` for school keywords (e.g., Tisch, Steinhardt, Tandon, CUSP, ECE, CSAW) and assigns them to the correct School metric instead of defaulting to `Other Schools`.
* **Overnight Day Rules**: If a booking is strictly overnight (e.g., its start time is later in the day than its end time), the span of calendar dates is appropriately subtracted by 1 to represent the true number of active nights/days used for the booking. The total hours are then directly multiplied by these actual days.

## Recent Updates

- **Search Function (⌘F)**: Added a search bar to the Grouping Pairs and Filtered Bookings tabs. Type any text to instantly filter table rows across all columns, showing only bookings that match your query. A clear button resets the search.
- **No Show & Late Cancellation Tracking**: "No Show" and "Late Cancellation" statuses are now detected as distinct filter categories. They appear as separate collapsible sections in the Filtered Bookings tab, as dedicated rows in the Top Sheet table (both in-app and CSV export), and as metric cards at the top of the Top Sheet Overview.
- **PDF Export Enhancements**: The PDF export now includes No Show and Late Cancellation counts alongside the existing reservation and hours metrics.
- **Filtered Bookings Scoped to Date Range**: The Filtered Bookings tab now only displays bookings that fall within the selected date range. Out-of-range bookings are excluded from the view since they're not relevant to the current audit period.
- **Fixed Date Sorting**: Sorting by date columns (Booking Start Date, Booking End Date) now uses proper date parsing instead of string comparison, ensuring correct chronological ordering regardless of date format.
- **Batch Editing**: Select multiple rows in any table (Shift-click or Cmd-click), then edit a cell in any selected row — the change will automatically apply to all selected rows in that column. This makes bulk corrections much faster.
- **Enhanced Edit Highlighting**: Edited cells now display a more prominent orange highlight (previously a subtle yellow) so modified values are immediately visible.
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
- Updated Top Sheet and PDF export calculations to compute total aggregate values by summing individual pre-rounded numbers, guaranteeing that the itemized columns visually map to the exact grand total without floating point discrepancies.
- Added multi-row paste support in the Grouping Pairs tables, allowing users to copy multiple column values (e.g. from Excel) and paste them simultaneously across multiple rows.
- Added multi-row selection and editing: Users can now click and drag, shift-click, or Cmd/Ctrl-click to select multiple cells in the same column. Typing in any of the selected cells will automatically synchronize the edits across all highlighted rows.
- Added a "Discard Changes" button that appears alongside the "Save Changes" button, giving users a quick way to revert all unsaved table modifications at once.

## Native macOS Application

The project has been ported to a fully native, standalone macOS application using Swift and SwiftUI. This eliminates the need for Node.js, Python, or local servers.

### Building and Running the macOS App
1. Open the `DataAuditMac` directory.
2. Double click the `Package.swift` file to open it in Xcode.
3. Select the `DataAuditMac` executable target in the top toolbar.
4. Click the **Run** button (or press `Cmd + R`) to compile and launch the application natively on your Mac.

The macOS app supports importing `.csv` files natively and generates PDFs using macOS's built-in `PDFKit`.

### CSV Bundle Export/Import
The macOS app supports exporting the entire audit as a folder bundle and re-importing it later. The exported bundle includes:
- `Grouping_Pairs/` — semester-sorted CSVs for rooms, departments, and schools
- `Raw_Data.csv` — complete raw reservation data (including filtered items) for lossless round-trips
- `Other/` — misformatted and "Other Schools" entries
- `Top_Sheet_*.csv` and `One_Sheet_Updated_*.csv`

When re-importing a bundle, the app will use `Raw_Data.csv` as the authoritative source and re-run the full processing pipeline, ensuring hours and filter states match the original. Bundles exported before this feature (without `Raw_Data.csv`) are still supported via the legacy grouping-pair reconstruction path.

