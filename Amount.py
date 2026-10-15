import csv
import json
from pathlib import Path

folder = Path(__file__).resolve().parent   
data_dir = folder / "Dataset Resources"    # original data files are here

codes_inTline = {} # Sorts old routes under new T line Categories and saves in dictionary

with open(data_dir / "854d17aa-2d85-49a4-9e3e-ff7c06b596a7.csv", encoding="utf-8-sig") as f: # Dataset CSV File
    for row in csv.DictReader(f):
        line = row["GTFS Route_short_name"]
        code = row["Current GTFS Route_short_name"]
        codes_inTline.setdefault(line, []).append(code)

for line, codes in codes_inTline.items(): # Print amount of routes in each T Line
    print(line, len(codes))

with open(folder / "codes_inTline.json", "w") as f: # Saves dictionaries as a new JSON file
    json.dump(codes_inTline, f, indent=2)
