#!/usr/bin/env bash

module load parallel

source ~/ideal_fishstick/scripts/PATHS.inc
source ~/ideal_fishstick/scripts/01_source.inc

echo "      . . .    Please   "
echo "       :.:     Wait!    "
echo "    ____:____     _  _  "
echo "   |         \   | \/ | "
echo "   |          \   \  |  "
echo "   |  O        \__/ |   "
echo " ~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^"

################################################################################################
################################################################################################
################################################################################################

if [ "$RUN" = "MULTI" ]; then

	# create a list of all fasta files in the designated folder
	[ -f ${LOC_LISTS}/${FOLDER}_inds ] || for i in ${LOC_FASTA}/${FOLDER}/*.fasta; do echo $(basename -a -s .fasta $i); done > ${LOC_LISTS}/${FOLDER}_inds

	LIST=${LOC_LISTS}/${FOLDER}_inds

	while read -r LINE
	do
		FOUND="$(find ${LOC_SCRIPTS}/myRuns/ -name "$LINE" -print -quit)"
		if [ "x$FOUND" == "x" ]; then
			for i in ${LOC_FASTA}/${FOLDER}/*.fasta; do 
				echo "creating folder $(basename -a -s .fasta $i)"
				# copy template folder, create a new folder named as the new file with template content
				cp -r ${LOC_SCRIPTS}/template ${LOC_SCRIPTS}/myRuns/$(basename -a -s .fasta $i)
				# if the template folder was copied into the folder by mistake, remove it:
				[ -d ${LOC_SCRIPTS}/myRuns/$(basename -a -s .fasta $i)/template ] && rm -rf ${LOC_SCRIPTS}/myRuns/$(basename -a -s .fasta $i)/template
			done
			# copy fasta files from the designated folder into the main fasta folder:
			cp ${LOC_FASTA}/${FOLDER}/*.fasta ${LOC_FASTA}

		else
			echo "checking file $LINE!"
		fi
	done <$LIST


	echo "running oneRun.sh based on ${LOC_LISTS}/${FOLDER}_inds"
	parallel 'sh /u/$USER/ideal_fishstick/scripts/oneRun.sh {}' :::: ${LOC_LISTS}/${FOLDER}_inds

elif [ "$RUN" = "SCAN" ]; then
	for N_A in {1..4}; do
		for N_B in {1..4}; do

			### SET OUT_NAME
			OUT_NAME=${FILE_A}_x${N_A}_${FILE}_x${N_B}

			### SET STOICHIOMETRY
			STOICHIOMETRY=${FILE_A}_MOUSE:${N_A}/${FILE}_MOUSE:${N_B}

			### SAVE FILE NAME INTO LIST FILE
			echo $OUT_NAME >> ${LOC_LISTS}/MATRIX_${FILE_A}_${FILE}

			### COPY TEMPLATE FOLDER
			[ -f ${LOC_SCRIPTS}/myRuns/$OUT_NAME ] || cp -r ${LOC_SCRIPTS}/template ${LOC_SCRIPTS}/myRuns/$OUT_NAME

			### REMOVE TEMPLATE FOLDER IF COPIED INTO FOLDER BY MISTAKE:
			[ -d ${LOC_SCRIPTS}/myRuns/$OUT_NAME/template ] && rm -rf ${LOC_SCRIPTS}/myRuns/$OUT_NAME/template

			### ENTER SCRIPTS FOLDER
			cd ${LOC_SCRIPTS}/myRuns/$OUT_NAME

			### SET FILE NAME IN USER PARAMETERS
			echo FILE=$OUT_NAME > 00_user_parameters.inc

		    ### SET TARGET STOICHIOMETRY
			echo $STOICHIOMETRY 300 ${OUT_NAME} > target.lst

			# SET TARGET LIST LOCATION (DO NOT CHANGE THIS)
			echo TARGET_LST_FILE=${LOC_SCRIPTS}/myRuns/${OUT_NAME}/target.lst > ${LOC_SCRIPTS}/myRuns/${OUT_NAME}/target.inc
		done
	done


	echo "running parameterScan.sh based on ${LOC_LISTS}/MATRIX_${FILE_A}_${FILE}"
	parallel 'sh /u/$USER/ideal_fishstick/scripts/parameterScan.sh {}' :::: ${LOC_LISTS}/MATRIX_${FILE_A}_${FILE}

else
	echo "To run single runs, simply execute './iRun.sh' in the command line."
fi
