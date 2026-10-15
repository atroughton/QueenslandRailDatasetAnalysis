setwd("/Users/aarontroughton/Desktop/TLineAnalysis")   # working directory (outputs are saved here)
data_dir <- "Dataset Resources"                        # subfolder with the original data (Excel csv, stop_times)

# ---- Load data (once) ----
map    <- read.csv(file.path(data_dir, "854d17aa-2d85-49a4-9e3e-ff7c06b596a7.csv"),
                   fileEncoding = "UTF-8-BOM", colClasses = "character")
routes <- read.csv("routesRail.csv", colClasses = "character")
trips  <- read.csv("tripsRail.csv",  colClasses = "character")
stops  <- read.csv("stopsRail.csv",  colClasses = "character")

lines <- c("T1", "T2", "T3", "T4", "T5", "T6")
cols  <- c(T1 = "#02a84a", T2 = "#55c7ee", T3 = "#bc65a2", T4 = "#5083c3",
           T5 = "#f8f311", T6 = "#e9454d", EX = "#999999")

# Shows a graph on screen AND saves it as a png in the working directory
draw_and_save <- function(plot_fn, file, width = 8, height = 6) {
  plot_fn()
  png(file, width = width, height = height, units = "in", res = 150)
  plot_fn()
  invisible(dev.off())
}

# Graph 1: route codes per T-line
counts <- table(factor(map$GTFS.Route_short_name, levels = c(lines, "EX")))

graph1 <- function() {
  b <- barplot(counts, col = cols, main = "Route codes per T-line",
               xlab = "T-line", ylab = "Number of route codes", ylim = c(0, 65))
  text(b, counts, labels = counts, pos = 3)
}
draw_and_save(graph1, "G1_routesinT.png")

# Graph 2: route codes by destination
agg <- as.data.frame(table(line = map$GTFS.Route_short_name,
                           dest = map$GTFS.Route_long_name))
agg <- agg[agg$Freq > 0, ]
agg$line <- factor(agg$line, levels = c(lines, "EX"))
agg$dest <- as.character(agg$dest)
agg <- agg[order(agg$line, -agg$Freq), ]

# Each line's share of all route codes, for the legend
totals <- tapply(agg$Freq, agg$line, sum)
pct <- round(totals / sum(totals) * 100, 1)
legend_labels <- paste0(names(cols), " (", pct[names(cols)], "%)")

graph2 <- function() {
  old <- par(mar = c(9, 4, 3, 1))     # extra space at the bottom for the names
  on.exit(par(old))                   # put margins back afterwards
  b <- barplot(agg$Freq, names.arg = agg$dest, las = 2, cex.names = 0.7,
               col = cols[as.character(agg$line)], ylim = c(0, 32),
               main = "Route codes by destination",
               ylab = "Number of route codes")
  text(b, agg$Freq, labels = agg$Freq, pos = 3)
  legend("topright", legend = legend_labels, fill = cols,
         title = "T-line (% of route codes)")
}
draw_and_save(graph2, "g2_Destinations.png", width = 9, height = 6)

# Join: trips -> routes (old code) -> Excel csv (T-line)
x <- merge(trips[, c("trip_id", "route_id")],
           routes[, c("route_id", "route_short_name")], by = "route_id")
x <- merge(x, map, by.x = "route_short_name", by.y = "Current.GTFS.Route_short_name")
names(x)[names(x) == "GTFS.Route_short_name"] <- "line"
names(x)[names(x) == "GTFS.Route_long_name"]  <- "dest"

# Graph 3: scheduled trips per T-line
trip_counts <- table(factor(x$line, levels = lines))

graph3 <- function() {
  b <- barplot(trip_counts, col = cols[lines], ylim = c(0, 3000),
               main = "Scheduled trips per T-line", ylab = "Number of trips")
  text(b, trip_counts, labels = trip_counts, pos = 3)
}
draw_and_save(graph3, "g3_trips_PerTLINE.png")

# Graph 4: share of route codes vs share of trips 
code_pct <- as.numeric(table(factor(map$GTFS.Route_short_name, levels = lines)))
code_pct <- code_pct / sum(code_pct) * 100
trip_pct <- as.numeric(trip_counts) / sum(trip_counts) * 100

graph4 <- function() {
  barplot(rbind(code_pct, trip_pct), beside = TRUE, names.arg = lines,
          col = c("grey70", "#5083c3"), ylim = c(0, 50),
          main = "Share of route codes vs share of trips",
          ylab = "Percent", legend.text = c("Route codes", "Trips"),
          args.legend = list(x = "topright"))
}
draw_and_save(graph4, "g4_codeAmount_VS_Trips.png")

# Table: stations per T-line
# Read only the two columns needed from the big file
hdr <- names(read.csv(file.path(data_dir, "stop_times.txt"), nrows = 1))
cc  <- ifelse(hdr %in% c("trip_id", "stop_id"), "character", "NULL")
stop_times <- read.csv(file.path(data_dir, "stop_times.txt"), colClasses = cc)

# Keep rail trips, then swap each platform for its parent station
stop_times <- stop_times[stop_times$trip_id %in% trips$trip_id, ]
parent <- setNames(stops$parent_station, stops$stop_id)
stop_times$station <- parent[stop_times$stop_id]
blank <- is.na(stop_times$station) | stop_times$station == ""
stop_times$station[blank] <- stop_times$stop_id[blank]

y <- merge(stop_times, data.frame(trip_id = x$trip_id, line = x$line), by = "trip_id")

stations <- tapply(y$station, y$line, function(s) length(unique(s)))

result <- data.frame(line = names(stations),
                     stations = as.integer(stations),
                     pct_of_network = round(as.integer(stations) /
                                              length(unique(y$station)) * 100, 1),
                     trips = as.integer(trip_counts[names(stations)]))

print(result)
write.csv(result, "stationsPerLine.csv", row.names = FALSE)

# Table as an image (line column coloured)
tbl <- data.frame(line   = result$line,
                  count  = result$stations,
                  pct    = paste0(result$pct_of_network, "%"),
                  trips  = formatC(result$trips, big.mark = ",", format = "d"))
headers <- c("T-line", "Stations served", "% of 154 stations", "Scheduled trips")

table_graph <- function() {
  old <- par(mar = c(1, 1, 3, 1))
  on.exit(par(old))
  n <- nrow(tbl)
  plot(NA, xlim = c(0, 4), ylim = c(0, n + 1), axes = FALSE,
       xlab = "", ylab = "", xaxs = "i", yaxs = "i")
  title("Stations and scheduled trips per T-line")
  
  for (j in 1:4) {                                   # header row
    rect(j - 1, n, j, n + 1, col = "grey25", border = "grey80")
    text(j - 0.5, n + 0.5, headers[j], col = "white", font = 2)
  }
  for (i in 1:n) {                                   # one row per line
    for (j in 1:4) {
      is_line <- (j == 1)
      fill    <- if (is_line) cols[[tbl$line[i]]] else "white"
      txt_col <- if (is_line && !(tbl$line[i] %in% c("T2", "T5"))) "white" else "black"
      rect(j - 1, n - i, j, n - i + 1, col = fill, border = "grey80")
      text(j - 0.5, n - i + 0.5, as.character(tbl[i, j]),
           col = txt_col, font = if (is_line) 2 else 1)
    }
  }
}
draw_and_save(table_graph, "stationsPerLine.png", width = 9, height = 4)