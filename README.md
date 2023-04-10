## PROTEIN COMPLEX PREDICTION ON MPCDF RAVEN


### FIRST TIME SETUP

1. Download Miniconda (follow instructions and type yes for additional package installations)

        curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh


2. Install Miniconda on your account (follow instructions and type yes for additional package installations)

        ./Miniconda3-latest-Linux-x86_64.sh


3. Create a new environment you will work in:

        conda create --name fishy python=3.8


4. Activate the environment via

        conda activate fishy

    To automatically activate the environment at login, you can add `conda activate fishy` to your `~/.bashrc` file (open the file, paste it) - At each new login, the `fishy` environment will already be preloaded.


5. Clone Github repositories into your MAIN folder and run the `setup.sh` script:

        cd
        git clone https://github.com/FreshAirTonight/af2complex.git
        git clone https://github.com/tlobnow/ideal_fishstick.git
        cd ideal_fishstick
        ./setup.sh



### FOR EVERY NORMAL SESSION

1. Activate the environment via 

        conda activate fishy

2. Enter the folder containing `fasta_files`
    - supply new fasta files / folder structures
    - take a look at the existing test files
    - **IMPORTANT**: You can create folders containing files, but only fasta files in the main folder will be prepared.
    - To make sure everything is prepared, simply copy all fasta files into the main fasta_files directory as well

3. Enter the `scripts` folder
    - start the `msa.sh` script to prepare feature files for modeling through Multiple Sequence Alignments (for each file in the fasta folder)

4. Supervise the progress of slurm jobs
    - `check_squeue.sh` will refresh every 10 seconds to show currently running jobs
    - `squeue.sh` will also show currently running jobs, but will not refresh

5. Check the `feature_files` folder
    - every prepared fasta should now have a folder containing a `features.pkl` file

6. Enter the `scripts` folder and choose one of the following run options:
    - Run a single setup:
        - Open `iRun.sh`
        - Set complex stoichiometry (more info in the script)
        - Set desired output name
        - Start the run with `./iRun.sh`
    - Run multiple samples following a set stoichiometry:
        - Open `01_source.inc`
        - Set `RUN=MULTI`
        - Set the `FOLDER` name (folder with all protein fasta files of interest, should be stored in `~/ideal_fishstick/fasta_files/yourFolderName`)
        - Set stoichiometry structure (Partner A, B, adjust as needed)
        - Set desired output name structure
        - e.g. If you want all complexes to be modeled against 2xMyD88 -> OUT_NAME=MYD88_x2_${FILE}_x1
        - ${FILE} will be replaced by each of the files in your designated folder
        - Start the runs with `./multiRun.sh` (this script prompts execution of `oneRun.sh` and iterates over files in your designated folder)
        - **IMPORTANT**: By default, the script will run all possible modeling scripts.
        - If the model has not finished yet, but the slurm job is already running, the script will start another job (we don't want that)
        - To avoid this behaviour, simply open `oneRun.sh` and change MODE to 2
        - This will only allow processing of your files, no new job submission
    - Run two proteins in a matrix-like setup (= parameter scan) to check for stoichiometric ratios
        - iScores will be most likely be highest if modeled as the correct biological stoichiometry
        - Open `01_source.inc`
        - Change run setting to `RUN=SCAN`
        - Set the stoichiometry structure and monomers of choice
        - Set the desired output name structure
        - Set the desired min/max number of monomers you wish to check
        - e.g. MIN=1, MAX=6 will run all 36 combinatory possibilities
        - it depends on monomer length how many can be predicted
        - at some point the complexes will be too complex to finish within the 24hr slurm job limit
        - Start the run with `./parameterScan.sh`

7. While the slurm jobs are running:
    - check which jobs have successfully finished or are still outstanding per run folder:
        - change MODE in each respective run script (iRun.sh, oneRun.sh, parameterScan.sh) to `MODE=2`
        - this will prevent submission of new jobs
        - DO NOT FORGET TO CHANGE BACK TO MODE=1 to allow new job submissions
    - check progress of running jobs --> as described in (4.)

8. Once the model predictions have finished:
    - You can restart the script (iRun.sh, multiRun.sh, or parameterScan.sh), to:
        - get confirmation that all jobs successfully finished (no new submissions necessary)
        - run the relaxation to get rid of minor clashes/inconsistencies (model improvement)
        - process finished files for analysis in R:
            - this step is optional, but will help analysis beyond the visual analysis of your .pdb files
            - changes model names to the specific output name
            - replaces the term "Infinity" with a large number in JSON files to make them readable in R
            - move JSON files into a designated folder
    - You can view your results in the `output_files` folder
