import re

with open("src/data_processor.py", "r") as f:
    content = f.read()

# Replace get_semester
old_get_semester = """def get_semester(date_obj, ay_start_year):
    if pd.isna(date_obj): return 'Other'
    year1 = ay_start_year
    year2 = ay_start_year + 1
    
    fall_start = pd.Timestamp(year=year1, month=9, day=1)
    fall_end = pd.Timestamp(year=year1, month=12, day=31)
    winter_start = pd.Timestamp(year=year2, month=1, day=1)
    winter_end = pd.Timestamp(year=year2, month=1, day=18)
    spring_start = pd.Timestamp(year=year2, month=1, day=19)
    spring_end = pd.Timestamp(year=year2, month=5, day=16)
    summer_start = pd.Timestamp(year=year2, month=5, day=17)
    summer_end = pd.Timestamp(year=year2, month=8, day=31)
    
    if fall_start <= date_obj <= fall_end: return f'Fall {year1}'
    if winter_start <= date_obj <= winter_end: return f'Winter {year2}'
    if spring_start <= date_obj <= spring_end: return f'Spring {year2}'
    if summer_start <= date_obj <= summer_end: return f'Summer {year2}'
    return 'Other'"""

new_get_semester = """def get_semester(date_obj):
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
        return f'Summer {year}'"""

content = content.replace(old_get_semester, new_get_semester)

# Replace process_reservations sig and logic
old_proc_res = """def process_reservations(df, ay_start_year):"""
new_proc_res = """def process_reservations(df, start_date, end_date):"""
content = content.replace(old_proc_res, new_proc_res)

old_filter_logic = """    df_raw['Semester'] = df_raw['Booking Start Date'].apply(lambda x: get_semester(x, ay_start_year))
    
    # Filter only for the current Academic Year
    semesters = [f'Fall {ay_start_year}', f'Winter {ay_start_year+1}', f'Spring {ay_start_year+1}', f'Summer {ay_start_year+1}']
    valid_semester = df_raw['Semester'].isin(semesters)
    df_raw.loc[~valid_semester, 'Filtered Out'] = True
    df_raw.loc[~valid_semester, 'Filter Reason'] += 'Outside AY Set Ranges; '
    
    # Create the valid subset to continue normal processing
    df = df_raw[~df_raw['Filtered Out']].copy()"""

new_filter_logic = """    df_raw['Semester'] = df_raw['Booking Start Date'].apply(get_semester)
    
    valid_date = (df_raw['Booking Start Date'].dt.date >= start_date) & (df_raw['Booking Start Date'].dt.date <= end_date)
    df_raw.loc[~valid_date, 'Filtered Out'] = True
    df_raw.loc[~valid_date, 'Filter Reason'] += 'Outside Selected Date Range; '
    
    # Create the valid subset to continue normal processing
    df = df_raw[~df_raw['Filtered Out']].copy()
    
    def get_semester_sort_key(sem_str):
        if sem_str == 'Other': return (9999, 9)
        term, year_str = sem_str.split(' ')
        term_order = {'Fall': 0, 'Winter': 1, 'Spring': 2, 'Summer': 3}
        return (int(year_str), term_order.get(term, 4))
        
    semesters = sorted([s for s in df['Semester'].unique() if s != 'Other'], key=get_semester_sort_key)"""
content = content.replace(old_filter_logic, new_filter_logic)

# generate_top_sheet signature
old_gen_ts = """def generate_top_sheet(df_pack, ay_start_year, semesters):"""
new_gen_ts = """def generate_top_sheet(df_pack, start_date, end_date, semesters):"""
content = content.replace(old_gen_ts, new_gen_ts)

old_ts_rows = """    ay_code = str(ay_start_year + 1)[-2:]
    total_res = len(df_overall)
    
    # Init structure
    output_rows = [
        ["Reservation Data Audit", "", "", "", "", ""],
        ["If some #'s don't match with the total nb, it's due to events hosted by multiple dptmnts.", "", "", "", "", ""],
        ["", semesters[0], semesters[1], semesters[2], semesters[3], f"AY{ay_code}, total:"],
        ["", "", "", "", "", ""],
        ["Total # of reservations:", "", "", "", "", total_res],
        ["", "", "", "", "", ""]
    ]"""
new_ts_rows = """    total_res = len(df_overall)
    date_str = f"{start_date.strftime('%b %Y')} - {end_date.strftime('%b %Y')}"
    
    # Init structure dynamically based on number of semesters
    padding = [""] * (len(semesters) + 1)
    output_rows = [
        [f"Reservation Data Audit ({date_str})"] + padding,
        ["If some #'s don't match with the total nb, it's due to events hosted by multiple dptmnts."] + padding,
        [""] + semesters + ["Total:"],
        [""] + padding,
        ["Total # of reservations:"] + [""] * len(semesters) + [total_res],
        [""] + padding
    ]"""
content = content.replace(old_ts_rows, new_ts_rows)

old_update_one_sheet = """def update_one_sheet(df_pack, one_sheet_path, ay_start_year):"""
new_update_one_sheet = """def update_one_sheet(df_pack, one_sheet_path, start_date):"""
content = content.replace(old_update_one_sheet, new_update_one_sheet)

old_os_ay_code = """    ay_code = f"AY{str(ay_start_year + 1)[-2:]}"
    prev_ay_code = f"AY{str(ay_start_year)[-2:]}\""""
new_os_ay_code = """    ay_start_year = start_date.year if start_date.month >= 9 else start_date.year - 1
    ay_code = f"AY{str(ay_start_year + 1)[-2:]}"
    prev_ay_code = f"AY{str(ay_start_year)[-2:]}\""""
content = content.replace(old_os_ay_code, new_os_ay_code)

old_excel = """def export_to_excel(df_pack, ay_start_year, top_sheet_df, semesters):"""
new_excel = """def export_to_excel(df_pack, start_date, end_date, top_sheet_df, semesters):"""
content = content.replace(old_excel, new_excel)

old_pdf = """def export_to_pdf(df_pack, ay_start_year, top_sheet_df, semesters, one_sheet_df=None):"""
new_pdf = """def export_to_pdf(df_pack, start_date, end_date, top_sheet_df, semesters, one_sheet_df=None):"""
content = content.replace(old_pdf, new_pdf)

old_pdf_title = """    # --- 1. Top Sheet ---
    elements.append(Paragraph(f"Data Audit Report: AY{str(ay_start_year)[-2:]}-{str(ay_start_year+1)[-2:]}", title_style))"""
new_pdf_title = """    # --- 1. Top Sheet ---
    date_str = f"{start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}"
    elements.append(Paragraph(f"Data Audit Report: {date_str}", title_style))"""
content = content.replace(old_pdf_title, new_pdf_title)

old_pdf_table = """    ts_table = Table(clean_ts_data, colWidths=[200, 80, 80, 80, 80, 80], repeatRows=3)"""
new_pdf_table = """    available_width = 712 - 200
    w = max(40, available_width / (len(semesters) + 1)) if len(semesters) + 1 > 0 else 80
    col_widths = [200] + [w] * (len(semesters) + 1)
    ts_table = Table(clean_ts_data, colWidths=col_widths, repeatRows=3)"""
content = content.replace(old_pdf_table, new_pdf_table)

old_proc_excel = """def process_excel_import(uploaded_file, ay_start_year):"""
new_proc_excel = """def process_excel_import(uploaded_file, start_date, end_date):"""
content = content.replace(old_proc_excel, new_proc_excel)

old_temp_pack1 = """        temp_pack, _ = process_reservations(raw_df, ay_start_year)"""
new_temp_pack1 = """        temp_pack, _ = process_reservations(raw_df, start_date, end_date)"""
content = content.replace(old_temp_pack1, new_temp_pack1)

old_final_pack = """    final_pack, final_sems = process_reservations(raw_df, ay_start_year)"""
new_final_pack = """    final_pack, final_sems = process_reservations(raw_df, start_date, end_date)"""
content = content.replace(old_final_pack, new_final_pack)

# Ensure "AY" check works correctly in export_to_pdf
old_ay_check = """        if "AY" in str(row[5]) or i == 2:"""
new_ay_check = """        if "Total:" in str(row[-1]) or i == 2:"""
content = content.replace(old_ay_check, new_ay_check)

with open("src/data_processor.py", "w") as f:
    f.write(content)

print("Patch applied.")
