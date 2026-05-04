import pandas as pd
dummy_date = "2000-01-01 "
start_time_str = "1899-12-31 14:00:00"
start_dt = pd.to_datetime(dummy_date + start_time_str, errors='coerce')
print("Parsed:", start_dt, pd.isna(start_dt))
