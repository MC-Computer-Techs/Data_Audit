import re

with open("src/app.py", "r") as f:
    content = f.read()

# Replace lines 19-24
old_input = """if not st.session_state.data_processed:
    ay_start_year = st.number_input("Academic Year Starting Year (e.g., 2024 for AY24-25)", min_value=2015, max_value=2050, value=2024)
else:
    ay_start_year = st.session_state.ay_start_year
    st.info(f"**Academic Year:** AY{str(ay_start_year)[-2:]}-{str(ay_start_year+1)[-2:]} *(Locked after processing)*")"""
new_input = """if not st.session_state.data_processed:
    c1, c2 = st.columns(2)
    with c1:
        start_date = st.date_input("Start Date", value=datetime.date(2024, 9, 1))
    with c2:
        end_date = st.date_input("End Date", value=datetime.date(2025, 8, 31))
else:
    start_date = st.session_state.start_date
    end_date = st.session_state.end_date
    st.info(f"**Date Range:** {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')} *(Locked after processing)*")"""
content = content.replace(old_input, new_input)

# Replace lines 41-44
old_call = """                if excel_file is not None:
                    processed_df, semesters = process_excel_import(excel_file, ay_start_year)
                else:
                    df = pd.read_csv(uploaded_file)
                    processed_df, semesters = process_reservations(df, ay_start_year)"""
new_call = """                if excel_file is not None:
                    processed_df, semesters = process_excel_import(excel_file, start_date, end_date)
                else:
                    df = pd.read_csv(uploaded_file)
                    processed_df, semesters = process_reservations(df, start_date, end_date)"""
content = content.replace(old_call, new_call)

content = content.replace(
    """                base_dir = f"{ay_start_year}-{ay_start_year+1}_Data_Audit\"""",
    """                base_dir = f"{start_date.strftime('%Y-%m-%d')}_to_{end_date.strftime('%Y-%m-%d')}_Data_Audit\""""
)

old_ts_gen = """                # 4. Generate Top Sheet
                top_sheet_df = generate_top_sheet(processed_df, ay_start_year, semesters)
                ts_path = os.path.join(base_dir, f"Top_Sheet_{ay_start_year}-{ay_start_year+1}.csv")"""
new_ts_gen = """                # 4. Generate Top Sheet
                top_sheet_df = generate_top_sheet(processed_df, start_date, end_date, semesters)
                ts_path = os.path.join(base_dir, f"Top_Sheet_{start_date.strftime('%Y-%m-%d')}_to_{end_date.strftime('%Y-%m-%d')}.csv")"""
content = content.replace(old_ts_gen, new_ts_gen)

old_os_gen = """                    one_sheet_updated_df = update_one_sheet(processed_df, temp_os_path, ay_start_year)
                    os_path = os.path.join(base_dir, f"One_Sheet_Updated_AY{str(ay_start_year)[-2:]}-{str(ay_start_year+1)[-2:]}.csv")"""
new_os_gen = """                    one_sheet_updated_df = update_one_sheet(processed_df, temp_os_path, start_date)
                    ay_start_year_inf = start_date.year if start_date.month >= 9 else start_date.year - 1
                    os_path = os.path.join(base_dir, f"One_Sheet_Updated_AY{str(ay_start_year_inf)[-2:]}-{str(ay_start_year_inf+1)[-2:]}.csv")"""
content = content.replace(old_os_gen, new_os_gen)

content = content.replace(
    """                st.session_state.ay_start_year = ay_start_year""",
    """                st.session_state.start_date = start_date
                st.session_state.end_date = end_date"""
)

content = content.replace(
    """            st.subheader(f"Top Sheet: AY {ay_start_year}-{ay_start_year+1}")""",
    """            st.subheader(f"Top Sheet: {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}")"""
)

old_dl_pdf = """                pdf_buf = export_to_pdf(processed_df, ay_start_year, top_sheet_df, semesters, one_sheet_updated_df)
                st.download_button(
                    label="Download Top Sheet (PDF)",
                    data=pdf_buf.getvalue(),
                    file_name=f"Top_Sheet_{ay_start_year}-{ay_start_year+1}.pdf",
                    mime="application/pdf",
                    type="primary"
                )"""
new_dl_pdf = """                pdf_buf = export_to_pdf(processed_df, start_date, end_date, top_sheet_df, semesters, one_sheet_updated_df)
                st.download_button(
                    label="Download Top Sheet (PDF)",
                    data=pdf_buf.getvalue(),
                    file_name=f"Top_Sheet_{start_date.strftime('%Y-%m-%d')}_to_{end_date.strftime('%Y-%m-%d')}.pdf",
                    mime="application/pdf",
                    type="primary"
                )"""
content = content.replace(old_dl_pdf, new_dl_pdf)

old_dl_xl = """                excel_buf = export_to_excel(processed_df, ay_start_year, top_sheet_df, semesters)
                st.download_button(
                    label="Download Full Audit (Excel)",
                    data=excel_buf.getvalue(),
                    file_name=f"Data_Audit_{ay_start_year}-{ay_start_year+1}.xlsx","""
new_dl_xl = """                excel_buf = export_to_excel(processed_df, start_date, end_date, top_sheet_df, semesters)
                st.download_button(
                    label="Download Full Audit (Excel)",
                    data=excel_buf.getvalue(),
                    file_name=f"Data_Audit_{start_date.strftime('%Y-%m-%d')}_to_{end_date.strftime('%Y-%m-%d')}.xlsx","""
content = content.replace(old_dl_xl, new_dl_xl)

old_reproc = """                    # 1. Reprocess all data from the modified master raw_df
                    new_processed, new_sems = process_reservations(st.session_state.raw_df, st.session_state.ay_start_year)
                    st.session_state.processed_df = new_processed
                    st.session_state.semesters = new_sems
                    
                    # 2. Regenerate Top Sheet
                    new_top_sheet = generate_top_sheet(new_processed, st.session_state.ay_start_year, new_sems)
                    st.session_state.top_sheet_df = new_top_sheet
                    
                    # 3. Re-export CSV files silently to keep the local disk cache synced
                    export_grouping_pairs(new_processed, st.session_state.grouping_dir)
                    ts_local_path = os.path.join(st.session_state.base_dir, f"Top_Sheet_{st.session_state.ay_start_year}-{st.session_state.ay_start_year+1}.csv")
                    new_top_sheet.to_csv(ts_local_path, index=False, header=False)
                    
                    # 4. Regenerate One Sheet if it was provided
                    if st.session_state.one_sheet_bytes is not None:
                        temp_os_path = os.path.join(st.session_state.base_dir, "temp_one_sheet.csv")
                        with open(temp_os_path, "wb") as f:
                            f.write(st.session_state.one_sheet_bytes)
                        new_os_updated = update_one_sheet(new_processed, temp_os_path, st.session_state.ay_start_year)
                        st.session_state.one_sheet_updated_df = new_os_updated
                        os_path = os.path.join(st.session_state.base_dir, f"One_Sheet_Updated_AY{str(st.session_state.ay_start_year)[-2:]}-{str(st.session_state.ay_start_year+1)[-2:]}.csv")"""
new_reproc = """                    # 1. Reprocess all data from the modified master raw_df
                    new_processed, new_sems = process_reservations(st.session_state.raw_df, st.session_state.start_date, st.session_state.end_date)
                    st.session_state.processed_df = new_processed
                    st.session_state.semesters = new_sems
                    
                    # 2. Regenerate Top Sheet
                    new_top_sheet = generate_top_sheet(new_processed, st.session_state.start_date, st.session_state.end_date, new_sems)
                    st.session_state.top_sheet_df = new_top_sheet
                    
                    # 3. Re-export CSV files silently to keep the local disk cache synced
                    export_grouping_pairs(new_processed, st.session_state.grouping_dir)
                    ts_local_path = os.path.join(st.session_state.base_dir, f"Top_Sheet_{st.session_state.start_date.strftime('%Y-%m-%d')}_to_{st.session_state.end_date.strftime('%Y-%m-%d')}.csv")
                    new_top_sheet.to_csv(ts_local_path, index=False, header=False)
                    
                    # 4. Regenerate One Sheet if it was provided
                    if st.session_state.one_sheet_bytes is not None:
                        temp_os_path = os.path.join(st.session_state.base_dir, "temp_one_sheet.csv")
                        with open(temp_os_path, "wb") as f:
                            f.write(st.session_state.one_sheet_bytes)
                        new_os_updated = update_one_sheet(new_processed, temp_os_path, st.session_state.start_date)
                        st.session_state.one_sheet_updated_df = new_os_updated
                        ay_start_year_inf = st.session_state.start_date.year if st.session_state.start_date.month >= 9 else st.session_state.start_date.year - 1
                        os_path = os.path.join(st.session_state.base_dir, f"One_Sheet_Updated_AY{str(ay_start_year_inf)[-2:]}-{str(ay_start_year_inf+1)[-2:]}.csv")"""
content = content.replace(old_reproc, new_reproc)

old_os_tab = """            if one_sheet_updated_df is not None:
                st.write(f"The historic One Sheet has been updated with AY{str(ay_start_year+1)[-2:]} metrics.")
                st.dataframe(one_sheet_updated_df)
                
                csv_buffer_os = io.StringIO()
                one_sheet_updated_df.to_csv(csv_buffer_os, index=False, header=False)
                st.download_button(
                    label="Download Updated One Sheet CSV",
                    data=csv_buffer_os.getvalue(),
                    file_name=f"One_Sheet_Updated_AY{str(ay_start_year)[-2:]}-{str(ay_start_year+1)[-2:]}.csv","""
new_os_tab = """            if one_sheet_updated_df is not None:
                ay_start_year_inf = start_date.year if start_date.month >= 9 else start_date.year - 1
                st.write(f"The historic One Sheet has been updated with AY{str(ay_start_year_inf+1)[-2:]} metrics based on the start date.")
                st.dataframe(one_sheet_updated_df)
                
                csv_buffer_os = io.StringIO()
                one_sheet_updated_df.to_csv(csv_buffer_os, index=False, header=False)
                st.download_button(
                    label="Download Updated One Sheet CSV",
                    data=csv_buffer_os.getvalue(),
                    file_name=f"One_Sheet_Updated_AY{str(ay_start_year_inf)[-2:]}-{str(ay_start_year_inf+1)[-2:]}.csv","""
content = content.replace(old_os_tab, new_os_tab)

with open("src/app.py", "w") as f:
    f.write(content)

print("App patch applied.")
