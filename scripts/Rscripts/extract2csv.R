#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
LOC_OUT = args[1]	# $LOC_OUT
OUT_NAME = args[2]	# $OUT_NAME
RUN = args[3]	# $RUN
unlink(".RData")

# Load required libraries
pacman::p_load(tidyr,stringr,jsonlite,janitor,fs,purrr,utils,data.table,dplyr)
print("Libraries loaded.")

# Function to extract information from JSON files
jsonExtract <- function(jsonFile, outFile, fileName) {
	# Read the JSON file
	jsonData <- fromJSON(jsonFile)

	# Extract relevant information using pivot_longer function
	model <- strsplit(jsonData$order[[1]], "_", fixed = TRUE)[[1]][2]
	tolData <- jsonData$tol_values %>% as.data.frame() %>% pivot_longer(everything(), names_to = "RECYCLE", values_to = "TOL") 
	pLDDTData <- jsonData$plddts %>% as.data.frame() %>% pivot_longer(everything(), names_to = "RECYCLE", values_to = "pLDDT") 
	pTMData <- jsonData$ptms %>% as.data.frame() %>% pivot_longer(everything(), names_to = "RECYCLE", values_to = "pTM") 
	piTMData <- jsonData$pitms %>% as.data.frame() %>% pivot_longer(everything(), names_to = "RECYCLE", values_to = "piTM") 
	iScoreData <- jsonData$`interface score` %>% as.data.frame() %>% pivot_longer(everything(), names_to = "RECYCLE", values_to = "iScore") 
	iResData <- jsonData$`interfacial residue number` %>% as.data.frame() %>% pivot_longer(everything(), names_to = "RECYCLE", values_to = "iRes") 
	iCntData <- jsonData$`interficial contact number` %>% as.data.frame() %>% pivot_longer(everything(), names_to = "RECYCLE", values_to = "iCnt") 
	fileModel <- paste(fileName, "MODEL", model, sep = "_")
	numClusters <- jsonData$clusters[[iScoreData$RECYCLE[1]]]$num_clusters
	numMonomers <- length(jsonData$chains)

	# Combine the extracted data into a data frame
	extractedData <- cbind(fileName, model, tolData, pLDDTData, pTMData, piTMData, iScoreData, iResData, iCntData, fileModel, numClusters, numMonomers)

	# Remove duplicated column names, if any
	extractedData <- extractedData[, !duplicated(colnames(extractedData))]

	# Write the extracted data to the output file
	write.table(extractedData, file = paste0(outFile, ".csv"), sep = ",", append = TRUE, quote = FALSE, row.names = FALSE, col.names = FALSE)

	# Filter out recycled data and write to a separate file
	extractedDataNoRecycle <- extractedData %>% filter(!str_detect(RECYCLE, "_recycled_"))
	write.table(extractedDataNoRecycle, file = paste0(outFile, "_noRecycles.csv"), sep = ",", append = TRUE, quote = FALSE, row.names = FALSE, col.names = FALSE)
}

# retrieve the files of interest, for now only one file, but loop can be used for folder structures containing subfolders
files <- OUT_NAME
# for multiple files in main folder
# files <- list.files(MAIN)
print(paste("files = ",files))

# Iterate over each file
for (fileName in files) {
	# Get the complete path of the output folder
	folder <- LOC_OUT
	print(paste("folder = ",folder))

	dir_create(folder,"CSV")
	print(paste("created CSV folder"))

	csvFile <- file.path(folder, "CSV", paste0(fileName, ".csv"))
	csvFileNoRecycles <- file.path(folder, "CSV", paste0(fileName, "_noRecycles.csv"))

	# Remove existing CSV files, if any
	if (file.exists(csvFile)) {
		file.remove(csvFile)
	}
	if (file.exists(csvFileNoRecycles)) {
		file.remove(csvFileNoRecycles)
	}

	# Get the JSON folder and the latest JSON file
	jsonFolder <- file.path(folder, "JSON")
	jsonFiles <- dir_ls(jsonFolder, regexp = "\\.json$", recurse = TRUE)

	# Skip the iteration if no JSON files found
	if (is_empty(jsonFiles)) {
		next
	}

	# Modify JSON files to replace "Infinity" with "9999"
	for (jsonFile in jsonFiles) {
		jsonContent <- readLines(jsonFile)
		jsonContent <- str_replace_all(jsonContent, "Infinity", "9999")
		writeLines(jsonContent, jsonFile)
	}

	# Process each JSON file
	for (jsonFile in jsonFiles) {
		outFile <- file.path(folder, "CSV", fileName)
		jsonExtract(jsonFile = jsonFile, outFile = outFile, fileName = fileName)
	}

	# Get the list of CSV files
	csvFiles <- c(csvFile, csvFileNoRecycles)

	# Process each CSV file
	for (csvFile in csvFiles) {
		# Read the CSV file and perform required transformations
		jsonExtractData <- data.table::fread(csvFile, header = FALSE) %>%
			dplyr::mutate(ORIGIN = fileName) %>%
			dplyr::rename(
						  FILE = V1,
						  MODEL = V2,
						  RECYCLE = V3,
						  TOL = V4,
						  pLDDT = V5,
						  pTM = V6,
						  piTM = V7,
						  iScore = V8,
						  iRes = V9,
						  iCnt = V10,
						  FILE_MODEL = V11,
						  NUM_CLUSTERS = V12,
						  N_MONOMERS = V13
			)

			# Add ranking based on descending iScore within each file
			jsonExtractData <- jsonExtractData %>%
				dplyr::mutate(
							  FILE_RECYCLE = paste0(FILE_MODEL, "_RECYCLE_", RECYCLE),
							  RANK = frank(desc(iScore), ties.method = "min")
							  ) %>%
			dplyr::distinct(FILE_RECYCLE, .keep_all = TRUE) %>%
			dplyr::group_by(FILE) %>%
			dplyr::mutate(RANK = frank(desc(iScore), ties.method = "min"))

		# Write the updated data back to the CSV file
		data.table::fwrite(jsonExtractData, csvFile, row.names = FALSE)
		print(paste(csvFile, "was created."))

		# NOT OPTIMIZED YET, SO DON'T USE
		#IF MAIN FOLDER WITH SUBFOLDERS IS ITERATED OVER, YOU CAN TECHNICALLY APPEND CSVs FROM ALL FOLDERS INTO ONE SUMMARY.csv
		#	# Append the data to the summary.csv file
		#	data.table::fwrite(jsonExtractData, file.path(LOC_OUT, "summary.csv"), row.names = FALSE, append = TRUE)
		#
		#	# Read the final summary.csv file and remove duplicates
		#	summary <- fread(file.path(LOC_OUT, "summary.csv")) %>% unique()
		#
		#	# Write the updated summary.csv file
		#	data.table::fwrite(summary, file.path(LOC_OUT, "summary.csv"), row.names = FALSE, append = TRUE)
	}
}
