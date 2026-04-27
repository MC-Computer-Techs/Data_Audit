import re

with open("src/app.py", "r") as f:
    content = f.read()

old_logic = """if 'ay_start_year' not in st.session_state:
    st.session_state.ay_start_year = 2024
if 'start_date' not in st.session_state:
    st.session_state.start_date = datetime.date(2024, 9, 1)
if 'end_date' not in st.session_state:
    st.session_state.end_date = datetime.date(2025, 8, 31)

def on_ay_change():
    ay = st.session_state.ay_input_key
    st.session_state.ay_start_year = ay
    st.session_state.start_date = datetime.date(ay, 9, 1)
    st.session_state.end_date = datetime.date(ay + 1, 8, 31)

def on_date_change():
    st.session_state.start_date = st.session_state.start_date_key
    st.session_state.end_date = st.session_state.end_date_key
    ay_inf = st.session_state.start_date.year if st.session_state.start_date.month >= 9 else st.session_state.start_date.year - 1
    st.session_state.ay_start_year = ay_inf

disabled = st.session_state.data_processed

st.number_input(
    "Academic Year Starting Year (e.g., 2024 for AY24-25)", 
    min_value=2015, max_value=2050, 
    value=st.session_state.ay_start_year,
    key='ay_input_key',
    on_change=on_ay_change,
    disabled=disabled
)

c1, c2 = st.columns(2)
with c1:
    st.date_input("Start Date", value=st.session_state.start_date, key='start_date_key', on_change=on_date_change, disabled=disabled)
with c2:
    st.date_input("End Date", value=st.session_state.end_date, key='end_date_key', on_change=on_date_change, disabled=disabled)

start_date = st.session_state.start_date
end_date = st.session_state.end_date"""

new_logic = """if 'ay_input_key' not in st.session_state:
    st.session_state.ay_input_key = 2024
if 'start_date_key' not in st.session_state:
    st.session_state.start_date_key = datetime.date(2024, 9, 1)
if 'end_date_key' not in st.session_state:
    st.session_state.end_date_key = datetime.date(2025, 8, 31)

def on_ay_change():
    ay = st.session_state.ay_input_key
    st.session_state.start_date_key = datetime.date(ay, 9, 1)
    st.session_state.end_date_key = datetime.date(ay + 1, 8, 31)

def on_date_change():
    ay_inf = st.session_state.start_date_key.year if st.session_state.start_date_key.month >= 9 else st.session_state.start_date_key.year - 1
    st.session_state.ay_input_key = ay_inf

disabled = st.session_state.data_processed

st.number_input(
    "Academic Year Starting Year (e.g., 2024 for AY24-25)", 
    min_value=2015, max_value=2050, 
    key='ay_input_key',
    on_change=on_ay_change,
    disabled=disabled
)

c1, c2 = st.columns(2)
with c1:
    st.date_input("Start Date", key='start_date_key', on_change=on_date_change, disabled=disabled)
with c2:
    st.date_input("End Date", key='end_date_key', on_change=on_date_change, disabled=disabled)

start_date = st.session_state.start_date_key
end_date = st.session_state.end_date_key"""

content = content.replace(old_logic, new_logic)

with open("src/app.py", "w") as f:
    f.write(content)

print("Patch applied")
