import pandas as pd

def get_semester(date_obj):
    if pd.isna(date_obj): return 'Other'
    year = date_obj.year
    month = date_obj.month
    day = date_obj.day
    
    if month >= 9:
        return f'Fall {year}'
    elif month == 1 and day <= 18:
        return f'Winter {year}'
    elif month == 1 and day > 18:
        return f'Spring {year}'
    elif 2 <= month <= 4:
        return f'Spring {year}'
    elif month == 5 and day <= 16:
        return f'Spring {year}'
    else:
        return f'Summer {year}'

dates = [
    pd.Timestamp(2024, 9, 1),
    pd.Timestamp(2024, 12, 31),
    pd.Timestamp(2025, 1, 15),
    pd.Timestamp(2025, 1, 20),
    pd.Timestamp(2025, 3, 10),
    pd.Timestamp(2025, 5, 16),
    pd.Timestamp(2025, 5, 17),
    pd.Timestamp(2025, 8, 30),
]
for d in dates:
    print(d, get_semester(d))
