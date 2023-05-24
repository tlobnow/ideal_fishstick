#!/usr/bin/env bash

module load parallel

source ~/ideal_fishstick/scripts/02_PATHS.inc
source ~/ideal_fishstick/scripts/01_source.inc

echo "      . . .    Please   "
echo "       :.:     Wait!    "
echo "    ____:____     _  _  "
echo "   |         \   | \/ | "
echo "   |          \   \  |  "
echo "   |  O        \__/ |   "
echo " ~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^"

# This bash script checks if the user wants to run a single or multiple runs by checking the $RUN variable. 
# If $RUN is set to "MULTI", it performs the following tasks:
#   
# (1) It creates a list of all fasta files in a designated folder and saves it in a file called ${LOC_LISTS}/${FOLDER}_inds. 
# (2) It loops through each line in ${LOC_LISTS}/${FOLDER}_inds, and checks if the corresponding run directory exists in ${LOC_SCRIPTS}/myRuns/. 
# (3) If it does not exist, it creates a new directory with the name of the fasta file, 
#		and copies the content of the ${LOC_SCRIPTS}/template directory into it. 
# (4) If the template directory was copied into the new directory by mistake, it is removed.
# (5) It copies all fasta files in the designated folder to the main fasta folder.
# (6) It uses the parallel command to run MULTI.sh script on each fasta file in parallel, passing the name of the file as an argument.
# (7) If $RUN is not set to "MULTI", it simply prints a message reminding the user how to run single runs.

################################################################################################
################################################################################################
################################################################################################

if [ "$RUN" = "SINGLE" ]; then

	sh ~/ideal_fishstick/scripts/SINGLE.sh

elif [ "$RUN" = "MULTI" ]; then

	# create a list of all fasta files in the designated folder
	IND_LIST="${LOC_LISTS}/${FOLDER}_inds"

	#if [ ! -f "$IND_LIST" ]; then
	#	find "${LOC_FASTA}/${FOLDER}" -name "*.fasta" -printf '%f\n' > "$IND_LIST"
	#fi
	for i in ${LOC_FASTA}/${FOLDER}/*.fasta; do echo $(basename -a -s .fasta $i); done > "$IND_LIST"


	# create missing run directories and copy templates
	while read -r LINE; do
		RUN_DIR="${LOC_SCRIPTS}/myRuns/${LINE}"
		if [ ! -d "$RUN_DIR" ]; then
			echo "creating folder $LINE"
			cp -r "${LOC_SCRIPTS}/template" "$RUN_DIR"
			# remove template folder if it was copied into the new folder by mistake
			[ -d "${RUN_DIR}/template" ] && rm -rf "${RUN_DIR}/template"
		else
			echo "checking file $LINE!"
		fi
	done < "$IND_LIST"

	# copy fasta files from the designated folder into the main fasta folder:
	cp "${LOC_FASTA}/${FOLDER}"/*.fasta "${LOC_FASTA}"

	echo "running MULTI.sh based on $IND_LIST"
	# run MULTI.sh on each fasta file in parallel
	parallel "sh /u/\$USER/ideal_fishstick/scripts/MULTI.sh {}" :::: "$IND_LIST"
	#parallel "sh /u/\$USER/ideal_fishstick/scripts/0_oneRun.sh {}" :::: "$IND_LIST"

elif [ "$RUN" = "MATRIX" ]; then

	sh /u/${USER}/ideal_fishstick/scripts/MATRIX.sh

else
	echo "Please adjust the run settings in 01_source.inc"
fi
