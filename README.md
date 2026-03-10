# Data Audit Web Application

This web application helps perform a data audit for academic year reservations from the Booking Tool. 

## Setup Instructions

This project uses `uv` for python dependency management.

1. Activate the virtual environment manually:
   ```bash
   source .venv/bin/activate
   ```
2. Run the application:
   ```bash
   streamlit run app.py
   ```

## Features
- Upload “ALL BT Reservations” CSV
- Specify an Academic Year
- Generate Grouping Pair Files (Schools, Departments, Rooms by Semesters F, W, Sp, Su)
- Consolidate Top Sheet and One Sheet
- Real-time updates and metrics tracking
