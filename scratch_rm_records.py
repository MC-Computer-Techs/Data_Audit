with open("src/data_processor.py", "r") as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if "# --- 2. Grouping Pairs ---" in line:
        start_idx = i
    if "# --- 3. One Sheet ---" in line:
        end_idx = i
        break

if start_idx != -1 and end_idx != -1:
    del lines[start_idx:end_idx]
    with open("src/data_processor.py", "w") as f:
        f.writelines(lines)
    print("Grouping pairs removed successfully.")
else:
    print("Could not find section markers.")
