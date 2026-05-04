import pandas as pd
import datetime
from src.data_processor import process_reservations, export_to_excel, process_excel_import

# 1. Read raw CSV
df_csv = pd.read_csv('All_BT_Reservations.csv')
start_date = datetime.date(2024, 9, 1)
end_date = datetime.date(2025, 8, 31)

# 2. Process
pack1, sems1 = process_reservations(df_csv, start_date, end_date)
h1 = pack1['overall']['Calc Hours'].sum()
print("Hours from CSV:", h1)

# 3. Export to Excel
top_sheet = pd.DataFrame() # dummy
buf = export_to_excel(pack1, start_date, end_date, top_sheet, sems1)

# 4. Import from Excel
buf.seek(0)
pack2, sems2 = process_excel_import(buf, start_date, end_date)
h2 = pack2['overall']['Calc Hours'].sum()
print("Hours from Excel:", h2)

# Check why they differ!
df_raw1 = pack1['raw_annotated']
df_raw2 = pack2['raw_annotated']

print("df_raw1 ACTUAL hours sum:", df_raw1['ACTUAL hours'].sum())
print("df_raw2 ACTUAL hours sum:", df_raw2['ACTUAL hours'].sum())

