#!/usr/bin/env bash

### SELECT ####################################### 
##################################################
CONTINUE=TRUE
ALLOW_MODEL_SUBMISSIONS=FALSE #TRUE
ALLOW_RELAX_SUBMISSIONS=TRUE
##################################################

FILE=$1
source ./PATHS.inc
source ./01_source.inc


if [ $CONTINUE = "TRUE" ]; then

        ### COPY THE TEMPLATE FOLDER TO CREATE A DIRECTORY FOR THIS RUN
		# if the SLURMS folder is still empty, remove the scripts file folder
		#[ -s ${LOC_SCRIPTS}/myRuns/${FILE}/SLURMS_${OUT_NAME} ] || rm -r ${LOC_SCRIPTS}/myRuns/${FILE}
		# if the file folder does not exist yet, create one from the template folder
        [ -f ${LOC_SCRIPTS}/myRuns/${FILE} ] || cp -r ${LOC_SCRIPTS}/template ${LOC_SCRIPTS}/myRuns/${FILE}

		### ENTER SCRIPTS FOLDER
        cd ${LOC_SCRIPTS}/myRuns/${FILE}

        ### SET FILE NAME IN USER PARAMETERS
        echo FILE=${FILE}  > 00_user_parameters.inc

        ### SET TARGET STOICHIOMETRY
        echo $STOICHIOMETRY 300 ${OUT_NAME} > target.lst

		### ASSESS THE CURRENT STATUS OF MODEL FILES:
		cd ${LOC_OUT}

		for i in {1..5}; do
			# check if the renamed model and json files are also present:
			if [ -f  ${OUT_NAME}_model_${i}.pdb -a ${OUT_NAME}_ranking_model_${i}.json ]; then
				echo " ---> PREDICTION ${i} OF ${OUT_NAME} DONE."
				PREDICTION_STATUS="PASS"

			elif [ -f ${LOC_OUT}/UNRLXD/${OUT_NAME}_model_${i}.pdb -a ${LOC_OUT}/JSON/${OUT_NAME}_ranking_model_${i}.json ] ; then
				echo " ---> PREDICTION ${i} OF ${OUT_NAME} DONE."
				# move the unrelaxed samples back into the main folder for now
				mv  ${LOC_OUT}/UNRLXD/${OUT_NAME}_model_${i}.pdb ${LOC_OUT} 
				PREDICTION_STATUS="PASS"

				# if you cannot find the renamed models, maybe the unrenamed versions exist -> rename them appropriately
			elif  [ -f model_${i}_*_*_*_*_*.pdb -a ranking_model_${i}_*_*_*_*_*.json ]; then
				echo " ---> PREDICTION ${i} OF ${OUT_NAME} DONE."
				mv model_${i}_*_*_*_*_*.pdb ${OUT_NAME}_model_${i}.pdb
				mv ranking_model_${i}_* ${OUT_NAME}_ranking_model_${i}.json
				# if still present, remove any leftover pickle files
				[ -f model_${i}_*_*_*_*_*.pkl ] && rm model_${i}_*_*_*_*_*.pkl
				PREDICTION_STATUS="PASS"

			else
				# otherwise start the missing models
				cd ${LOC_SCRIPTS}/myRuns/${FILE}
				if [ ${ALLOW_MODEL_SUBMISSIONS} = "TRUE" ]; then
					JOBID1=$(sbatch --parsable script2_comp_model_${i}.sh)
					echo " ---> ${JOBID1} (PRED ${i})"
				else
					echo "ALLOW_MODEL_SUBMISSIONS = ${ALLOW_MODEL_SUBMISSIONS}"
					echo " ---> ${JOBID1} (PRED ${i})"
				fi
				PREDICTION_STATUS="FAIL"

			fi
		done

		### STATUS OF THE RELAXED FILES
		if [ $PREDICTION_STATUS = "PASS" ]; then 
			cd ${LOC_OUT}

			if [ -f ${LOC_OUT}/relaxed_model_1_*_*_*_*_*.pdb -a ${LOC_OUT}/relaxed_model_2_*_*_*_*_*.pdb -a ${LOC_OUT}/relaxed_model_3_*_*_*_*_*.pdb  -a ${LOC_OUT}/relaxed_model_4_*_*_*_*_*.pdb -a ${LOC_OUT}/relaxed_model_5_*_*_*_*_*.pdb ]; then
				echo "(3) RELAXATION OF ${OUT_NAME} FINISHED SUCCESSFULLY."
				# rename relaxed models
				for i in {1..5}; do
					mv relaxed_model_${i}_* ${OUT_NAME}_rlx_model_${i}.pdb
					# remove pickle files if necessary
					[ -f model_${i}_*_*_*_*_*.pkl ] && rm model_${i}_*_*_*_*_*.pkl
				done
				RELAXATION_STATUS="PASS"

			# test if all relaxed files are present -> pipeline finished!
			elif [ -f ${LOC_OUT}/${OUT_NAME}_rlx_model_1.pdb -a ${LOC_OUT}/${OUT_NAME}_rlx_model_2.pdb -a ${LOC_OUT}/${OUT_NAME}_rlx_model_3.pdb -a ${LOC_OUT}/${OUT_NAME}_rlx_model_4.pdb -a ${LOC_OUT}/${OUT_NAME}_rlx_model_5.pdb -a -s ${LOC_OUT}/slurm.out ]; then
				echo "(5) PIPELINE FINISHED SUCCESSFULLY. SEE ${LOC_OUT}"
				RELAXATION_STATUS="PASS"

			# test if some files are partially renamed already
			elif [ -f ${LOC_OUT}/relaxed_${OUT_NAME}_model_1.pdb -a ${LOC_OUT}/relaxed_${OUT_NAME}_model_2.pdb -a ${LOC_OUT}/relaxed_${OUT_NAME}_model_3.pdb -a ${LOC_OUT}/relaxed_${OUT_NAME}_model_4.pdb -a ${LOC_OUT}/relaxed_${OUT_NAME}_model_5.pdb ]; then
				echo "(3) RELAXATION OF ${OUT_NAME} FINISHED SUCCESSFULLY."
				for i in {1..5}; do
					# remove pickle files if necessary
					[ -f model_${i}_*_*_*_*_*.pkl ] && rm model_${i}_*_*_*_*_*.pkl
				done
				RELAXATION_STATUS="PASS"

			# test if some of the relaxed models are missing.. then remove all relaxed models and restart relaxation
			elif [ -f ${LOC_OUT}/relaxed_model_1_* ]; then 
				rm ${LOC_OUT}/relaxed_*
				# start new relaxation
				cd ${LOC_SCRIPTS}/myRuns/${FILE}
				if [ "${ALLOW_RELAX_SUBMISSIONS}" = "TRUE" ]; then 
					JOBID1=$(sbatch --parsable script3_relaxation.sh)
					echo " ---> ${JOBID1} (RLX ALL)"
				else
					echo "ALLOW_RELAX_SUBMISSIONS = $ALLOW_RELAX_SUBMISSIONS"
					echo " ---> ${JOBID1} (RLX ALL)"
				fi
				RELAXATION_STATUS="FAIL"

			# test if some already renamed relaxed files exist.. remove all and restart relaxation (should only happen if pipeline finished too early)
			elif [ -f ${OUT_NAME}_rlx_model_1.pdb ]; then
				rm ${OUT_NAME}_rlx_model_*
				# start new relaxation
				cd ${LOC_SCRIPTS}/myRuns/${FILE}
				if [ "${ALLOW_RELAX_SUBMISSIONS}" = "TRUE" ]; then
					JOBID1=$(sbatch --parsable script3_relaxation.sh)
					echo " ---> ${JOBID1} (RLX ALL)"
				else
					echo "ALLOW_RELAX_SUBMISSIONS = $ALLOW_RELAX_SUBMISSIONS"
					echo " ---> ${JOBID1} (RLX ALL)"
				fi
				RELAXATION_STATUS="FAIL"

			else 
				# start new relaxation
				cd ${LOC_SCRIPTS}/myRuns/${FILE}
				if [ "${ALLOW_RELAX_SUBMISSIONS}" = "TRUE" ]; then 
					JOBID1=$(sbatch --parsable script3_relaxation.sh)
					echo " ---> ${JOBID1} (RLX ALL)"
				else
					echo "ALLOW_RELAX_SUBMISSIONS = $ALLOW_RELAX_SUBMISSIONS"
					echo " ---> ${JOBID1} (RLX ALL)"
				fi
				RELAXATION_STATUS="FAIL"
			fi

		else 
			echo " ---> WAITING FOR ${OUT_NAME} MODELING TO FINISH."
		fi

		
		### STATUS OF R PREPARATION
		if [ "$RELAXATION_STATUS" = "PASS" ]; then
			mkdir -p ${LOC_OUT}/JSON
			mkdir -p ${LOC_OUT}/UNRLXD
			mkdir -p ${LOC_OUT}/SLURMS

			cd ${LOC_SCRIPTS}/myRuns/${FILE}

			# collect important info from the slurm files
			echo "(3) RELAXATION OF ${OUT_NAME} FINISHED SUCCESSFULLY."
			echo "(4) R PREPARATION OF ${OUT_NAME} FINISHED SUCCESSFULLY."


			#[ -f ${LOC_SCRIPTS}/myRuns/${FILE}/SLURMS_${OUT_NAME} ] && mv ${LOC_SCRIPTS}/myRuns/${FILE}/SLURMS_${OUT_NAME}/slurm* ${LOC_SCRIPTS}/myRuns/${FILE}
			#[ -s ${LOC_OUT}/slurm.out ] && echo "slurm.out was created and is not empty." || cat slurm* > ${LOC_OUT}/slurm.out
			cat slurm* > ${LOC_OUT}/slurm.out
			cp slurm* ~/ ${LOC_OUT}/SLURMS/

			cd ${LOC_OUT}

			for i in {1..5}
			do
				[ -f ${OUT_NAME}_model_${i}.pdb	] &&  mv ${OUT_NAME}_model_${i}.pdb	${LOC_OUT}/UNRLXD/${OUT_NAME}_model_${i}.pdb
				[ -f ${OUT_NAME}_ranking_model_${i}.json ] &&  mv ${OUT_NAME}_ranking_model_${i}.json ${LOC_OUT}/JSON/${OUT_NAME}_ranking_model_${i}.json
			done

			echo "(5) PIPELINE OF ${OUT_NAME} FINISHED SUCCESSFULLY."
			[ -f checkpoint ] && rm -r checkpoint
			ls ${LOC_OUT}
			cp -r ${LOC_OUT}/ ~/transferGit/

		else 
			echo " ---> WAITING FOR ${OUT_NAME} RELAXATION TO FINISH." 
		fi

else 
	echo " ---> WAITING FOR ${OUT_NAME} MSA TO FINISH."
fi


echo "---------------------------------------------------"
