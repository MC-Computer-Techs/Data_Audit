import streamlit as st
import pandas as pd
import os
import io
import datetime
from data_processor import process_reservations, export_grouping_pairs, generate_top_sheet, update_one_sheet

st.set_page_config(page_title="Data Audit Tool", layout="wide")

st.title("Reservation Data Audit Application")
st.markdown("Upload the Booking Tool reservations CSV file to generate Grouping Pairs, Top Sheet, and One Sheet stats.")

ay_start_year = st.number_input("Academic Year Starting Year (e.g., 2024 for AY24-25)", min_value=2015, max_value=2050, value=2024)

col1, col2 = st.columns(2)
with col1:
    uploaded_file = st.file_uploader("Upload 'Booking Tool Reservations' CSV", type=['csv'])
with col2:
    one_sheet_file = st.file_uploader("Upload Historic 'One Sheet' CSV (Optional)", type=['csv'])

if uploaded_file is not None:
    st.success("File uploaded successfully!")
    
    if st.button("Process Data"):
        with st.spinner("Processing data..."):
            try:
                # 1. Read input
                df = pd.read_csv(uploaded_file)
                
                # 2. Process to add Semesters, Room/Dept/School clean
                processed_df, semesters = process_reservations(df, ay_start_year)
                
                # 3. Create outputs directory
                base_dir = f"{ay_start_year}-{ay_start_year+1}_Data_Audit"
                grouping_dir = os.path.join(base_dir, "Grouping_Pairs")
                
                # We'll save files locally just in case, but also provide them for download in UI
                if not os.path.exists(grouping_dir):
                    os.makedirs(grouping_dir, exist_ok=True)
                
                generated_files = export_grouping_pairs(processed_df, grouping_dir)
                
                # 3b. Export "Other Schools" subset
                other_dir = os.path.join(base_dir, "Other")
                os.makedirs(other_dir, exist_ok=True)
                df_depts = processed_df['depts_schools']
                other_schools_df = df_depts[df_depts['Clean School'] == 'Other Schools']
                other_schools_path = os.path.join(other_dir, "Other_Schools.csv")
                other_schools_df.to_csv(other_schools_path, index=False)

                # 4. Generate Top Sheet
                top_sheet_df = generate_top_sheet(processed_df, ay_start_year, semesters)
                ts_path = os.path.join(base_dir, f"Top_Sheet_{ay_start_year}-{ay_start_year+1}.csv")
                top_sheet_df.to_csv(ts_path, index=False, header=False)
                
                # 4b. Update One Sheet (if provided)
                one_sheet_updated_df = None
                if one_sheet_file is not None:
                    # Save the uploaded one sheet temporarily to read with standard python csv reader
                    temp_os_path = os.path.join(base_dir, "temp_one_sheet.csv")
                    with open(temp_os_path, "wb") as f:
                        f.write(one_sheet_file.getbuffer())
                        
                    one_sheet_updated_df = update_one_sheet(processed_df, temp_os_path, ay_start_year)
                    os_path = os.path.join(base_dir, f"One_Sheet_Updated_AY{str(ay_start_year)[-2:]}-{str(ay_start_year+1)[-2:]}.csv")
                    one_sheet_updated_df.to_csv(os_path, index=False, header=False)
                
                st.success(f"Processing Complete! Files saved locally in `{base_dir}` directory.")
                
                # 5. UI Tabs
                tab1, tab2, tab3 = st.tabs(["Top Sheet Overview", "Grouping Pairs", "One Sheet Update"])
                
                with tab1:
                    st.subheader(f"Top Sheet: AY {ay_start_year}-{ay_start_year+1}")
                    
                    # Provide download button for the fully formatted Top Sheet CSV at the top
                    csv_buffer = io.StringIO()
                    top_sheet_df.to_csv(csv_buffer, index=False, header=False)
                    st.download_button(
                        label="Download Full Top Sheet CSV",
                        data=csv_buffer.getvalue(),
                        file_name=f"Top_Sheet_{ay_start_year}-{ay_start_year+1}.csv",
                        mime="text/csv",
                        type="primary"
                    )
                    
                    st.divider()
                    
                    # High level metrics
                    col1, col2 = st.columns(2)
                    with col1:
                        st.metric("Total Reservations", len(processed_df['overall']))
                    with col2:
                        st.metric("Total Hours", round(processed_df['overall']['Calc Hours'].sum(), 2))
                        
                    st.divider()
                    
                    # Helper to generate pretty view dataframe from df_pack subsets
                    def display_top_sheet_section(title, category_col, entity_list, df_target, is_hours=False):
                        st.markdown(f"**{title}**")
                        rows = []
                        for entity in entity_list:
                            # Reservations and Hours per semester
                            sem_data = {}
                            total_qty = 0
                            for s in semesters:
                                subset = df_target[(df_target[category_col] == entity) & (df_target['Semester'] == s)]
                                if not is_hours:
                                    qty = len(subset)
                                else:
                                    qty = round(subset['Calc Hours'].sum(), 2)
                                sem_data[s] = qty
                                total_qty += qty
                            
                            row_data = {category_col: entity}
                            row_data.update(sem_data)
                            row_data['Total'] = round(total_qty, 2) if is_hours else total_qty
                            rows.append(row_data)
                            
                        # Convert to df and display
                        section_df = pd.DataFrame(rows)
                        st.dataframe(section_df, use_container_width=True, hide_index=True)

                    st.markdown("### Top Sheet Breakdown")
                    st.write("Summary totals by Space, Department, and School.")
                    
                    df_overall = processed_df['overall']
                    df_rooms = processed_df['rooms']
                    df_depts_schools = processed_df['depts_schools']
                    
                    # Rooms
                    room_order = ['1201 Seminar Room', '233 Co-Lab', '230 Audio Lab', '221-224 Ballrooms', '220 Blackbox', '202 Lecture Hall', '103 Garage', '260 Post Production Lab']
                    rc1, rc2 = st.columns(2)
                    with rc1: display_top_sheet_section("Reservations per Room", "Clean Room", room_order, df_rooms)
                    with rc2: display_top_sheet_section("Hours per Room", "Clean Room", room_order, df_rooms, is_hours=True)
                    
                    # Programs
                    prog_order = ['ALT (Ed Leadership, ECT, and Higher and Post Secondary Education)', 'IDM', 'ITP / IMA / Low Res', 'CDI / Recorded Music', 'Music Tech', 'MARL', 'MPAP', 'Game Center', 'Other Group(s)', 'Community Partner']
                    pc1, pc2 = st.columns(2)
                    with pc1: display_top_sheet_section("Reservations per Program", "Clean Department", prog_order, df_depts_schools)
                    with pc2: display_top_sheet_section("Hours per Program", "Clean Department", prog_order, df_depts_schools, is_hours=True)
                    
                    # Schools
                    school_order = ['Tandon', 'Tisch', 'Steinhardt', 'Provost', 'URPA / Community Partner', 'Central', 'Other Schools']
                    sc1, sc2 = st.columns(2)
                    with sc1: display_top_sheet_section("Reservations per School", "Clean School", school_order, df_depts_schools)
                    with sc2: display_top_sheet_section("Hours per School", "Clean School", school_order, df_depts_schools, is_hours=True)

                with tab2:
                    st.subheader("Generated Grouping Pairs")
                    st.write("These tables divide the reservations by semester, then by School, Department, or Room:")
                    
                    # Organize grouping pairs visually with expanders
                    for fp in generated_files:
                        fname = os.path.basename(fp)
                        # Remove .csv for a cleaner title
                        clean_title = fname.replace('.csv', '').replace('_', ' ')
                        with st.expander(f"📄 {clean_title}"):
                            # Read and display data beautifully
                            df_group = pd.read_csv(fp)
                            st.dataframe(df_group, use_container_width=True, hide_index=True)
                            
                            # Provide download button below the table
                            with open(fp, "rb") as f:
                                st.download_button(
                                    label=f"Download {fname}",
                                    data=f,
                                    file_name=fname,
                                    mime="text/csv",
                                    key=fname
                                )
                
                with tab3:
                    st.subheader("One Sheet Update")
                    if one_sheet_file is not None and one_sheet_updated_df is not None:
                        st.write(f"The historic One Sheet has been updated with AY{str(ay_start_year+1)[-2:]} metrics.")
                        st.dataframe(one_sheet_updated_df)
                        
                        csv_buffer_os = io.StringIO()
                        one_sheet_updated_df.to_csv(csv_buffer_os, index=False, header=False)
                        st.download_button(
                            label="Download Updated One Sheet CSV",
                            data=csv_buffer_os.getvalue(),
                            file_name=f"One_Sheet_Updated_AY{str(ay_start_year)[-2:]}-{str(ay_start_year+1)[-2:]}.csv",
                            mime="text/csv"
                        )
                    else:
                        st.write("Please upload the Historic One Sheet CSV in the uploader above to automatically append this year's metrics to it.")
                        # Currently we show the current year's high level metrics
                        st.metric("Total Reservations", len(processed_df['overall']))
                        st.metric("Total Hours", round(processed_df['overall']['Calc Hours'].sum(), 2))
                    
            except Exception as e:
                st.error(f"An error occurred: {e}")
