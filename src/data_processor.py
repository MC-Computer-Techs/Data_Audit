import pandas as pd
import numpy as np
import os
import csv
from pathlib import Path

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
        
    # Infer missing or additional from title
    if 'itp' in title or 'ima' in title or 'low res' in title: depts.add('ITP / IMA / Low Res')
    if 'idm' in title: depts.add('IDM')
    if 'music tech' in title or 'mtech' in title: depts.add('Music Tech')
    if 'marl ' in title or 'marl_' in title or 'marl-' in title: depts.add('MARL')
    if 'cdi ' in title or 'recorded music' in title or 'clive' in title: depts.add('CDI / Recorded Music')
    if 'game center' in title: depts.add('Game Center')
    if 'mpap ' in title: depts.add('MPAP')
    if 'alt ' in title or 'alt-' in title or 'ect ' in title: depts.add('ALT (Ed Leadership, ECT, and Higher and Post Secondary Education)')
    
    if len(depts) == 0:
        depts.add('Other Group(s)')
        
    return list(depts)

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
        if pd.isna(start) or pd.isna(end): days = 1
        else: days = max(1, (end - start).days + 1)
        
        hours_col = 'ACTUAL hours' if 'ACTUAL hours' in row else 'Time In Use, Hours'
        raw_hours = pd.to_numeric(row[hours_col], errors='coerce')
        if pd.isna(raw_hours) or raw_hours < 0: raw_hours = 0
            
        rooms = pd.to_numeric(row['# rooms used'], errors='coerce')
        if pd.isna(rooms) or rooms < 1: rooms = 1
            
        # Capping each day at 12 hours max
        # min(raw_hours, days * 12 * rooms) assuming raw_hours is total aggregate
        cap = days * 12 * rooms
        return min(raw_hours, cap)
    except:
        return 0

def process_reservations(df, ay_start_year):
    df_raw = df.copy()
    if '_raw_id' not in df_raw.columns:
        df_raw['_raw_id'] = range(len(df_raw))
    
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
