import pandas as pd

# Test Top Sheet logic
row = ["1201 Seminar Room", "12.34", "15", "0.0", "", "Fall 2024"]
clean_row = []
for col_idx, x in enumerate(row):
    val = str(x)
    if col_idx > 0:
        try:
            f_val = float(val)
            val = str(int(round(f_val)))
        except ValueError:
            pass
    clean_row.append(val)
print("Top Sheet:", clean_row)

# Test One Sheet logic
line = ["", "AY24", "All of Media Commons", "150", "345.67", "12.5%", "", "", ""]
try:
    if line[4]:
        f_val = float(line[4].replace(',', ''))
        line[4] = str(int(round(f_val)))
except ValueError:
    pass
print("One Sheet:", line)
