import pandas as pd
import datetime

df = pd.DataFrame({'Time': ["14:00:00", "09:30:00"]})
df.to_excel("test_time.xlsx", index=False)
df2 = pd.read_excel("test_time.xlsx")
print(df2['Time'].tolist())
print(type(df2['Time'].iloc[0]))

# Also what if we export real data
df3 = pd.DataFrame({'Time': [datetime.time(14,0), datetime.time(9,30)]})
df3.to_excel("test_time2.xlsx", index=False)
df4 = pd.read_excel("test_time2.xlsx")
print(df4['Time'].tolist())
print(type(df4['Time'].iloc[0]))
