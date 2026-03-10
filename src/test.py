import sys
import pandas as pd
from data_processor import process_reservations, export_grouping_pairs, generate_top_sheet

def test():
    file_path = "/Users/kaibanda/Documents/DataAudit/All_BT_Reservations.csv"
    df = pd.read_csv(file_path)
    print("Columns:", df.columns)
    
    ay_start_year = 2024
    
    processed_df, semesters = process_reservations(df, ay_start_year)
    
    print("Semesters matched:", processed_df['Semester'].unique())
    print("Rows matched:", len(processed_df))
    
    # top_sheet_df = generate_top_sheet(processed_df, ay_start_year, semesters)
    # print("Top sheet shape:", top_sheet_df.shape)
    
if __name__ == "__main__":
    test()
