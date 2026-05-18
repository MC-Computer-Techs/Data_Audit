# DataAuditMac

Native macOS version of the Data Audit application, built with Swift and SwiftUI. Processes reservation data locally and generates analytical reports (Top Sheet Overview, Grouping Pairs, Filtered Bookings, etc.) without a web server or Python backend.

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
  - `Processing/DataProcessor.swift` — Filtering, hour calculation, department/school mapping
  - `Processing/CSVManager.swift` — CSV import/export using SwiftCSV
  - `Views/` — SwiftUI views (ContentView, TopSheetView, GroupingPairsView, etc.)

## Verification

Tested against `bookings_2026-04-13.csv` (5668 rows). All numbers match the Python/FastAPI version exactly:
- 710 filtered out, 4958 valid reservations
- 29,968.06 total calculated hours
- Per-semester, per-room, per-department, and per-school counts and hours all identical
