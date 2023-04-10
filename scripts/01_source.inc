RUN=MULTI		# executes multiRun.sh that iterates over oneRun.sh
#RUN=SCAN		# executes stoichiometry scans via parameterScan.sh

if [ "$RUN" = "MULTI" ]; then
	FOLDER=TEST
			# Specify the folder where your fasta files are located.
			# Folder will be used to create a list of the fasta base names, for which models will be run.

	FILE_A=MYD88
	
	# SET THE STOICHIOMETRY
	#N=1
	N_A=1
	N_B=1
	STOICHIOMETRY=${FILE_A}_MOUSE:${N_A}/${FILE}:${N_B}
        
	# SET THE OUTPUT NAME
	#OUT_NAME=${FILE_A}_x${N_A}_${FILE}_x${N_B}	# standard OUT_NAME
	OUT_NAME=${FILE_A}_${FILE}_x${N_B}		# single MyD88:XXXX runs

elif [ "$RUN" = "SCAN" ]; then
	
	# PROVIDE PARTNER A (MONOMER I) IN MATRIX SETUP
	FILE_A=MYD88_MOUSE
	
	# PROVIDE PARTNER B (MONOMER II) IN MATRIX SETUP
	FILE=IRAK4_MOUSE

	# SET THE STOICHIOMETRY
	STOICHIOMETRY=${FILE_A}:${N_A}/${FILE}:${N_B}
	
	# SET THE OUTPUT NAME
	OUT_NAME=MYD88_x${N_A}_${FILE}_x${N_B}

	# SET THE MIN AND MAX NUMBER OF MONOMERS FOR THE MATRIX SETUP
	MIN=1
	MAX=6

else
	echo "PLEASE SPECIFY THE RUN MODE."
fi

source ~/ideal_fishstick/scripts/PATHS.inc

##########################################################################################################################
##########################################################################################################################
##########################################################################################################################

# A WORD ON THE MODEL SCRIPT

        # (1) prepare feature files for all fasta files
        #       -> output in feature_files (features.pkl)
        # (2) run the predictions (5 neural network models) 
        #       -> output in output_files ($OUT_NAME_model_*.pdb, *.json in /JSON/)
        # (3) running the relaxation of each model can minimize clashes in addition to normal modeling
        #       -> output in output_files (relaxed_model_*.pdb)
        # (4) run the R_PREP script to combine all created slurm files into one big slurm (used to extract the metric output) 
        #       -> output in output_files (slurm.out)
        #       -> move PKL files to designated folder
        # (5) Let you know that everything is finished.



# A WORD ON STOICHIOMETRY IN THIS PIPELINE  # taken from the AF2C Github READ.ME --> see "https://github.com/FreshAirTonight/af2complex" for more info!

        # The stoichiometry of your target, be it a monomer or a complex, is defined in an input list file. In the examples provided, the target list
        # files are under subdirectory targets. The general format of a target in a list is as the follows (one line per target),

        #       A:2/B:2/C/D/E <total_length> <target_name> # the latter two can be left open to be auto-generated!

        # where the first column defines the stoichiometry of the complex, e.g., A:2/B:2/C/D/E, using the IDs of
        # the individual sequences, :<num> after each protein defines its homo copy number, and / to separate distinct monomers.
        # The IDs of monomers are also used as the name of sub-directory for locating their input features. The second column, <total_length>, is the
        # total number of amino acids of the putative complex. This is mainly for load-balance in a large-scale run on a computing cluster, and it is
        # parsed but not used by the model inference python script. The third column,
        # <target_name>, is the name of the sub-directory for placing predicted structural models.

        # In the example target above, the complex is made of five protein sequences named A to E, and protein A and B each have two copies. During a
        # prediction, the program will look for individual input features of A to E under the input feature directory, e.g, $input_dir/A/features.pkl, and
        # then assemble them into the features for complex structure prediction. If you provide only a single protein without a copy number, e.g., A
        # <seq_length>, it reverts to a structural prediction of a single protein A.
        # A more advanced example of using the domain cropping feature is like the follows

        #       A|19-200;500-700:2/B/C 1788 A2BC

        # where the residue ranges, 19 to 200 and 500 to 700, are taken out from A's full length input features for modeling A2BC, composed of two copies
        # of A, single copy of B and C, and with a total size of 1788 AAs. This format allows convenient and rapid tests of part of a large sequence, and
        # also avoid possible errors caused by using a partial sequence to derive MSAs.

        # A new symbol + is introduced in version 1.3.0. This plus sign separates individual chains like /, and additionally marks where the interface
        # score will be calculated. For example, in A:2/B:2/C/D, the interface score (iScore) will be calculated on the full target. If there is a complex
        # formed, e.g., A:2/B:2, it will give a high iScore regardless whether C or D interacts with A2:B2 or not. The plus sign is introduced such that one can 
        # evaluate iScore on specified combinations of chains. If we changed the target format to 

        #       A:2/B:2+C/D

        # the iScore will be calculate only for interface between A2:/B:2 and C/D, as it treats A2:/B2 and C/D as two super entities. Please checkout Example 3 
        # and a script for interface score calculation.
