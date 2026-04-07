import pandas as pd
import numpy as np
import os
import csv
from pathlib import Path
import re
import io

from reportlab.lib import colors
from reportlab.lib.pagesizes import landscape, letter
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, PageBreak
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle

ROOM_MAPPING = {
    '1201': '1201 Seminar Room',
    '233': '233 Co-Lab',
    '230': '230 Audio Lab',
    '260': '260 Post Production Lab',
    '202': '202 Lecture Hall',
    '103': '103 Garage',
    '220': '220 Blackbox',
    '221': '221-224 Ballrooms',
    '222': '221-224 Ballrooms',
    '223': '221-224 Ballrooms',
    '224': '221-224 Ballrooms',
}

def clean_room(room_str):
    if pd.isna(room_str): return 'Other'
    s = str(room_str)
    if '1201' in s: return '1201 Seminar Room'
    if '233' in s: return '233 Co-Lab'
    if '230' in s: return '230 Audio Lab'
    if '260' in s: return '260 Post Production Lab'
    if '202' in s: return '202 Lecture Hall'
    if '103' in s: return '103 Garage'
    if '220' in s: return '220 Blackbox'
    if any(r in s for r in ['221', '222', '223', '224']): return '221-224 Ballrooms'
    return 'Other'

def clean_department(dept_str):
    if pd.isna(dept_str): return 'Other Group(s)'
    d = str(dept_str).strip()
    if 'ALT' in d: return 'ALT (Ed Leadership, ECT, and Higher and Post Secondary Education)'
    if 'CDI' in d: return 'CDI / Recorded Music'
    if 'ITP' in d or 'IMA' in d or 'Low Res' in d: return 'ITP / IMA / Low Res'
    if d in ['IDM', 'Music Tech', 'MARL', 'MPAP', 'Game Center']: return d
    if d == 'Community Partner': return d
    return d

def extract_departments(row):
    dept_str = str(row.get('Department', ''))
    title = str(row.get('Reservation Title', '')).lower()
    
    depts = set()
    
    # Existing department parsing
    if not pd.isna(row.get('Department')) and dept_str.strip() not in ['', 'nan', 'Other']:
        depts.add(clean_department(dept_str))
    else:    
        #re.search(pattern, main_string, re.IGNORECASE):
        # Infer missing or additional from title
        if word_in_title('itp', title) or word_in_title('ima', title) or word_in_title('low res', title): depts.add('ITP / IMA / Low Res')
        if word_in_title('idm', title) or word_in_title('tcs', title): depts.add('IDM')
        if word_in_title('music tech', title) or word_in_title('mtech', title): depts.add('Music Tech')
        if word_in_title('marl', title) or word_in_title('marl_', title) or word_in_title('marl-', title): depts.add('MARL')
        if word_in_title('cdi', title) or word_in_title('recorded music', title) or word_in_title('clive', title): depts.add('CDI / Recorded Music')
        if word_in_title('game center', title): depts.add('Game Center')
        if word_in_title('mpap', title): depts.add('MPAP')
        if word_in_title('alt', title) or word_in_title('alt-', title) or word_in_title('ect', title): depts.add('ALT (Ed Leadership, ECT, and Higher and Post Secondary Education)')
        
        if len(depts) == 0:
            depts.add('Other Group(s)')
        
    return list(depts)

def word_in_title(word, title):
    return re.search(r"\b" + re.escape(word) + r"\b", title, re.IGNORECASE)

def map_school(dept_str, school_str, title_str=""):
    d = clean_department(dept_str)
    if not pd.isna(school_str) and str(school_str).strip() != '':
        # Keep original if provided, but raw data has Role instead
        pass
    
    steinhardt_depts = ['ALT (Ed Leadership, ECT, and Higher and Post Secondary Education)', 'MARL', 'Music Tech', 'MPAP']
    tisch_depts = ['CDI / Recorded Music', 'Game Center', 'ITP / IMA / Low Res']
    tandon_depts = ['IDM']
    
    if d in steinhardt_depts: return 'Steinhardt'
    if d in tisch_depts: return 'Tisch'
    if d in tandon_depts: return 'Tandon'
    if d == 'Community Partner': return 'URPA / Community Partner'
    
    # Infer from title if department mapping fell through
    t = str(title_str).lower()
    if 'tisch' in t or 'film' in t or 'drama' in t: return 'Tisch'
    if 'steinhardt' in t: return 'Steinhardt'
    if any(kw in t for kw in ['tandon', 'cusp', 'ece', 'sase', 'nsbe', 'terra', 'csaw', 'mae seminar', 'cybersecurity']): return 'Tandon'
    
    return 'Other Schools'

def get_semester(date_obj, ay_start_year):
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
    return 'Other'

def get_semester_code(sem_str):
    if 'Fall' in sem_str: return f'F{sem_str[-2:]}'
    if 'Winter' in sem_str: return f'W{sem_str[-2:]}'
    if 'Spring' in sem_str: return f'Sp{sem_str[-2:]}'
    if 'Summer' in sem_str: return f'Su{sem_str[-2:]}'
    return 'Other'

def calc_capped_hours(row):
    try:
        start = row['Booking Start Date']
        end = row['Booking End Date']
        
        days_correction = 1
        if 'Booking Start Time' in row and 'Booking End Time' in row:
            st_str = str(row['Booking Start Time'])
            et_str = str(row['Booking End Time'])
            if st_str != 'nan' and et_str != 'nan':
                dummy = "2000-01-01 "
                s_dt = pd.to_datetime(dummy + st_str, errors='coerce')
                e_dt = pd.to_datetime(dummy + et_str, errors='coerce')
                if pd.notna(s_dt) and pd.notna(e_dt):
                    if (e_dt - s_dt).total_seconds() < 0:
                        days_correction = 0

        if pd.isna(start) or pd.isna(end): days = 1
        else: days = max(1, (end - start).days + days_correction)
        
        hours_col = 'ACTUAL hours' if 'ACTUAL hours' in row else 'Time In Use, Hours'
        raw_hours = pd.to_numeric(row[hours_col], errors='coerce')
        if pd.isna(raw_hours) or raw_hours < 0: raw_hours = 0
            
        rooms = pd.to_numeric(row['# rooms used'], errors='coerce')
        if pd.isna(rooms) or rooms < 1: rooms = 1
            
        # Capping each day at 12 hours max
        cap = days * 12 * rooms
        return min(raw_hours, cap)
    except:
        return 0

def process_reservations(df, ay_start_year):
    df_raw = df.copy()
    if '_raw_id' not in df_raw.columns:
        df_raw['_raw_id'] = range(len(df_raw))
        
        # FIX NATIVE CSV HOURS ON INITIAL IMPORT
        cols_to_fix = [c for c in ['ACTUAL hours', 'Time In Use, Hours'] if c in df_raw.columns]
        if not cols_to_fix:
            cols_to_fix = ['ACTUAL hours']
            df_raw['ACTUAL hours'] = 0.0
            
        time_cols = ['Booking Start Date', 'Booking End Date', 'Booking Start Time', 'Booking End Time']
        if all(col in df_raw.columns for col in time_cols):
            for idx in df_raw.index:
                try:
                    s_date = pd.to_datetime(df_raw.at[idx, 'Booking Start Date'], errors='coerce')
                    e_date = pd.to_datetime(df_raw.at[idx, 'Booking End Date'], errors='coerce')
                    if pd.isna(s_date) or pd.isna(e_date):
                        days = 1
                    else:
                        days = max(1, (e_date - s_date).days + 1)
                        
                    start_time_str = str(df_raw.at[idx, 'Booking Start Time'])
                    end_time_str = str(df_raw.at[idx, 'Booking End Time'])
                    
                    if start_time_str != 'nan' and end_time_str != 'nan':
                        dummy_date = "2000-01-01 "
                        start_dt = pd.to_datetime(dummy_date + start_time_str, errors='coerce')
                        end_dt = pd.to_datetime(dummy_date + end_time_str, errors='coerce')
                        
                        if pd.notna(start_dt) and pd.notna(end_dt):
                            hours_diff = (end_dt - start_dt).total_seconds() / 3600.0
                            
                            if hours_diff < 0:
                                hours_diff += 24.0
                                days_correction = 0
                            else:
                                days_correction = 1
                                
                            if pd.isna(s_date) or pd.isna(e_date):
                                days = 1
                            else:
                                days = max(1, (e_date - s_date).days + days_correction)
                                
                            rooms_val = pd.to_numeric(df_raw.at[idx, '# rooms used'], errors='coerce')
                            if pd.isna(rooms_val) or rooms_val < 1: rooms_val = 1
                            
                            hours_diff = (end_dt - start_dt).total_seconds() / 3600.0
                            if hours_diff < 0: hours_diff += 24.0
                            
                            # Enforce the strict 12-hour daily maximum per room natively
                            hours_diff = min(hours_diff, 12.0)
                            
                            total_hours = max(0, hours_diff) * days * rooms_val
                            for fix_col in cols_to_fix:
                                df_raw.at[idx, fix_col] = float(total_hours)
                except Exception:
                    pass
    
    # Track filter reasons
    df_raw['Filtered Out'] = False
    df_raw['Filter Reason'] = ''
    
    # 1. Filter Statuses per Reference.md
    if 'End Event Status' in df_raw.columns:
        valid_status = df_raw['End Event Status'].isin(['Approved', 'Checked out'])
        df_raw.loc[~valid_status, 'Filtered Out'] = True
        df_raw.loc[~valid_status, 'Filter Reason'] += 'Status not Approved/Checked out; '
    else:
        valid_status = pd.Series(True, index=df_raw.index)
        
    # 2. Exclude Maintenance
    if 'Booking Type' in df_raw.columns and 'Reservation Title' in df_raw.columns:
        maint_mask = df_raw['Booking Type'].astype(str).str.lower().str.contains('maintenance') | \
                    df_raw['Reservation Title'].astype(str).str.lower().str.contains('maintenance')
        df_raw.loc[maint_mask, 'Filtered Out'] = True
        df_raw.loc[maint_mask, 'Filter Reason'] += 'Maintenance; '
    else:
        maint_mask = pd.Series(False, index=df_raw.index)

    df_raw['Booking Start Date'] = pd.to_datetime(df_raw['Booking Start Date'], errors='coerce')
    df_raw['Booking End Date'] = pd.to_datetime(df_raw['Booking End Date'], errors='coerce')
    df_raw['Semester'] = df_raw['Booking Start Date'].apply(lambda x: get_semester(x, ay_start_year))
    
    # Filter only for the current Academic Year
    semesters = [f'Fall {ay_start_year}', f'Winter {ay_start_year+1}', f'Spring {ay_start_year+1}', f'Summer {ay_start_year+1}']
    valid_semester = df_raw['Semester'].isin(semesters)
    df_raw.loc[~valid_semester, 'Filtered Out'] = True
    df_raw.loc[~valid_semester, 'Filter Reason'] += 'Outside AY Set Ranges; '
    
    # Create the valid subset to continue normal processing
    df = df_raw[~df_raw['Filtered Out']].copy()
    
    df['Calc Hours'] = df.apply(calc_capped_hours, axis=1)
    
    # Split rooms manually for Room calculation
    room_rows = []
    for idx, row in df.iterrows():
        rooms_str = str(row.get('Room(s)', ''))
        rooms_list = [r.strip() for r in rooms_str.split(',')] if rooms_str.strip() not in ['', 'nan'] else ['Other']
        for r in rooms_list:
            new_row = row.copy()
            new_row['Clean Room'] = clean_room(r)
            # Adjust hours and rooms for the split context
            total_rooms = pd.to_numeric(row['# rooms used'], errors='coerce')
            if pd.isna(total_rooms) or total_rooms < 1: total_rooms = 1
            new_row['Calc Hours'] = row['Calc Hours'] / total_rooms
            room_rows.append(new_row)
    
    df_rooms = pd.DataFrame(room_rows).reset_index(drop=True)
    
    # Extract multiple departments from title per Reference.md
    df['All Depts'] = df.apply(extract_departments, axis=1)
    
    # Split departments for Dept/School calculation
    dept_rows = []
    for idx, row in df.iterrows():
        for d in row['All Depts']:
            new_row = row.copy()
            new_row['Clean Department'] = d
            new_row['Clean School'] = map_school(d, '', row.get('Reservation Title', ''))
            dept_rows.append(new_row)
            
    df_depts_schools = pd.DataFrame(dept_rows).reset_index(drop=True)
    
    # Store multiple dataframes back so export and Top Sheet can use them
    df_pack = {
        'overall': df,
        'rooms': df_rooms,
        'depts_schools': df_depts_schools,
        'raw_annotated': df_raw
    }
    
    return df_pack, semesters

def export_grouping_pairs(df_pack, output_dir):
    """Save subsets separated by Semester and sorted by School, Department, or Room."""
    os.makedirs(output_dir, exist_ok=True)
    generated_files = []
    
    df_depts_schools = df_pack['depts_schools']
    df_rooms = df_pack['rooms']
    
    semesters_list = df_pack['overall']['Semester'].unique()
    
    for sem in semesters_list:
        if sem == 'Other': continue
        sem_code = get_semester_code(sem)
        
        # Schools
        schools_df = df_depts_schools[df_depts_schools['Semester'] == sem].sort_values(by='Clean School')
        schools_path = os.path.join(output_dir, f"{sem_code}_Schools.csv")
        schools_df.to_csv(schools_path, index=False)
        generated_files.append(schools_path)
        
        # Depts
        depts_df = df_depts_schools[df_depts_schools['Semester'] == sem].sort_values(by='Clean Department')
        depts_path = os.path.join(output_dir, f"{sem_code}_Dpmts.csv")
        depts_df.to_csv(depts_path, index=False)
        generated_files.append(depts_path)
        
        # Rooms
        rooms_df = df_rooms[df_rooms['Semester'] == sem].sort_values(by='Clean Room')
        rooms_path = os.path.join(output_dir, f"{sem_code}_Rooms.csv")
        rooms_df.to_csv(rooms_path, index=False)
        generated_files.append(rooms_path)
        
    return generated_files

def generate_top_sheet(df_pack, ay_start_year, semesters):
    """Generate the structured Top Sheet."""
    df_overall = df_pack['overall']
    df_rooms = df_pack['rooms']
    df_depts_schools = df_pack['depts_schools']
    
    ay_code = str(ay_start_year + 1)[-2:]
    total_res = len(df_overall)
    
    # Init structure
    output_rows = [
        ["Reservation Data Audit", "", "", "", "", ""],
        ["If some #'s don't match with the total nb, it's due to events hosted by multiple dptmnts.", "", "", "", "", ""],
        ["", semesters[0], semesters[1], semesters[2], semesters[3], f"AY{ay_code}, total:"],
        ["", "", "", "", "", ""],
        ["Total # of reservations:", "", "", "", "", total_res],
        ["", "", "", "", "", ""]
    ]
    
    overall_hours = [round(df_overall[df_overall['Semester'] == s]['Calc Hours'].sum(), 2) for s in semesters]
    overall_res = [len(df_overall[df_overall['Semester'] == s]) for s in semesters]
    
    output_rows.append(["Hours"] + overall_hours + [round(sum(overall_hours), 2)])
    output_rows.append(["Reservations"] + overall_res + [sum(overall_res)])
    output_rows.append(["", "", "", "", "", ""])
    
    def add_section(title, category_col, entity_list, df_target):
        output_rows.append([title, "", "", "", "", ""])
        for entity in entity_list:
            res_counts = [len(df_target[(df_target[category_col] == entity) & (df_target['Semester'] == s)]) for s in semesters]
            if sum(res_counts) > 0 or True: # Keep zero rows for format consistency
                output_rows.append([entity] + res_counts + [sum(res_counts)])
            
    def add_hours_section(title, category_col, entity_list, df_target):
        output_rows.append([title, "", "", "", "", ""])
        for entity in entity_list:
            hr_counts = [round(df_target[(df_target[category_col] == entity) & (df_target['Semester'] == s)]['Calc Hours'].sum(), 2) for s in semesters]
            output_rows.append([entity] + hr_counts + [round(sum(hr_counts), 2)])

    room_order = ['1201 Seminar Room', '233 Co-Lab', '230 Audio Lab', '221-224 Ballrooms', '220 Blackbox', '202 Lecture Hall', '103 Garage', '260 Post Production Lab']
    add_section("Reservations per room:", "Clean Room", room_order, df_rooms)
    add_hours_section("Hours per room:", "Clean Room", room_order, df_rooms)
    
    prog_order = ['ALT (Ed Leadership, ECT, and Higher and Post Secondary Education)', 'IDM', 'ITP / IMA / Low Res', 'CDI / Recorded Music', 'Music Tech', 'MARL', 'MPAP', 'Game Center', 'Other Group(s)', 'Community Partner']
    add_section("Reservations per program:", "Clean Department", prog_order, df_depts_schools)
    add_hours_section("Hours per Program:", "Clean Department", prog_order, df_depts_schools)
    
    school_order = ['Tandon', 'Tisch', 'Steinhardt', 'Provost', 'URPA / Community Partner', 'Central', 'Other Schools']
    add_section("Reservations per School:", "Clean School", school_order, df_depts_schools)
    output_rows.append(["", "", "", "", "", ""])
    add_hours_section("Hours per School:", "Clean School", school_order, df_depts_schools)
    
    top_sheet_df = pd.DataFrame(output_rows)
    return top_sheet_df

def update_one_sheet(df_pack, one_sheet_path, ay_start_year):
    """
    Reads the existing One Sheet CSV, appends a new row for AY(ay_start_year+1) under
    each of the sections (Overall, By Department, By School, By Space).
    Returns the new DataFrame or raises error if structure is unexpected.
    """
    df_overall = df_pack['overall']
    df_rooms = df_pack['rooms']
    df_depts_schools = df_pack['depts_schools']
    
    ay_code = f"AY{str(ay_start_year + 1)[-2:]}"
    prev_ay_code = f"AY{str(ay_start_year)[-2:]}"
    
    with open(one_sheet_path, 'r') as f:
        reader = csv.reader(f)
        lines = list(reader)
    
    output_lines = []
    
    i = 0
    while i < len(lines):
        line = lines[i]
        output_lines.append(line)
        
        # Check if this line is the LAST row of a chunk for the previous academic year.
        if len(line) > 1 and line[1].strip() == prev_ay_code:
            entity = line[2].strip()
            
            # Category detection based on entity name
            cat_col = None
            if entity == "All of Media Commons":
                cat_col = "Overall"
            elif entity in ['ALT ', 'IDM', 'ITP / IMA / Low Res', 'CDI / Recorded Music', 'Music Tech', 'MARL', 'Game Center', 'Community Partner', 'Other Group(s)']:
                cat_col = "Clean Department"
            elif entity in ['Tandon', 'Tisch', 'Steinhardt', 'Other School']:
                cat_col = "Clean School"
            else:
                cat_col = "Clean Room"
            
            clean_entity = entity.strip()
            if cat_col == "Overall":
                res_count = len(df_overall)
                hs_count = df_overall['Calc Hours'].sum()
            elif cat_col == "Clean Department":
                search_entity = 'ALT (Ed Leadership, ECT, and Higher and Post Secondary Education)' if clean_entity == 'ALT' else clean_entity
                subset = df_depts_schools[df_depts_schools[cat_col] == search_entity]
                res_count = len(subset)
                hs_count = subset['Calc Hours'].sum()
            elif cat_col == "Clean School":
                search_entity = 'Other Schools' if clean_entity == 'Other School' else clean_entity
                subset = df_depts_schools[df_depts_schools[cat_col] == search_entity]
                res_count = len(subset)
                hs_count = subset['Calc Hours'].sum()
            else:
                # Clean Room
                subset = df_rooms[df_rooms[cat_col] == clean_entity]
                res_count = len(subset)
                hs_count = subset['Calc Hours'].sum()
            
            # Calculate % change from previous year
            prev_res_str = line[3].replace(',', '') if len(line) > 3 and line[3] else "0"
            try:
                prev_res = float(prev_res_str)
            except:
                prev_res = 0.0
                
            if prev_res > 0:
                pct_change = ((res_count - prev_res) / prev_res) * 100
                pct_str = f"{pct_change:.2f}%"
            else:
                pct_str = ""
            
            new_row = ["", ay_code, entity, str(res_count), f"{hs_count:.2f}", pct_str, "", "", ""]
            
            # Pad new_row to match line length
            while len(new_row) < len(line):
                new_row.append("")
                
            output_lines.append(new_row)
            
        i += 1
            
    updated_df = pd.DataFrame(output_lines)
    return updated_df

def export_to_excel(df_pack, ay_start_year, top_sheet_df, semesters):
    """
    Export the full data audit to an Excel file represented as a BytesIO buffer.
    """
    buf = io.BytesIO()
    with pd.ExcelWriter(buf, engine='xlsxwriter') as writer:
        # Sheet 1: Top Sheet
        top_sheet_df.to_excel(writer, sheet_name='Top Sheet', index=False, header=False)
        worksheet = writer.sheets['Top Sheet']
        worksheet.set_column(0, 0, 40)
        worksheet.set_column(1, 5, 20)
        
        # Sheet 2: Raw Data (Hidden)
        raw_df = df_pack['raw_annotated'].copy()
        raw_df.to_excel(writer, sheet_name='Raw Data', index=False)
        writer.sheets['Raw Data'].hide()
        
        # Grouping Pairs Sheets
        df_depts_schools = df_pack['depts_schools']
        df_rooms = df_pack['rooms']
        semesters_list = df_pack['overall']['Semester'].unique()
        
        for sem in semesters_list:
            if sem == 'Other': continue
            sem_code = get_semester_code(sem)
            
            schools_df = df_depts_schools[df_depts_schools['Semester'] == sem].sort_values(by='Clean School')
            schools_df.to_excel(writer, sheet_name=f"{sem_code}_Schools", index=False)
            
            depts_df = df_depts_schools[df_depts_schools['Semester'] == sem].sort_values(by='Clean Department')
            depts_df.to_excel(writer, sheet_name=f"{sem_code}_Dpmts", index=False)
            
            rooms_df = df_rooms[df_rooms['Semester'] == sem].sort_values(by='Clean Room')
            rooms_df.to_excel(writer, sheet_name=f"{sem_code}_Rooms", index=False)
            
    buf.seek(0)
    return buf

def process_excel_import(uploaded_file, ay_start_year):
    """
    Process an uploaded Excel file, applying any edits made in the grouping sheets
    back to the raw data, and process it entirely.
    """
    xls = pd.ExcelFile(uploaded_file)
    sheet_names = xls.sheet_names
    
    raw_df = pd.read_excel(uploaded_file, sheet_name='Raw Data')
    # Pandas read_excel handles datetimes well but coerce to be safe on main cols
    raw_df['Booking Start Date'] = pd.to_datetime(raw_df['Booking Start Date'], errors='coerce')
    raw_df['Booking End Date'] = pd.to_datetime(raw_df['Booking End Date'], errors='coerce')
    
    for sheet in sheet_names:
        if sheet in ['Top Sheet', 'Raw Data']: continue
        
        edited_df = pd.read_excel(uploaded_file, sheet_name=sheet)
        if '_raw_id' not in edited_df.columns:
            continue
            
        temp_pack, _ = process_reservations(raw_df, ay_start_year)
        
        if '_Schools' in sheet: original_df = temp_pack['depts_schools']
        elif '_Dpmts' in sheet: original_df = temp_pack['depts_schools']
        elif '_Rooms' in sheet: original_df = temp_pack['rooms']
        else: continue
            
        edited_df = edited_df.sort_values('_raw_id').reset_index(drop=True)
        orig_subset = original_df[original_df['_raw_id'].isin(edited_df['_raw_id'])].sort_values('_raw_id').reset_index(drop=True)
        
        # To avoid issues with float nan vs empty string, filling na before diff might be safer or using the same na comparison
        if len(edited_df) == len(orig_subset):
            changed_mask = edited_df != orig_subset
            changed_mask = changed_mask & ~(edited_df.isna() & orig_subset.isna())
            
            for idx in changed_mask.index[changed_mask.any(axis=1)]:
                raw_id = orig_subset.loc[idx, '_raw_id']
                time_edited = False
                for col in changed_mask.columns[changed_mask.loc[idx]]:
                    new_val = edited_df.loc[idx, col]
                    mapped_col = col
                    if col == 'Clean Department': mapped_col = 'Department'
                    elif col == 'Clean Room': mapped_col = 'Room(s)'
                    elif col == 'Clean School': continue
                    elif col == 'Calc Hours':
                        mapped_col = 'ACTUAL hours' if 'ACTUAL hours' in raw_df.columns else 'Time In Use, Hours'
                    
                    if mapped_col in ['Booking Start Date', 'Booking End Date', 'Booking Start Time', 'Booking End Time']:
                        time_edited = True
                        
                    if mapped_col in raw_df.columns:
                        mask = raw_df['_raw_id'] == raw_id
                        raw_df.loc[mask, mapped_col] = new_val
                        
                if time_edited:
                    mask = raw_df['_raw_id'] == raw_id
                    row_data = raw_df.loc[mask].iloc[0]
                    try:
                        s_date = pd.to_datetime(row_data.get('Booking Start Date', pd.NaT))
                        e_date = pd.to_datetime(row_data.get('Booking End Date', pd.NaT))
                        if pd.isna(s_date) or pd.isna(e_date):
                            days = 1
                        
                        dummy_date = "2000-01-01 "
                        start_time_str = str(row_data.get('Booking Start Time', '00:00'))
                        end_time_str = str(row_data.get('Booking End Time', '00:00'))
                        start_dt = pd.to_datetime(dummy_date + start_time_str, errors='coerce')
                        end_dt = pd.to_datetime(dummy_date + end_time_str, errors='coerce')
                        
                        if not pd.isna(start_dt) and not pd.isna(end_dt):
                            hours_diff = (end_dt - start_dt).total_seconds() / 3600.0
                            
                            if hours_diff < 0:
                                hours_diff += 24.0
                                days_correction = 0
                            else:
                                days_correction = 1
                                
                            if pd.isna(s_date) or pd.isna(e_date):
                                days = 1
                            else:
                                days = max(1, (e_date - s_date).days + days_correction)
                                
                            rooms_val = pd.to_numeric(row_data.get('# rooms used', 1), errors='coerce')
                            if pd.isna(rooms_val) or rooms_val < 1: rooms_val = 1
                            
                            hours_diff = min(hours_diff, 12.0)
                            total_hours = max(0, hours_diff) * days * rooms_val
                        else:
                            total_hours = 0
                            
                        cols_to_update = [c for c in ['ACTUAL hours', 'Time In Use, Hours'] if c in raw_df.columns]
                        if not cols_to_update: cols_to_update = ['ACTUAL hours']
                        for c in cols_to_update:
                            raw_df.loc[mask, c] = total_hours
                    except Exception:
                        pass
                        
    final_pack, final_sems = process_reservations(raw_df, ay_start_year)
    return final_pack, final_sems

def export_to_pdf(df_pack, ay_start_year, top_sheet_df, semesters, one_sheet_df=None):
    """
    Export the full data audit to a beautifully formatted PDF buffer using ReportLab.
    """
    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf, pagesize=landscape(letter),
        rightMargin=40, leftMargin=40, topMargin=40, bottomMargin=40
    )
    elements = []
    
    styles = getSampleStyleSheet()
    title_style = styles['Title']
    h2_style = styles['Heading2']
    h3_style = styles['Heading3']
    
    # --- 1. Top Sheet ---
    elements.append(Paragraph(f"Data Audit Report: AY{str(ay_start_year)[-2:]}-{str(ay_start_year+1)[-2:]}", title_style))
    elements.append(Spacer(1, 20))
    
    ts_data = top_sheet_df.fillna("").astype(str).values.tolist()
    
    # Styles for the first column to handle text-wrapping and indentation
    ts_cell_style = ParagraphStyle(
        'TS_Cell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=10,
        leading=12,
        leftIndent=10  # Indent the typical rows
    )
    
    ts_bold_style = ParagraphStyle(
        'TS_Bold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=12,
        leftIndent=0,
        textColor=colors.black
    )
    
    ts_header_style = ParagraphStyle(
        'TS_Header',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=12,
        leftIndent=0,
        textColor=colors.whitesmoke,
        alignment=1 # Center
    )

    clean_ts_data = []
    for i, row in enumerate(ts_data):
        clean_row = []
        
        # Check condition for how to style column 0
        val0 = str(row[0])
        is_bold_section = False
        is_header_row = False
        
        if "Total #" in val0 or "Hours" == val0 or "Reservations" == val0:
            is_bold_section = True
        elif val0.strip() and not str(row[1]).strip() and not str(row[2]).strip() and val0.strip() != "Reservation Data Audit" and val0.strip() != "If some #'s don't match with the total nb, it's due to events hosted by multiple dptmnts.":
            is_bold_section = True
            
        if "AY" in str(row[5]) or i == 2:
            is_header_row = True
            
        for col_idx, x in enumerate(row):
            val = str(x).replace('.0', '') if str(x).endswith('.0') else str(x)
            
            # Wrap first column in Paragraph for automatic text wrapping & indentation
            if col_idx == 0 and val.strip() and val.strip() != "Reservation Data Audit" and not val.strip().startswith("If some"):
                if is_header_row:
                    clean_row.append(Paragraph(val, ts_header_style))
                elif is_bold_section:
                    clean_row.append(Paragraph(val, ts_bold_style))
                else:
                    clean_row.append(Paragraph(val, ts_cell_style))
            else:
                clean_row.append(val)
                
        clean_ts_data.append(clean_row)
        
    ts_table = Table(clean_ts_data, colWidths=[200, 80, 80, 80, 80, 80], repeatRows=3)
    
    # Style the Top Sheet
    ts_style = TableStyle([
        ('FONTNAME', (0,0), (-1,-1), 'Helvetica'),
        ('FONTSIZE', (0,0), (-1,-1), 10),
        ('ALIGN', (1,0), (-1,-1), 'CENTER'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('GRID', (0,2), (-1,-1), 0.5, colors.lightgrey),
        ('BOX', (0,2), (-1,-1), 1.5, colors.HexColor('#2c3e50')),
    ])
    
    # Highlight specific header structures
    for i, row in enumerate(ts_data):
        val0 = str(row[0]).strip()
        if val0 and not str(row[1]).strip() and not str(row[2]).strip():
            # Section separators / titles
            if val0 != "Reservation Data Audit" and not val0.startswith("If some"):
                ts_style.add('FONTNAME', (0, i), (-1, i), 'Helvetica-Bold')
                ts_style.add('BACKGROUND', (0, i), (-1, i), colors.HexColor('#ecf0f1'))
                ts_style.add('BOX', (0, i), (-1, i), 1, colors.HexColor('#bdc3c7'))
        
        if "AY" in str(row[5]) or i == 2:
            # Column header row
            ts_style.add('FONTNAME', (0, i), (-1, i), 'Helvetica-Bold')
            ts_style.add('BACKGROUND', (0, i), (-1, i), colors.HexColor('#2980b9'))
            ts_style.add('TEXTCOLOR', (0, i), (-1, i), colors.whitesmoke)
            ts_style.add('ALIGN', (0, i), (-1, i), 'CENTER')
            
        if "Total #" in val0 or "Hours" == val0 or "Reservations" == val0:
            ts_style.add('FONTNAME', (0,i), (-1,i), 'Helvetica-Bold')

    ts_table.setStyle(ts_style)
    elements.append(ts_table)
    elements.append(Spacer(1, 30))
    
    # --- 2. Grouping Pairs ---
    # Due to width, we'll selectively output heavily referenced columns
    target_cols = ['Reservation Title', 'Booking Start Date', 'Clean Department', 'Clean School', 'Clean Room', 'Calc Hours']
    
    df_depts_schools = df_pack['depts_schools'].copy()
    
    def df_to_table(df_subset, table_title):
        elements.append(PageBreak())
        elements.append(Paragraph(table_title, h2_style))
        elements.append(Spacer(1, 10))
        
        cols_to_use = [c for c in target_cols if c in df_subset.columns]
        df_display = df_subset[cols_to_use].copy()
        
        for c in ['Booking Start Date', 'Booking End Date']:
            if c in df_display.columns:
                df_display[c] = pd.to_datetime(df_display[c], errors='coerce').dt.strftime('%Y-%m-%d')
                
        if 'Calc Hours' in df_display.columns:
            df_display['Calc Hours'] = df_display['Calc Hours'].round(2).astype(str)
            
        df_display = df_display.fillna("")
        df_display = df_display.astype(str)
        
        cell_style = styles['Normal']
        cell_style.fontSize = 8
        cell_style.leading = 10
        
        header_style = ParagraphStyle(
            'Header',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=8,
            textColor=colors.whitesmoke,
            alignment=0
        )
        
        data = []
        # Header row
        header_row = [Paragraph(c, header_style) for c in df_display.columns]
        data.append(header_row)
        
        # Data rows
        for _, row in df_display.iterrows():
            para_row = [Paragraph(str(val), cell_style) for val in row]
            data.append(para_row)
            
        col_widths = []
        for c in cols_to_use:
            if c == 'Reservation Title': col_widths.append(192)
            elif c == 'Booking Start Date': col_widths.append(70)
            elif c == 'Clean Department': col_widths.append(150)
            elif c == 'Clean School': col_widths.append(100)
            elif c == 'Clean Room': col_widths.append(140)
            elif c == 'Calc Hours': col_widths.append(60)
            else: col_widths.append(100)
            
        t = Table(data, colWidths=col_widths, repeatRows=1)
        
        style = TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#34495e')),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 8),
            ('TOPPADDING', (0, 0), (-1, 0), 8),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#bdc3c7')),
        ])
        
        # Add alternating row colors for data
        for i in range(1, len(data)):
            if i % 2 == 0:
                style.add('BACKGROUND', (0, i), (-1, i), colors.HexColor('#f9f9f9'))
                
        t.setStyle(style)
        elements.append(t)
    
    semesters_list = df_pack['overall']['Semester'].unique()
    for sem in semesters_list:
        if sem == 'Other': continue
        sem_code = get_semester_code(sem)
        schools_df = df_depts_schools[df_depts_schools['Semester'] == sem].sort_values(by=['Clean School', 'Clean Department'])
        df_to_table(schools_df, f"{sem_code} (Records)")
        
    # --- 3. One Sheet ---
    if one_sheet_df is not None:
        elements.append(PageBreak())
        elements.append(Paragraph("One Sheet Update", h2_style))
        elements.append(Spacer(1, 10))
        
        os_data = one_sheet_df.fillna("").astype(str).values.tolist()
        
        # Apply paragraph wrapping for One Sheet to avoid overflow
        cell_style = styles['Normal']
        cell_style.fontSize = 8
        
        wrapped_os_data = []
        for line in os_data:
            wrapped_os_data.append([Paragraph(str(val), cell_style) for val in line])
            
        os_table = Table(wrapped_os_data, colWidths=[90, 60, 160, 60, 60, 60, 60, 60, 90], repeatRows=1)
        
        os_style = TableStyle([
            ('FONTNAME', (0,0), (-1,-1), 'Helvetica'),
            ('FONTSIZE', (0,0), (-1,-1), 8),
            ('GRID', (0,0), (-1,-1), 0.5, colors.grey),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ])
        
        for i, row in enumerate(os_data):
            if "Term" in str(row[1]) or "AY" in str(row[1]) and i == 0:
                os_style.add('BACKGROUND', (0, i), (-1, i), colors.HexColor('#8e44ad'))
            elif str(row[1]).strip() == "":
                os_style.add('BACKGROUND', (0, i), (-1, i), colors.HexColor('#ecf0f1'))

        os_table.setStyle(os_style)
        elements.append(os_table)
        
    doc.build(elements)
    buf.seek(0)
    return buf
