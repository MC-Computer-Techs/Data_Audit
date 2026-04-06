import pandas as pd
import io

# create sample df
df = pd.DataFrame({'_raw_id': [0, 1, 2], 'Clean Department': ['A', 'B', 'C'], 'Calc Hours': [1.0, 2.0, 3.0]})

# test excel export to bytes
buf = io.BytesIO()
with pd.ExcelWriter(buf, engine='xlsxwriter') as writer:
    df.to_excel(writer, sheet_name='Raw Data', index=False)
    # create a hidden sheet
    writer.sheets['Raw Data'].hide()
    
buf.seek(0)
# test import
read_df = pd.read_excel(buf, sheet_name='Raw Data')
print("Imported DF columns:", read_df.columns.tolist())
print(read_df)
