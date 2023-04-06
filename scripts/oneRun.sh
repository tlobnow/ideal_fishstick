#!/usr/bin/env bash

### SELECT ####################################### 
EXTENDED_VIEW=TRUE
FORCE_RLX=FALSE

MODE=1
# MODE 1: Start Everything (Modeling / Rlx / R preparation)
# MODE 2: Start Modeling   + R Prep 
# MODE 3: Start Relaxation + R Prep
# MODE 4: Start R Prep (no jobs submitted, just progress check)


if [ $EXTENDED_VIEW = TRUE ]; then
	if   [ "$MODE" = "1" ]; then 
		echo "MODE 1: Start any necessary job (Modeling / Rlx / R preparation)"
	elif [ "$MODE" = "2" ]; then 
		echo "MODE 2: Start Modeling Jobs Only ( + R Prep). "
	elif [ "$MODE" = "3" ]; then 
		echo "MODE 3: Start Relaxation Jobs Only (+ R Prep). "
	else [ "$MODE" = "4" ];      
		echo "MODE 4: Only R Prep & checking what needs to be done. "
	fi
fi


### ADDING SOME COLOR TO THE OUTPUT
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

### START A TICKER TO COUNT FINISHED MODELS
PREDICTION_TICKER=0
##################################################

CONTINUE=TRUE
FILE=$1
source ./PATHS.inc
source ./01_source.inc


if [ $CONTINUE = "TRUE" ]; then

        ### COPY THE TEMPLATE FOLDER TO CREATE A DIRECTORY FOR THIS RUN
        [ -f ${LOC_SCRIPTS}/myRuns/${FILE} ] || cp -r ${LOC_SCRIPTS}/template ${LOC_SCRIPTS}/myRuns/${FILE}

		### ENTER SCRIPTS FOLDER
        cd ${LOC_SCRIPTS}/myRuns/${FILE}

        ### SET FILE NAME IN USER PARAMETERS
        echo FILE=${FILE}  > 00_user_parameters.inc

        ### SET TARGET STOICHIOMETRY
        echo $STOICHIOMETRY 300 ${OUT_NAME} > target.lst

		### ASSESS THE CURRENT STATUS OF MODEL FILES:
		[ -f ${LOC_OUT} ] && cd ${LOC_OUT}

		### 5 NEURAL NETWORK MODELS ARE USED - WE LOOP THROUGH 1:5 TO CHECK MODEL PROGRESS
		for i in {1..5}; do

			# find and remove pickle files (HUGE and useless to us)
			[ -f ${LOC_OUT} ] && find ${LOC_OUT} -name \*.pkl -delete
			# COUNT THE FILES INSIDE THE LOC_OUT FOLDER - WHAT WAS ALREADY CREATED FOR EACH OF THE 5 MODELS??
			# HOW MANY MODELS ARE RELAXED AND CORRECTLY RENAMED?
			[ -f ${LOC_OUT} ] && OUT_RLX_MODEL_COUNT=`ls ${LOC_OUT} | grep ^relaxed_${OUT_NAME}_model_${i}_* | wc -l`
			# HOW MANY MODELS HAVE RUN SUCCESSFULLY AND HAVE BEEN RENAMED ALREADY?
			[ -f ${LOC_OUT} ] && OUT_MODEL_COUNT=`ls ${LOC_OUT} | grep ^${OUT_NAME}_model_${i}_* | wc -l`
			# HOW MANY MODELS HAVE RUN SUCCESSFULLY BUT ARE IN THE INITIAL STATE?
			[ -f ${LOC_OUT} ] && MODEL_COUNT=`ls ${LOC_OUT} | grep ^model_${i}_* | wc -l`
			# IF A DIRECTORY NAMED UNRLXD EXISTS AND IT'S NOT EMPTY -> HOW MANY RENAMED MODEL FILES ARE IN THERE ALREADY?
			[ -d ${LOC_OUT}/UNRLXD ] && MOVED_OUT_MODEL_COUNT=`ls ${LOC_OUT}/UNRLXD | grep ^${OUT_NAME}_model_${i}_* | wc -l` || MOVED_OUT_MODEL_COUNT=0

			# IF THE MODEL OR THE RELAXED FILE OF THE MODEL EXIST IN THE OUPUT FOLDER --> SETS PREDICTION_STATUS TO PASS
			if [ $OUT_RLX_MODEL_COUNT -eq 1 -o $MODEL_COUNT -eq 1 -o $OUT_MODEL_COUNT -eq 1 ]; then
				if [ $EXTENDED_VIEW = TRUE ]; then
					echo " ---> PREDICTION ${i} OF ${OUT_NAME} DONE."
				fi
				PREDICTION_STATUS="PASS"

			# CHECK IF ANY OF THE MODELS HAVE RUN MORE THAN ONCE! GIVES A WARNING IF SO	
			elif [  $OUT_RLX_MODEL_COUNT -gt 1 -o $MODEL_COUNT -gt 1 -o $OUT_MODEL_COUNT -gt 1 ]; then
				echo -e "${YELLOW}MODEL ${i} WAS PREDICTED MORE THAN ONCE. PLEASE CHECK FOLDER BEFORE JOINING SLURMS [PREDICTION_STATUS = PASS]${NC}"
				PREDICTION_STATUS="PASS"

			# IF THE UNRLXD FOLDER WAS ALREADY CREATED, CHECK THE CONTENT AND MOVE FILES BACK INTO MAIN FILE FOLDER
			elif [ $MOVED_OUT_MODEL_COUNT -eq 1 ]; then
				if [ $EXTENDED_VIEW = TRUE ]; then
					echo " ---> PREDICTION ${i} OF ${OUT_NAME} DONE."
				fi
				mv [ -f ${LOC_OUT}/UNRLXD/${OUT_NAME}_model_${i}_* ] && ${LOC_OUT}/UNRLXD/${OUT_NAME}_model_${i}_* ${LOC_OUT} 
				PREDICTION_STATUS="PASS"

			# LIKELY NO MODEL CREATED UNTIL NOW -> CHECK FOR TIME LIMIT FAILS OR START NEW MODELING JOB
			else
				cd ${LOC_SCRIPTS}/myRuns/${FILE}
				grep --include=slurm\* -rzl . -e "DUE TO TIME LIMIT" 
				TIME_LIMIT_EVAL=$?	

				# 0 means FAIL >> at least one job was canceled due to TIME LIMIT
				# 1 means PASS >> none of the slurm jobs were canceled due to TIME LIMIT - likely need a restart!
				if [ $TIME_LIMIT_EVAL = 0 ]; then
					echo -e "${BLUE} TIME LIMIT FAIL OF ${OUT_NAME}! WILL NOT START A NEW PREDICTION ROUND... ${NC}"
				else
					if [ $MODE -le 2 ]; then
						JOBID1=$(sbatch --parsable script_model_${i}.sh)
						echo -e "${RED} ---> ${JOBID1} (PRED ${i})${NC}"
					else
						echo -e "${RED}SUBMISSION OF MODELING JOBS SET TO FALSE ${NC}"
						echo -e "${RED} ---> ${JOBID1} (PRED ${i})${NC}"
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
					cd ${LOC_SCRIPTS}/myRuns/${FILE}
					if [ $MODE -eq 1 -o $MODE -eq 3 ]; then
						#JOBID1=$(sbatch --parsable script_relaxation.sh)
						#echo -e "${RED} ---> ${JOBID1} (RLX ALL) ${NC}"
						echo "NO RELAXATION STEP FOR NOW."
					else
						#echo -e "${RED}SUBMISSION OF RELAXATION JOBS SET TO FALSE ${NC}"
						#echo -e "${RED} ---> ${JOBID1} (RLX ALL) ${NC}"
						echo "NO RELAXATION STEP FOR NOW."
					fi
					RELAXATION_STATUS="FAIL"
				fi


			# OTHERWISE REMOVE PRE-EXISTING RELAXED FILES AND START NEW RELAXATION
			else 
				#[ -f  ${LOC_OUT}/relaxed_model_1* -o -f ${LOC_OUT}/relaxed_${OUT_NAME}_model_1* ] && rm relaxed*
				#[ -f  ${LOC_OUT}/${OUT_NAME}_rlx_model_1* ] && rm *rlx*
					
				# START NEW RELAXATION
				cd ${LOC_SCRIPTS}/myRuns/${FILE}
				if [ $MODE -eq 1 -o $MODE -eq 3 ]; then
					#JOBID1=$(sbatch --parsable script_relaxation.sh)
					#echo -e "${RED} ---> ${JOBID1} (RLX ALL) ${NC}"
					echo "NO RELAXATION STEP FOR NOW."
				else
					#echo -e "${RED}SUBMISSION OF RELAXATION JOBS SET TO FALSE ${NC}"
					#echo -e "${RED} ---> ${JOBID1} (RLX ALL) ${NC}"
					echo "NO RELAXATION STEP FOR NOW."

				fi
				RELAXATION_STATUS="FAIL"
			fi

		# if the prediction ticker is less than five, check if it's due to slurm job time limitation, then proceed with relaxation!
		elif [ $PREDICTION_TICKER -lt 5 ]; then

			cd ${LOC_SCRIPTS}/myRuns/${FILE}
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
					cd ${LOC_SCRIPTS}/myRuns/${FILE}
					if [ $MODE -eq 1 -o $MODE -eq 3 ]; then
						#jobid1=$(sbatch --parsable script_relaxation.sh)
						#echo -e "${RED} ---> ${JOBID1} (RLX ALL) ${NC}"
						echo "NO RELAXATION STEP FOR NOW."
					else
						#echo -e "${RED}SUBMISSION OF RELAXATION JOBS SET TO FALSE ${NC}"
						#echo -e "${RED} ---> ${JOBID1} (RLX ALL) ${NC}"
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
			#mkdir -p ${LOC_OUT}/UNRLXD
			mkdir -p ${LOC_OUT}/SLURMS

			# ENTER THE SCRIPTS FOLDER
			cd ${LOC_SCRIPTS}/myRuns/${FILE}

			# CONCATENATE SLURM FILES AND STORE THEM IN OUTPUT FOLDER
			cat slurm* > ${LOC_OUT}/slurm.out
			cp slurm* ${LOC_OUT}/SLURMS/

			# ENTER OUTPUT FOLDER
			cd ${LOC_OUT}

			# RENAME FILES
			for i in {1..5}
			do
				#for j in relaxed_model_${i}_*; do mv -- "$j" "${OUT_NAME}_rlx_model_${i}.pdb" ; done
				#[ -f relaxed_model_${i}_* ] && mv relaxed_model_${i}_* ${OUT_NAME}_rlx_model_${i}.pdb
				#[ -f ${OUT_NAME}_model_${i}.pdb	] &&  mv ${OUT_NAME}_model_${i}.pdb	${LOC_OUT}/UNRLXD/${OUT_NAME}_model_${i}.pdb
				[ -f model_${i}* ] && mv  model_${i}* ${OUT_NAME}_model_${i}.pdb
				[ -f ranking_model_${i}* ] && mv  ranking_model_${i}* ${LOC_OUT}/JSON/${OUT_NAME}_ranking_model_${i}.json
				[ -f ${OUT_NAME}_ranking_model_${i}.json ] &&  mv ${OUT_NAME}_ranking_model_${i}.json ${LOC_OUT}/JSON/${OUT_NAME}_ranking_model_${i}.json
			done

			cd ${LOC_OUT}/JSON/ 
			# REPLACE "Infinity" WITH LARGE NUMBER IN ALL JSON FILES FOR JSON EXTRACTION IN R
			grep -rl Infinity . | xargs sed -i 's/Infinity/9999/g'

			# REMOVE CHECKPOINT FOLDER IF FOUND
			[ -f checkpoint ] && rm -r checkpoint

			# COPY THE FOLDER INTO TRANSFERGIT REPO
			cp -r ${LOC_OUT}/ ~/transferGit/

			if [ $EXTENDED_VIEW = TRUE ]; then
				echo "(4) R PREPARATION OF ${OUT_NAME} FINISHED SUCCESSFULLY."
				echo "(5) PIPELINE OF ${OUT_NAME} FINISHED SUCCESSFULLY."
				echo "(6) COPIED FOLDER TO ~/transferGit/"
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