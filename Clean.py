"""
Cleaning the data of routes.txt, trips.txt and stops.txt files from the broader SEQ GTFS Dataset.
Removes other forms of public transport and keeps only rail (route type 2).

Reads the original files from the "Dataset Resources" folder.
Saves as CSV rather than txt as the files are already formatted like a csv:
"""

from pathlib import Path

import pandas as pd

folder = Path(__file__).resolve().parent      
data_dir = folder / "Dataset Resources"       # Connect to dataset files


def read(name, **kwargs):
    # **kwargs passes any extra options (e.g. usecols=...) straight to pd.read_csv
    return pd.read_csv(data_dir / name, dtype=str, keep_default_na=False, **kwargs)


# 1. Routes: keep rail only (route_type 2)
routes = read("routes.txt")
rail_routes = routes[routes["route_type"] == "2"]

# 2. Trips: keep trips on those routes
trips = read("trips.txt")
rail_trips = trips[trips["route_id"].isin(rail_routes["route_id"])]

# Save routes and trips now
rail_routes.to_csv(folder / "routesRail.csv", index=False)
rail_trips.to_csv(folder / "tripsRail.csv", index=False)

print(f"routes: {len(routes)} -> {len(rail_routes)}")
print(f"trips:  {len(trips)} -> {len(rail_trips)}")

# 3. Stops: keep rail stops
stops = read("stops.txt")

if not (data_dir / "stop_times.txt").exists():
    print("\nstop_times.txt not found in 'Dataset Resources', so stops were not filtered.")
    print("Copy stop_times.txt into that folder and run this script again.")
else:
    stop_times = read("stop_times.txt", usecols=["trip_id", "stop_id"])
    rail_stop_ids = set(
        stop_times.loc[stop_times["trip_id"].isin(rail_trips["trip_id"]), "stop_id"]
    )
    rail_platforms = stops[stops["stop_id"].isin(rail_stop_ids)]

    # Also keep the parent stations of those platforms
    parents = set(rail_platforms["parent_station"]) - {""}
    rail_stops = stops[stops["stop_id"].isin(rail_stop_ids) | stops["stop_id"].isin(parents)]

    rail_stops.to_csv(folder / "stopsRail.csv", index=False)
    print(f"stops:  {len(stops)} -> {len(rail_stops)}")
