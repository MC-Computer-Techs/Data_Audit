# DataAuditMac

Native macOS application for auditing reservation data, built with Swift and SwiftUI. Processes Booking Tool CSV files locally and generates analytical reports — no web server or Python backend required.

## Features

- **Visual Upload Screen**: Drag-and-drop file zones for the Booking Tool CSV and optional Historic One Sheet CSV. Includes Start/End Date pickers along with an **Academic Year** drop-down picker to easily set standard start/end date ranges. Also supports importing a previously exported bundle folder to resume work.
- **Top Sheet Overview**: Metric cards (Total Reservations, Total Hours) with hover animations, followed by a structured data table with section title highlighting and semester column headers ordered by academic year (Fall → Winter → Spring → Summer).
- **Grouping Pairs**: Collapsible data tables for Schools, Departments, and Rooms per semester. Columns are displayed in canonical CSV export order with "Request #" first. **All cells are editable** — click any cell to type, select multiple cells, and copy/paste. Supports column sorting (click headers), per-row "Include" checkbox, multi-cell selection, and multi-row paste.
- **One Sheet Update**: Full scrollable table with purple AY row highlighting. "Download CSV" button for direct one-sheet export.
- **Filtered Bookings**: Four collapsible subsections — "No Shows", "Late Cancellations", "Misformatted Rooms" (Room 000 records), and "Other Filtered Bookings" (remaining filtered records). Full data tables with all cells editable, red background tint for excluded rows, filtered count badge, and an inline search bar (⌘F) for quick lookups.
- **Batched Edit Pipeline**: Edits are collected as pending changes (highlighted in yellow). "Save Changes" applies all at once and triggers recalculation. "Discard Changes" clears pending edits.
- **Export Bundle**: The "Export Bundle" button is the only way to save output data. A file picker lets you choose the destination directory. If a bundle folder with the same name already exists at that location, a confirmation dialog warns you before overwriting — preventing accidental data loss.
- **Bundle Contents**: Creates a date-labeled folder (`YYYY-MM-DD_to_YYYY-MM-DD_Data_Audit/`) containing:
  - `Grouping_Pairs/` — Per-semester Schools, Departments, and Rooms CSVs
  - `Other/` — Other Schools CSV and Misformatted Rooms CSV
  - `Raw_Data.csv` — All raw reservations for lossless re-import
  - `Top_Sheet_<dates>.csv` — Summary statistics
  - `One_Sheet_Updated_<AY>.csv` — Updated one-sheet (if historic data was provided)
- **PDF Export**: Renders the Top Sheet as a high-quality PDF via native `ImageRenderer`. All hour values are rounded to whole numbers, and totals are computed from the rounded figures so columns add up cleanly. Fixed layout rendering removes all scrolling constraints for a clean full-page render.

## How to Run

### Terminal (Quick Start)

Your Mac already includes the Swift compiler (Apple Swift 6.2.3), so no additional installs are needed.

```bash
cd ~/DataAudit
swift run
```

This will download the `SwiftCSV` dependency, compile, and launch the application window.

### Building a Standalone Executable with Xcode

1. **Open the project in Xcode**

2. **Build for Release**:
   - For an optimized release build, select **Product → Archive**
   - Select **Distribute Content** and click next on **Select a method for distribution** with **Custom** selected. Click next on **Build Products** and choose the export location   

   You can copy this binary anywhere on your Mac and run it directly — no Xcode or Swift toolchain required at runtime.

3. **Uploading to Google Drive**
   - Since Google Drive doesn't let you download files that can't be scanned, **Compress** the executable file into a zip file before uploading it so that it can be downloaded

4. **Running the downloaded file**
   - After downloading the zip file, it will automatically unpack the executable
   - Double click to run, and press cancel after the "Apple could not verify..." message appears
   - Navigate to **System Settings → Privacy & Security** and scroll to the bottom
   - Click **Allow** next to the message saying the app was "blocked to protect your mac"
   - Double click the application again and press **Open Anyway** to run the application

## Project Structure

```
DataAudit/
├── Package.swift                          # Swift Package Manager configuration
├── Package.resolved                       # Resolved dependency versions
├── Sources/
│   ├── DataAuditMac.swift                 # App entry point
│   ├── Models/
│   │   └── Reservation.swift              # Data model with multi-format date parsing
│   ├── Processing/
│   │   ├── DataProcessor.swift            # Filtering, hour calculation, dept/school mapping, One Sheet generation
│   │   ├── CSVManager.swift               # CSV import/export, bundle directory generation & import
│   │   └── PDFGenerator.swift             # PDF rendering via ImageRenderer
│   └── Views/
│       ├── ContentView.swift              # Main app shell (upload screen, tab bar, edit pipeline, export)
│       ├── TopSheetView.swift             # Metric cards + structured data table
│       ├── GroupingPairsView.swift         # Per-semester collapsible data tables with full editing
│       ├── FilteredBookingsView.swift      # Misformatted + Filtered subsections with full editing
│       ├── OneSheetView.swift             # Historic one-sheet display with download
│       └── CollapsibleTableView.swift     # Reusable full-column table (sorting, multi-select, batch paste, edit tracking)
└── README.md
```

## CSV Column Format

The application supports the current Booking Tool CSV format, where reservation status is determined by **individual timestamp columns** rather than parsing a comma-separated `End Event Status` string.

### Status Detection Columns

| Column | Purpose |
|--------|---------|
| `No Show At` | Booking is a no-show if this has a timestamp |
| `Canceled At` | Booking is canceled if this has a timestamp |
| `Checked In At` / `Checked Out At` | Booking was attended |
| `First Approved At` / `Final Approved At` | Booking was approved |
| `Declined At` | Booking was declined |
| `End Event Status` | Simple status label (e.g., "Approved") — retained as a display column |

### Filtering Logic

- **No Show**: `No Show At` column has a timestamp
- **Late Cancellation**: `Canceled At` has a timestamp within **24 hours** before the approved booking start time
- **Cancellation**: `Canceled At` has a timestamp (not late)
- **Declined**: `Declined At` has a timestamp
- **Approved**: `First Approved At` or `Final Approved At` has a timestamp, or the booking was checked in/out
- **Kept**: Booking has approval AND no rejection (no-show, cancellation, or decline)

### Service Columns

The CSV includes: `Equipment Services (Y/N)`, `Equipment Service Details`, `Staffing Services (Y/N)`, `Staffing Service Details`, `Cleaning Services (Y/N)`. Legacy `Media Services (Y/N)` / `Media Service Details` columns are also supported for backward compatibility with older CSV files.

## Dependencies

- [SwiftCSV](https://github.com/swiftcsv/SwiftCSV) (v0.8.1+) — CSV parsing and enumeration
