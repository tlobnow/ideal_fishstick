# ideal_fishstick

1. Activate the environment via `conda activate fishy`

2. Enter the folder containing `fasta_files`
    - supply new fasta files / folder structures
    - take a look at the existing test files
    - IMPORTANT: You can create folders containing files, but only fasta files in the main folder will be prepared.
    - To make sure everything is prepared, simply copy all fasta files into the main fasta_files directory as well

3. Enter the `scripts` folder
    - start the `prepYourFeatures.sh` script to prepare MSAs for modeling (for each file in the fasta folder)

4. Supervise the progress of slurm jobs
    - `check_squeue.sh` will refresh every 10 seconds to show currently running jobs
    - `squeue.sh` will also show currently running jobs, but will not refresh

5. Check the `feature_files` folder
    - every prepared fasta should now have a folder containing a `features.pkl` file

6. Enter the `scripts` folder and choose one of the following run options:
    - Run a single setup:
        - Open `00_source.inc`
        - Set complex stoichiometry (more info in the script)
        - Set desired output name
        - Start the run with `./iRun.sh`
    - Run multiple samples following a set stoichiometry:
        - Open `01_source.inc`
        - Set the folder name (folder with all protein fasta files of interest, should be stored in ~/ideal_fishstick/fasta_files/yourFolderName)
        - Set complex stoichiometry (Partner A, B, adjust as needed)
        - Set desired output name structure
        - e.g. I want all complexes to be modeled against 4xMyD88 -> OUT_NAME=MYD88_x4_${FILE}_x1
        - ${FILE} will be replaced by each of the files in your designated folder
        - Start the runs with `./multiRun.sh` (this script prompts execution of `oneRun.sh` and iterates over files in your designated folder)
        - IMPORTANT: By default, the script will run all possible modeling scripts.
        - If the model has not finished yet, but the slurm job is already running, the script will start another job (we don't want that)
        - To avoid this behaviour, simply open `oneRun.sh` and change MODE to 2
        - This will only allow processing of your files, no new job submission
    - Run two proteins in a matrix-like setup (= parameter scan) to check for stoichiometric indications/needs
        - iScores will be most likely be highest with the correct biologically relevant stoichiometry
        - Open `02_parameterScan.inc`
        - Set the complex stoichiometry
        - Set the desired output name structure
        - Set the desired min/max monomers you wish to check
        - e.g. MIN=1, MAX=6 will run all 36 combinatory possibilities
        - it depends on monomer length how many will actually be possible to predict
        - at some point the complexes will be too complex to finish within the 24hr slurm job limit
        - Start the run with `./parameterScan.sh`

7. While the slurm jobs are running:
    - check which jobs have successfully finished or are still outstanding per run folder:
        - change MODE in each respective run script (iRun.sh, oneRun.sh, parameterScan.sh) to `MODE=2`
        - this will prevent submission of new jobs
        - DO NOT FORGET TO CHANGE BACK TO MODE=1 to allow new job submissions
    - check progress of running jobs --> as described in (4.)

8. Once the jobs have finished:
    - You can restart the script (iRun.sh, multiRun.sh, or parameterScan.sh), to:
        - get confirmation that all jobs successfully finished (no new submissions necessary)
        - process finished files for analysis in R:
            - this step is optional, but will help analysis beyond the visual analysis of your .pdb files
            - changes model names to the specific output name
            - replaces the term "Infinity" with a large number in JSON files to make them readable in R
            - move JSON files into a designated folder
    - You can view your results in the `output_files` folder
