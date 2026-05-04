from fastapi import FastAPI, UploadFile, File, Form, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, FileResponse
import pandas as pd
import uuid
import datetime
import io
import os
import tempfile
import json
from typing import Optional

from src.data_processor import (
    process_reservations, 
    generate_top_sheet, 
    update_one_sheet, 
    export_to_excel, 
    process_excel_import, 
    export_to_pdf,
    export_grouping_pairs
)

app = FastAPI(title="Data Audit Tool API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # For development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory store for sessions
sessions = {}

def get_session(session_id: str):
    if session_id not in sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    return sessions[session_id]

@app.post("/api/upload")
async def upload_files(
    start_date: str = Form(...),
    end_date: str = Form(...),
    csv_file: Optional[UploadFile] = File(None),
    excel_file: Optional[UploadFile] = File(None),
    one_sheet_file: Optional[UploadFile] = File(None)
):
    try:
        s_date = datetime.datetime.strptime(start_date, "%Y-%m-%d").date()
        e_date = datetime.datetime.strptime(end_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")

    if not csv_file and not excel_file:
        raise HTTPException(status_code=400, detail="Must provide either a CSV file or an Excel file")

    try:
        # Process the main data file
        if excel_file:
            contents = await excel_file.read()
            processed_df, semesters = process_excel_import(io.BytesIO(contents), s_date, e_date)
        else:
            contents = await csv_file.read()
            df = pd.read_csv(io.BytesIO(contents))
            processed_df, semesters = process_reservations(df, s_date, e_date)

        # Process one sheet if provided
        one_sheet_updated_df = None
        one_sheet_bytes = None
        if one_sheet_file:
            one_sheet_bytes = await one_sheet_file.read()
            with tempfile.NamedTemporaryFile(delete=False, suffix=".csv") as tmp:
                tmp.write(one_sheet_bytes)
                tmp_path = tmp.name
            
            one_sheet_updated_df = update_one_sheet(processed_df, tmp_path, s_date)
            os.remove(tmp_path)

        # Generate top sheet
        top_sheet_df = generate_top_sheet(processed_df, s_date, e_date, semesters)

        session_id = str(uuid.uuid4())
        
        sessions[session_id] = {
            "processed_df": processed_df,
            "raw_df": processed_df['raw_annotated'].copy(),
            "semesters": semesters,
            "start_date": s_date,
            "end_date": e_date,
            "top_sheet_df": top_sheet_df,
            "one_sheet_updated_df": one_sheet_updated_df,
            "one_sheet_bytes": one_sheet_bytes
        }

        # Also write the data locally exactly like Streamlit did so user has files on their machine
        base_dir = f"{s_date.strftime('%Y-%m-%d')}_to_{e_date.strftime('%Y-%m-%d')}_Data_Audit"
        os.makedirs(base_dir, exist_ok=True)
        
        grouping_dir = os.path.join(base_dir, "Grouping_Pairs")
        export_grouping_pairs(processed_df, grouping_dir)
        
        other_dir = os.path.join(base_dir, "Other")
        os.makedirs(other_dir, exist_ok=True)
        df_depts = processed_df['depts_schools']
        other_schools_df = df_depts[df_depts['Clean School'] == 'Other Schools']
        other_schools_path = os.path.join(other_dir, "Other_Schools.csv")
        other_schools_df.to_csv(other_schools_path, index=False)

        ts_path = os.path.join(base_dir, f"Top_Sheet_{s_date.strftime('%Y-%m-%d')}_to_{e_date.strftime('%Y-%m-%d')}.csv")
        top_sheet_df.to_csv(ts_path, index=False, header=False)
        
        if one_sheet_updated_df is not None:
            ay_start_year_inf = s_date.year if s_date.month >= 9 else s_date.year - 1
            os_path = os.path.join(base_dir, f"One_Sheet_Updated_AY{str(ay_start_year_inf)[-2:]}-{str(ay_start_year_inf+1)[-2:]}.csv")
            one_sheet_updated_df.to_csv(os_path, index=False, header=False)

        sessions[session_id]['base_dir'] = base_dir
        sessions[session_id]['grouping_dir'] = grouping_dir

        return {
            "session_id": session_id,
            "message": f"Processing Complete! Files saved locally in `{base_dir}` directory."
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/session/{session_id}/summary")
def get_summary(session_id: str):
    session = get_session(session_id)
    top_sheet_df = session['top_sheet_df']
    df_overall = session['processed_df']['overall']
    
    # Send the raw top sheet as a list of lists so the frontend can render it nicely
    ts_data = top_sheet_df.fillna("").astype(str).values.tolist()
    
    total_reservations = len(df_overall)
    total_hours = round(df_overall['Calc Hours'].sum(), 2)

    return {
        "start_date": session['start_date'].isoformat(),
        "end_date": session['end_date'].isoformat(),
        "semesters": session['semesters'],
        "total_reservations": total_reservations,
        "total_hours": total_hours,
        "top_sheet_data": ts_data
    }

@app.get("/api/session/{session_id}/groupings")
def get_groupings(session_id: str):
    session = get_session(session_id)
    
    processed_df = session['processed_df']
    df_depts_schools = processed_df['depts_schools']
    df_rooms = processed_df['rooms']
    semesters = session['semesters']

    def get_sem_code(sem_str):
        if 'Fall' in sem_str: return f'F{sem_str[-2:]}'
        if 'Winter' in sem_str: return f'W{sem_str[-2:]}'
        if 'Spring' in sem_str: return f'Sp{sem_str[-2:]}'
        if 'Summer' in sem_str: return f'Su{sem_str[-2:]}'
        return 'Other'

    groupings = []
    
    for sem in processed_df['overall']['Semester'].unique():
        if sem == 'Other': continue
        sem_code = get_sem_code(sem)
        
        schools_df = df_depts_schools[df_depts_schools['Semester'] == sem].sort_values(by='Clean School').fillna("")
        depts_df = df_depts_schools[df_depts_schools['Semester'] == sem].sort_values(by='Clean Department').fillna("")
        rooms_df = df_rooms[df_rooms['Semester'] == sem].sort_values(by='Clean Room').fillna("")
        
        groupings.append({
            "semester": sem,
            "semester_code": sem_code,
            "schools": schools_df.to_dict(orient="records"),
            "departments": depts_df.to_dict(orient="records"),
            "rooms": rooms_df.to_dict(orient="records")
        })

    return {"groupings": groupings}

@app.post("/api/session/{session_id}/groupings")
async def update_groupings(session_id: str, payload: dict):
    # Payload format: {"edits": [{"raw_id": 123, "column": "Clean School", "value": "Tisch"}, ...]}
    session = get_session(session_id)
    raw_df = session['raw_df']
    
    edits = payload.get("edits", [])
    if not edits:
        return {"message": "No edits provided"}

    changes_made = False

    for edit in edits:
        raw_id = edit['raw_id']
        col = edit['column']
        new_val = edit['value']
        
        mapped_col = col
        if col == 'Clean Department': mapped_col = 'Department'
        elif col == 'Clean Room': mapped_col = 'Room(s)'
        elif col == 'Clean School': continue # Derived strictly from Department
        elif col == 'Calc Hours':
            mapped_col = 'ACTUAL hours' if 'ACTUAL hours' in raw_df.columns else 'Time In Use, Hours'

        time_edited = mapped_col in ['Booking Start Date', 'Booking End Date', 'Booking Start Time', 'Booking End Time']

        if mapped_col in raw_df.columns:
            mask = raw_df['_raw_id'] == raw_id
            
            # Coerce to string if target column expects string
            if new_val is not None and not isinstance(new_val, str):
                if pd.api.types.is_string_dtype(raw_df[mapped_col]):
                    if isinstance(new_val, float) and new_val.is_integer():
                        new_val = str(int(new_val))
                    else:
                        new_val = str(new_val)
                        
            raw_df.loc[mask, mapped_col] = new_val
            changes_made = True
            
        if time_edited:
            mask = raw_df['_raw_id'] == raw_id
            row_data = raw_df.loc[mask].iloc[0]
            try:
                s_date = pd.to_datetime(row_data.get('Booking Start Date', pd.NaT))
                e_date = pd.to_datetime(row_data.get('Booking End Date', pd.NaT))
                
                dummy_date = "2000-01-01 "
                start_time_str = str(row_data.get('Booking Start Time', '00:00'))
                end_time_str = str(row_data.get('Booking End Time', '00:00'))
                start_dt = pd.to_datetime(dummy_date + start_time_str, errors='coerce')
                end_dt = pd.to_datetime(dummy_date + end_time_str, errors='coerce')
                
                if not pd.isna(start_dt) and not pd.isna(end_dt):
                    hours_diff = (end_dt - start_dt).total_seconds() / 3600.0
                    if hours_diff < 0: hours_diff += 24.0
                    days_correction = 0 if hours_diff < 0 else 1
                    days = 1 if (pd.isna(s_date) or pd.isna(e_date)) else max(1, (e_date - s_date).days + days_correction)
                    
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

    if changes_made:
        # Reprocess
        s_date = session['start_date']
        e_date = session['end_date']
        
        new_processed, new_sems = process_reservations(raw_df, s_date, e_date)
        new_top_sheet = generate_top_sheet(new_processed, s_date, e_date, new_sems)
        
        session['processed_df'] = new_processed
        session['semesters'] = new_sems
        session['top_sheet_df'] = new_top_sheet
        
        # Regenerate files locally
        base_dir = session['base_dir']
        export_grouping_pairs(new_processed, session['grouping_dir'])
        
        ts_local_path = os.path.join(base_dir, f"Top_Sheet_{s_date.strftime('%Y-%m-%d')}_to_{e_date.strftime('%Y-%m-%d')}.csv")
        new_top_sheet.to_csv(ts_local_path, index=False, header=False)
        
        if session['one_sheet_bytes'] is not None:
            with tempfile.NamedTemporaryFile(delete=False, suffix=".csv") as tmp:
                tmp.write(session['one_sheet_bytes'])
                tmp_path = tmp.name
            
            new_os_updated = update_one_sheet(new_processed, tmp_path, s_date)
            os.remove(tmp_path)
            session['one_sheet_updated_df'] = new_os_updated
            
            ay_start_year_inf = s_date.year if s_date.month >= 9 else s_date.year - 1
            os_path = os.path.join(base_dir, f"One_Sheet_Updated_AY{str(ay_start_year_inf)[-2:]}-{str(ay_start_year_inf+1)[-2:]}.csv")
            new_os_updated.to_csv(os_path, index=False, header=False)

    return {"message": "Changes saved and data recalculated"}

@app.get("/api/session/{session_id}/onesheet")
def get_one_sheet(session_id: str):
    session = get_session(session_id)
    os_df = session['one_sheet_updated_df']
    if os_df is None:
        return {"data": None}
    
    return {"data": os_df.fillna("").astype(str).values.tolist()}

@app.get("/api/session/{session_id}/filtered")
def get_filtered(session_id: str):
    session = get_session(session_id)
    raw_df = session['processed_df']['raw_annotated']
    
    filtered_df = raw_df[raw_df['Filtered Out'] == True].fillna("")
    
    return {
        "total_filtered": len(filtered_df),
        "data": filtered_df.to_dict(orient="records")
    }

@app.get("/api/download/{session_id}/pdf")
def download_pdf(session_id: str):
    session = get_session(session_id)
    pdf_buf = export_to_pdf(
        session['processed_df'], 
        session['start_date'], 
        session['end_date'], 
        session['top_sheet_df'], 
        session['semesters'], 
        session['one_sheet_updated_df']
    )
    
    filename = f"Top_Sheet_{session['start_date'].strftime('%Y-%m-%d')}_to_{session['end_date'].strftime('%Y-%m-%d')}.pdf"
    
    return StreamingResponse(
        pdf_buf, 
        media_type="application/pdf", 
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )

@app.get("/api/download/{session_id}/excel")
def download_excel(session_id: str):
    session = get_session(session_id)
    excel_buf = export_to_excel(
        session['processed_df'], 
        session['start_date'], 
        session['end_date'], 
        session['top_sheet_df'], 
        session['semesters']
    )
    
    filename = f"Data_Audit_{session['start_date'].strftime('%Y-%m-%d')}_to_{session['end_date'].strftime('%Y-%m-%d')}.xlsx"
    
    return StreamingResponse(
        excel_buf, 
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", 
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )

@app.get("/api/download/{session_id}/onesheet_csv")
def download_onesheet_csv(session_id: str):
    session = get_session(session_id)
    os_df = session['one_sheet_updated_df']
    if os_df is None:
        raise HTTPException(status_code=404, detail="No One Sheet available")
    
    s_date = session['start_date']
    ay_start_year_inf = s_date.year if s_date.month >= 9 else s_date.year - 1
    filename = f"One_Sheet_Updated_AY{str(ay_start_year_inf)[-2:]}-{str(ay_start_year_inf+1)[-2:]}.csv"
    
    csv_buf = io.StringIO()
    os_df.to_csv(csv_buf, index=False, header=False)
    csv_buf.seek(0)
    
    return StreamingResponse(
        csv_buf, 
        media_type="text/csv", 
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )
