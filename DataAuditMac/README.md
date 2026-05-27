# DataAuditMac

Native macOS version of the Data Audit application, built with Swift and SwiftUI. A **1:1 replica** of the Python/React web application — processes reservation data locally and generates analytical reports without a web server or Python backend.

## Features

- **Visual Upload Screen**: Drag-and-drop file zones for the Booking Tool CSV and optional Historic One Sheet CSV. Includes Start/End Date pickers along with an **Academic Year** drop-down picker to easily set standard start/end date ranges.
- **Top Sheet Overview**: Metric cards (Total Reservations, Total Hours) with hover animations, followed by a structured data table with section title highlighting and semester column headers — matching the web app's styled HTML table.
- **Grouping Pairs**: Full collapsible data tables for Schools, Departments, and Rooms per semester. Shows **every column** from the data (not just editable fields). Supports column sorting (click headers), per-row "Include" checkbox, inline cell editing, multi-cell selection, and multi-row paste.
- **One Sheet Update**: Full scrollable table with purple AY row highlighting. "Download CSV" button for direct one-sheet export.
- **Filtered Bookings**: Two collapsible subsections — "Misformatted Rooms" (Room 000 records) and "Filtered Bookings" (all filtered records). Full data tables with editing, red background tint for excluded rows, filtered count badge.
- **Batched Edit Pipeline**: Edits are collected as pending changes (highlighted in yellow). "Save Changes" applies all at once and triggers recalculation. "Discard Changes" clears pending edits. Matches the web app's batch-save behavior exactly.
- **Auto-Export**: On initial upload, automatically saves the full export bundle to `~/Documents/` matching the Python app's auto-save behavior. Manual "Export Bundle" button also available.
- **Bundle Exporter**: Creates the date-labeled folder (`YYYY-MM-DD_to_YYYY-MM-DD_Data_Audit/`) with `Grouping_Pairs/` and `Other/` subfolders, Top Sheet CSV, Misformatted CSV, Other Schools CSV, and updated One Sheet CSV.
- **PDF Export**: Renders the Top Sheet as a high-quality PDF via native `ImageRenderer`. Fixed layout rendering perfectly matches the HTML structure but removes all scrolling constraints for a clean full-page render.

## How to Run

Your Mac already includes the Swift compiler (Apple Swift 6.2.3), so no additional installs are needed.

```bash
cd ~/Documents/DataAudit/DataAuditMac
swift run
```

This will download the `SwiftCSV` dependency, compile, and launch the application window.

## Debug / Comparison Mode

To compare Swift output against the Python/FastAPI backend numbers:

```bash
swift run DataAuditMac --debug /path/to/bookings.csv
```

This runs headless, processes the CSV with a wide date range (2024-2027), and prints per-semester, per-room, per-department, and per-school breakdowns to stdout.

## Project Structure

- `Package.swift` — Swift Package Manager configuration
- `Sources/DataAuditMac/` — Core source code
  - `Models/Reservation.swift` — Data model with multi-format date parsing
  - `Processing/DataProcessor.swift` — Filtering, hour calculation, department/school mapping, One Sheet generation
  - `Processing/CSVManager.swift` — CSV import/export, bundle directory generation
  - `Processing/PDFGenerator.swift` — PDF rendering via ImageRenderer
  - `Views/ContentView.swift` — Main app shell (upload screen, tab bar, edit pipeline)
  - `Views/TopSheetView.swift` — Metric cards + structured data table
  - `Views/GroupingPairsView.swift` — Per-semester collapsible data tables with full editing
  - `Views/FilteredBookingsView.swift` — Misformatted + Filtered subsections with full editing
  - `Views/OneSheetView.swift` — Historic one-sheet display with download
  - `Views/CollapsibleTableView.swift` — Reusable full-column table (sorting, multi-select, batch paste, edit tracking)

## Verification

Tested against `bookings_2026-04-13.csv` (5668 rows). All numbers match the Python/FastAPI version exactly:
- 710 filtered out, 4958 valid reservations
- 29,968.06 total calculated hours
- Per-semester, per-room, per-department, and per-school counts and hours all identical
