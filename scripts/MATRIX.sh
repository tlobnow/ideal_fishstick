#!/usr/bin/env bash

### SELECT #######################################
EXTENDED_VIEW=FALSE #TRUE
FORCE_PRED=FALSE
FORCE_RLX=FALSE #TRUE

MODE=1
MODE=2

# MODE 1: Start Everything (MSA, Modeling / Rlx / Processing)
# MODE 2: Start Progress Report (no new jobs submitted)
# MODE 3: Start MSA
# MODE 4: Start Modeling   + R Prep (MSA allowed)
# MODE 5: Start Relaxation + R Prep (MSA allowed)

if [ "$EXTENDED_VIEW" = "TRUE" ]; then
    case "$MODE" in
        "1") echo "MODE 1: START ANY JOBS (MSA+Modeling+Rlx+Processing)" ;;
        "2") echo "MODE 2: PROGRESS REPORT" ;;
        "3") echo "MODE 3: MSA ONLY" ;;
        "4") echo "MODE 4: MODELING (+MSA)" ;;
        "5") echo "MODE 5: RELAXATION (+MSA)" ;;
        *) echo "Unknown mode: $MODE" ;;
    esac
fi

### ADDING SOME COLOR TO THE OUTPUT
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

### INITIATE A TICKER TO COUNT FINISHED MODELS
PREDICTION_TICKER=0
##################################################

module purge
module load jdk/8.265 gcc/10 impi/2021.2 fftw-mpi R/4.0.2

FILE=$1
CONTINUE=FALSE # BY DEFAULT FALSE, FIRST CHECK FOR MSA
source ./02_PATHS.inc
source ./01_source.inc

# Check if MSA needs to be run (starts job if necessary)
#source ./msa_run.sh


for i in {1..5}; do
        for j in {1..5}; do echo ${FILE_A}_x${i}_${FILE}_x${j}
	done >>  ${LOC_LISTS}/${FILE_A}_${FILE}_SCAN_INDS
done


CONTINUE=TRUE
for i in {1..5}; do
	for j in {1..5}; do
		NUM=$((i+j))
		# SET THE STOICHIOMETRY, OUT_NAME STRUCTURE
		STOICHIOMETRY=${FILE_A}:${i}/${FILE}:${j}
		OUT_NAME=${FILE_A}_x${i}_${FILE}_x${j}
		#OUT_NAME=${FILE_A}_x${NUM}
		LOC_OUT=${MAIN}/output_files/${OUT_NAME}

		#for m in {1..$i}; do
		#	for j in {1..5}; do echo ${FILE_A}_x${i}_${FILE}_x${j}
		#	done >>  ${LOC_LISTS}/${FILE_A}_${FILE}_SCAN_INDS
		#done

		#for NUM in {1..5}; do
		#	echo ${FILE_A}_x$NUM
		#done > ${LOC_LISTS}/${FILE_A}_${FILE}_SCAN_INDS

		# Prep the run
		if [ "$CONTINUE" = "TRUE" ]; then
			### COPY THE TEMPLATE FOLDER TO CREATE A DIRECTORY FOR THIS RUN
			[ -f ${LOC_SCRIPTS}/runs/${OUT_NAME} ] || cp -r ${LOC_SCRIPTS}/template ${LOC_SCRIPTS}/runs/${OUT_NAME}
			### ENTER SCRIPTS FOLDER
			cd ${LOC_SCRIPTS}/runs/${OUT_NAME}
			### REMOVE DUPLICATE TEMPLATE FOLDER IF FOUND
			if [ -d ${LOC_SCRIPTS}/runs/${OUT_NAME}/template ]; then  rm -Rf ${LOC_SCRIPTS}/runs/${OUT_NAME}/template; fi
			### SET FILE NAME IN USER PARAMETERS
			echo FILE=${OUT_NAME}  > 00_user_parameters.inc
			### SET TARGET STOICHIOMETRY
			echo $STOICHIOMETRY 300 ${OUT_NAME} > target.lst
			### ASSESS THE CURRENT STATUS OF MODEL FILES:
			cd ${LOC_OUT} 2>/dev/null # the 2>/dev/null just means that we ignore the error messages (e.g. cannot access folder, list stuff, ..)
			### 5 NEURAL NETWORK MODELS ARE USED - WE LOOP THROUGH 1:5 TO CHECK MODEL PROGRESS
			for m in {1..5}; do
				# FIND AND REMOVE PICKLE FILES IN OUTPUT FOLDER (HUGE + USELESS FOR US)
				find ${LOC_OUT} 2>/dev/null -name \*.pkl -delete
				# COUNT THE FILES INSIDE THE LOC_OUT FOLDER - WHAT WAS ALREADY CREATED FOR EACH OF THE 5 MODELS??
				# HOW MANY MODELS ARE RELAXED AND CORRECTLY RENAMED?
				OUT_RLX_MODEL_COUNT=`ls ${LOC_OUT} 2>/dev/null | grep ^relaxed_${OUT_NAME}_model_${m}_* | wc -l`
				# HOW MANY MODELS HAVE RUN SUCCESSFULLY AND HAVE BEEN RENAMED ALREADY?
				OUT_MODEL_COUNT=`ls ${LOC_OUT} 2>/dev/null | grep ^${OUT_NAME}_model_${m}_* | wc -l`
				# HOW MANY MODELS HAVE RUN SUCCESSFULLY BUT ARE IN THE INITIAL STATE?
				MODEL_COUNT=`ls ${LOC_OUT} 2>/dev/null | grep ^model_${m}_* | wc -l`
				# IF A DIRECTORY NAMED UNRLXD EXISTS AND IT'S NOT EMPTY -> HOW MANY RENAMED MODEL FILES ARE IN THERE ALREADY?
				[ -d ${LOC_OUT}/UNRLXD 2>/dev/null ] && MOVED_OUT_MODEL_COUNT=`ls ${LOC_OUT}/UNRLXD | grep ^${OUT_NAME}_model_${m}_* | wc -l` || MOVED_OUT_MODEL_COUNT=0
				# IF THE MODEL OR THE RELAXED FILE OF THE MODEL EXIST IN THE OUPUT FOLDER --> SETS PREDICTION_STATUS TO PASS
				if [[ ($OUT_RLX_MODEL_COUNT -eq 1) || ( $MODEL_COUNT -eq 1 ) || ( $OUT_MODEL_COUNT -eq 1 ) ]] ; then
					if [ $EXTENDED_VIEW = TRUE ]; then
						echo "(2) ---> PREDICTION ${m} OF ${OUT_NAME} DONE."
					fi
					PREDICTION_STATUS="PASS"
				# CHECK IF ANY OF THE MODELS HAVE RUN MORE THAN ONCE! GIVES A WARNING IF SO
				elif [[ ($OUT_RLX_MODEL_COUNT -gt 1) || ( $MODEL_COUNT -gt 1 ) || ( $OUT_MODEL_COUNT -gt 1 ) ]] ; then
					echo -e "${YELLOW}(2) MODEL ${m} WAS PREDICTED MORE THAN ONCE. PLEASE CHECK FOLDER BEFORE JOINING SLURMS [PREDICTION_STATUS = PASS]${NC}"
					PREDICTION_STATUS="PASS"
				# IF THE UNRLXD FOLDER WAS ALREADY CREATED, CHECK THE CONTENT AND MOVE FILES BACK INTO MAIN FILE FOLDER
				elif [ $MOVED_OUT_MODEL_COUNT -eq 1 ]; then
					if [ $EXTENDED_VIEW = TRUE ]; then
						echo " ---> PREDICTION ${m} OF ${OUT_NAME} DONE."
					fi
					[ -f ${LOC_OUT}/UNRLXD/${OUT_NAME}_model_${m}_* ] && mv ${LOC_OUT}/UNRLXD/${OUT_NAME}_model_${m}_* ${LOC_OUT}
					PREDICTION_STATUS="PASS"
				# LIKELY NO MODEL CREATED UNTIL NOW -> CHECK FOR TIME LIMIT FAILS OR START NEW MODELING JOB
				else
					cd ${LOC_SCRIPTS}/runs/${OUT_NAME}
					grep --include=slurm\* -rzl . -e "DUE TO TIME LIMIT"
					TIME_LIMIT_EVAL=$?
					grep --include=slurm\* -rzl . -e "model_${m}.*x not in list"
					X_NOT_IN_LIST_EVAL=$?
					grep --include=slurm\* -rzl . -e "model_${m}.*Out of memory"
					OOM_EVAL=$?
					# 0 means FAIL >> at least one job was canceled due to TIME LIMIT or LIST ERROR
					# 1 means PASS >> none of the slurm jobs were canceled due to TIME LIMIT or LIST ERROR - likely need a restart!
					if [ $TIME_LIMIT_EVAL = 0 ]; then
						echo -e "${BLUE}(2) TIME LIMIT FAIL OF ${OUT_NAME}! WILL NOT START A NEW PREDICTION ROUND... ${NC}"
					elif [ $X_NOT_IN_LIST_EVAL = 0 ]; then
						if [ $FORCE_PRED = "TRUE" ]; then
							if [ $MODE -eq 1 -o $MODE -eq 4 ]; then
								JOBID1=$(sbatch --parsable script_model_${m}.sh)
								echo -e "${RED} ---> ${JOBID1} (PRED ${m})${NC}"
							else
								echo -e "${RED}(2) NO SUBMISSION OF MODELING JOBS - CHANGE MODE TO ALLOW NEW SUBMISSIONS.${NC}"
							fi
						else
							echo -e "${BLUE}(2) X NOT IN LIST FAIL OF ${OUT_NAME} MODEL ${m}! WILL NOT START A NEW PREDICTION ROUND... ${NC}"
						fi
					elif [ $OOM_EVAL = 0 ]; then
						echo -e "${BLUE}(2) OUT OF MEMORY FAIL OF  ${OUT_NAME} MODEL ${m}! WILL NOT START A NEW PREDICTION ROUND... ${NC}"
					else
						if [ $MODE -eq 1 -o $MODE -eq 4 ]; then
							JOBID1=$(sbatch --parsable script_model_${m}.sh)
							echo -e "${RED} ---> ${JOBID1} (PRED ${m})${NC}"
						else
							echo -e "${RED}(2) NO SUBMISSION OF MODELING JOBS - CHANGE MODE TO ALLOW NEW SUBMISSIONS.${NC}"
						fi
					fi
					PREDICTION_STATUS="FAIL"
				fi
				# IF ANY PREDICTION_STATUS WAS SET TO PASS, THE TICKER GOES UP BY ONE
				if [ $PREDICTION_STATUS = "PASS" ]; then let PREDICTION_TICKER++ ; fi
			done
			### STATUS OF THE RELAXED FILES
			if [ $PREDICTION_TICKER -ge 5 ]; then
				cd ${LOC_OUT}
				RLX_COUNT=`ls ${LOC_OUT} | grep 'relaxed' | wc -l`
				RLX_COUNT_v2=`ls ${LOC_OUT} | grep 'rlx' | wc -l`
				# IF THERE ARE AT LEAST FIVE RELAXED SAMPLES, GIVE RELAXATION PASS
				if [ $RLX_COUNT -ge 5 -o $RLX_COUNT_v2 -ge 5 ]; then
					# REMOVE PICKLE FILES IF FOUND
					find ${LOC_OUT} -name \*.pkl -delete
					RELAXATION_STATUS="PASS"
					if [ $EXTENDED_VIEW = TRUE ]; then
						echo "(3) RELAXATION OF ${OUT_NAME} FINISHED SUCCESSFULLY."
					fi
				elif [ $RLX_COUNT -ge 1 -o $RLX_COUNT_v2 -ge 1 ]; then
						# PARTIAL RELAXATION, BUT NOT FORCED TO RESTART
						if [ $FORCE_RLX = FALSE ]; then
								echo -e "${YELLOW}(3) RELAXATION OF ${OUT_NAME} WAS ATTEMPTED, BUT HAS NOT FINISHED. SET FORCE_RLX = TRUE IF NECESSARY.${NC}"
								RELAXATION_STATUS="PASS"
						# FORCES TO REMOVE PRE-EXISTING RELAXED FILES AND START NEW RELAXATION
						else
							[ -f  ${LOC_OUT}/relaxed_model_1* -o -f ${LOC_OUT}/relaxed_${OUT_NAME}_model_1* ] && rm relaxed*
							[ -f  ${LOC_OUT}/${OUT_NAME}_rlx_model_1* ] && rm *rlx*
							# START NEW RELAXATION
							cd ${LOC_SCRIPTS}/runs/${OUT_NAME}
							if [ $MODE -eq 1 -o $MODE -eq 5 ]; then
								#JOBID1=$(sbatch --parsable script_relaxation.sh)
								#echo -e "${RED} ---> ${JOBID1} (RLX ALL) ${NC}"
								echo "NO RELAXATION STEP FOR NOW."
							else
								#echo -e "${RED}(3) NO SUBMISSION OF RELAXATION JOBS - CHANGE MODE TO ALLOW NEW SUBMISSIONS.${NC}"
								echo "NO RELAXATION STEP FOR NOW."
							fi
							RELAXATION_STATUS="FAIL"
						fi
				# OTHERWISE REMOVE PRE-EXISTING RELAXED FILES AND START NEW RELAXATION
				else
					# START NEW RELAXATION
					cd ${LOC_SCRIPTS}/runs/${OUT_NAME}
					if [ $MODE -eq 1 -o $MODE -eq 5 ]; then
							#JOBID1=$(sbatch --parsable script_relaxation.sh)
							#echo -e "${RED} ---> ${JOBID1} (RLX ALL) ${NC}"
							echo "NO RELAXATION STEP FOR NOW."
					else
							#echo -e "${RED}(3) NO SUBMISSION OF RELAXATION JOBS - CHANGE MODE TO ALLOW NEW SUBMISSIONS.${NC}"
							echo "NO RELAXATION STEP FOR NOW."
					fi
					RELAXATION_STATUS="FAIL"
				fi
			# if the prediction ticker is less than five, check if it's due to slurm job time limitation, then proceed with relaxation!
			elif [ $PREDICTION_TICKER -lt 5 ]; then
				cd ${LOC_SCRIPTS}/runs/${OUT_NAME}
				grep --include=slurm\* -rzl . -e "DUE TO TIME LIMIT"
				TIME_LIMIT_EVAL=$?
				# 0 means FAIL >> at least one job was canceled due to TIME LIMIT
				# 1 means PASS >> none of the slurm jobs were canceled due to TIME LIMIT - likely need a restart!
				if [ $TIME_LIMIT_EVAL = 0 ]; then
					echo -e "${BLUE} TIME LIMIT FAIL OF ${OUT_NAME}! WILL CONTINUE WITH RELAXATION. ${NC}"
					cd ${LOC_OUT}
					RLX_COUNT=`ls ${LOC_OUT} | grep 'relaxed' | wc -l`
					RLX_COUNT_v2=`ls ${LOC_OUT} | grep 'rlx' | wc -l`
					# IF THERE ARE AT LEAST FIVE RELAXED SAMPLES, GIVE RELAXATION PASS
					if [ $RLX_COUNT -eq $PREDICTION_TICKER -o $RLX_COUNT_v2 -eq $PREDICTION_TICKER ]; then
						# REMOVE PICKLE FILES IF FOUND
						find ${LOC_OUT} -name \*.pkl -delete
						RELAXATION_STATUS="PASS"
						if [ $EXTENDED_VIEW = TRUE ]; then
							echo "(3) RELAXATION OF ${OUT_NAME} FINISHED SUCCESSFULLY."
						fi
						# OTHERWISE REMOVE PRE-EXISTING RELAXED FILES AND START NEW RELAXATION
					else
						[ -f  ${LOC_OUT}/relaxed_model_1* -o -f ${LOC_OUT}/relaxed_${OUT_NAME}_model_1* ] && rm relaxed*
						[ -f  ${LOC_OUT}/${OUT_NAME}_rlx_model_1* ] && rm *rlx*
						# START NEW RELAXATION
						cd ${LOC_SCRIPTS}/runs/${OUT_NAME}
						if [ $MODE -eq 1 -o $MODE -eq 5 ]; then
							#jobid1=$(sbatch --parsable script_relaxation.sh)
							#echo -e "${RED} ---> ${JOBID1} (RLX ALL) ${NC}"
							echo "NO RELAXATION STEP FOR NOW."
						else
							#echo -e "${RED}(3) NO SUBMISSION OF RELAXATION JOBS - CHANGE MODE TO ALLOW NEW SUBMISSIONS.${NC}"
							echo "NO RELAXATION STEP FOR NOW."
						fi
						RELAXATION_STATUS="FAIL"
					fi
				fi
			else
				echo -e "${RED} ---> WAITING FOR ${OUT_NAME} MODELING TO FINISH. ${NC}"
			fi
			### STATUS OF R PREPARATION
			#if [ "$RELAXATION_STATUS" = "PASS" ]; then
			if [ $PREDICTION_TICKER -ge 5 ]; then
				# CREATE NECESSARY FOLDERS / ENSURE THEY HAVE BEEN CREATED ALREADY
				mkdir -p ${LOC_OUT}/JSON
				mkdir -p ${LOC_OUT}/UNRLXD
				mkdir -p ${LOC_OUT}/SLURMS
				# ENTER THE SCRIPTS FOLDER
				cd ${LOC_SCRIPTS}/runs/${OUT_NAME}
				# CONCATENATE SLURM FILES AND STORE THEM IN OUTPUT FOLDER
				cat slurm* > ${LOC_OUT}/slurm.out
				cp slurm* ${LOC_OUT}/SLURMS/
				# ENTER OUTPUT FOLDER
				cd ${LOC_OUT}
				[ -f relax_metrics.json ] && rm relax_metrics.json
				# RENAME FILES
				for m in {1..5}; do
					#for j in relaxed_model_${m}_*; do mv -- "$j" "${OUT_NAME}_rlx_model_${m}.pdb" ; done
					#[ -f relaxed_model_${m}_* ] && mv relaxed_model_${m}_* ${OUT_NAME}_rlx_model_${m}.pdb
					[ -f ${OUT_NAME}_model_${m}.pdb ] &&  mv ${OUT_NAME}_model_${m}.pdb     ${LOC_OUT}/UNRLXD/${OUT_NAME}_model_${m}.pdb
					[ -f model_${m}* ] && mv  model_${m}* ${LOC_OUT}/UNRLXD/${OUT_NAME}_model_${m}.pdb
					[ -f ranking_model_${m}* ] && mv  ranking_model_${m}* ${LOC_OUT}/JSON/${OUT_NAME}_ranking_model_${m}.json
					[ -f ${OUT_NAME}_ranking_model_${m}.json ] &&  mv ${OUT_NAME}_ranking_model_${m}.json ${LOC_OUT}/JSON/${OUT_NAME}_ranking_model_${m}.json
				done
				cd ${LOC_OUT}
                		echo "extracting JSON and converting to CSV file"
		                Rscript --vanilla ${LOC_SCRIPTS}/Rscripts/extract2csv.R ${LOC_OUT} ${OUT_NAME} ${RUN}

				# REMOVE CHECKPOINT FOLDER IF FOUND
				[ -f checkpoint ] && rm -r checkpoint
				# COPY THE FOLDER INTO TRANSFERGIT REPO
				#cp -r ${LOC_OUT}/ ~/transferGit/
				if [ $EXTENDED_VIEW = TRUE ]; then
					echo "(4) R PREPARATION OF ${OUT_NAME} FINISHED SUCCESSFULLY."
					echo "(5) PIPELINE OF ${OUT_NAME} FINISHED SUCCESSFULLY."
					#echo "(6) COPIED FOLDER TO ~/transferGit/"
					ls ${LOC_OUT}
				fi
			else
				echo -e "${RED} ---> WAITING FOR ${OUT_NAME} RELAXATION TO FINISH. ${NC}"
			fi
		else
			echo -e "${RED} ---> WAITING FOR ${OUT_NAME} MSA TO FINISH. ${NC}"
		fi

		if [ $EXTENDED_VIEW = TRUE ]; then
			echo "---------------------------------------------------"
		fi

	done
done

