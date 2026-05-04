import pandas as pd
import datetime

t = datetime.time(14,0)
print(str(t))

dummy_date = "2000-01-01 "
print(pd.to_datetime(dummy_date + str(t), errors='coerce'))
