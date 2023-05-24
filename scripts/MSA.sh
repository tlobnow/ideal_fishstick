#!/usr/bin/env bash

# CHECK WHETHER THE FILE OF INTEREST HAS A FOLDER IN THE FEATURE_FILES DIRECTORY
if [[ -d "$LOC_FEATURES/$FILE" ]]; then
    # IF THERE IS A FOLDER, CHECK IF A FEATURES.PKL FILE IS IN THERE (NECESSARY FOR MODELING)
    if [[ -f "$LOC_FEATURES/$FILE/features.pkl" ]]; then
        # IF THE FEATURES.PKL EXISTS:
        CONTINUE=TRUE
        if [[ $EXTENDED_VIEW == "TRUE" ]]; then
            printf "(1) (^o^)/ %s READY!\n" "$FILE"
        fi
    else
        # IF THE FEATURES.PKL FILE IS MISSING:
        CONTINUE=FALSE
        if [[ $MODE -ne 2 ]]; then
            # ENTER FILE FOLDER
            cd "$LOC_FEA_GEN/$FILE"
            # SAVE THE FILE NAME IN 00_user_parameters.inc
            echo "FILE=$FILE" > "$LOC_FEA_GEN/$FILE/00_user_parameters.inc"
            # START A SLURM JOB TO RUN THE MSA
            JOBID1=$(sbatch --parsable script_msa.sh)
		running_jobs+=("$JOBID")
            printf "%s /(x.x) (%s) %s FEATURES FILE MISSING... STARTING MSA! %s\n" "$RED" "$JOBID1" "$FILE" "$NC"
        else 
            printf "%s /(x.x) NO SUBMISSION OF MSA JOBS - CHANGE MODE TO ALLOW NEW MSA JOBS.%s\n" "$RED" "$NC"
        fi
    fi
# IF NO FOLDER IS FOUND IN THE FEATURE_FILES DIRECTORY:
else
    CONTINUE=FALSE
    if [[ $MODE -ne 2 ]]; then
        # CREATE FILE FOLDER FROM TEMPLATE
        cp -r "$LOC_FEA_GEN/feaGen_template" "$LOC_FEA_GEN/$FILE"
        # ENTER FILE FOLDER
        cd "$LOC_FEA_GEN/$FILE"
        # SAVE THE FILE NAME IN 00_user_parameters.inc
        echo "FILE=$FILE" > "$LOC_FEA_GEN/$FILE/00_user_parameters.inc"
        # START A SLURM JOB TO RUN THE MSA
        JOBID1=$(sbatch --parsable script_msa.sh)
	running_jobs+=("$JOBID")
        printf "%s /(x.x) (%s) %s FEATURES FILE MISSING... STARTING MSA! %s\n" "$RED" "$JOBID1" "$FILE" "$NC"
    else 
        printf "%s /(x.x) NO SUBMISSION OF MSA JOBS - CHANGE MODE TO ALLOW NEW SUBMISSIONS.%s\n" "$RED" "$NC"
    fi
fi
