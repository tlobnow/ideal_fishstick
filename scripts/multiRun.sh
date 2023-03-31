#!/usr/bin/env bash

module load parallel

source ./PATHS.inc
source ./01_source.inc

LIST=${LOC_LISTS}/${FOLDER}_inds

################################################################################################
################################################################################################
################################################################################################

### SET UP A LIST OF INDIVIDUALS IN LISTS FOLDER
# = if you cannot find the list for the folder specified above, then create a list with the basenames in that folder.
[ -f $LIST ] || for i in ${LOC_FASTA}/${FOLDER}/*.fasta; do echo $(basename -a -s .fasta $i); done > ${LOC_LISTS}/${FOLDER}_inds

### COPY THE TEMPLATE SCRIPT TO CREATE FOLDER PER INDIVIDUAL
# = read the list file - if you cannot find a folder that carries the same name as the line you are currently reading (list) -> create a folder with 
#   that name by copying the template folder. Once all folders are created, also copy the fasta files into the main fasta_files folder
#   (could also move, but I retain them in the original folder as a backup for reference)

while read -r LINE
do
	FOUND="$(find ${LOC_SCRIPTS}/myRuns/ -name "$LINE" -print -quit)"
	if [ "x$FOUND" != "x" ]
	then
		echo "Working on $LINE"
	else
		for i in ${LOC_FASTA}/${FOLDER}/*.fasta; do 
			# copy template folder, create a new folder named as the new file with template content
			cp -r ${LOC_SCRIPTS}/template ${LOC_SCRIPTS}/myRuns/$(basename -a -s .fasta $i)
			# if the template folder was copied into the folder by mistake, remove it:
			[ -f ${LOC_SCRIPTS}/myRuns/$(basename -a -s .fasta $i)/template ] && rm -r ${LOC_SCRIPTS}/myRuns/$(basename -a -s .fasta $i)/template ; done
		# copy fasta files from the designated folder into the main fasta folder:
		cp ${LOC_FASTA}/${FOLDER}/*.fasta ${LOC_FASTA}
	fi
done <$LIST


################################################################################################
################################################################################################
################################################################################################

echo "running oneRun.sh based on ${LOC_LISTS}/${FOLDER}_inds"
parallel 'sh oneRun.sh {}' :::: ${LOC_LISTS}/${FOLDER}_inds
