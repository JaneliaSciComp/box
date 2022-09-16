#!/usr/bin/python3

# Designed for python >= 3.6

import os
from tpt.utilities import *
from tpt.fuster import *



def scrape_bsub_stdout_for_job_ids(raw_stdout) :
    stdout = raw_stdout.strip()   # There are leading newlines and other nonsense in the raw version
    raw_tokens = stdout.split()
    is_token_nonempty = [ len(str)>0 for str in raw_tokens ]
    token_from_token_index = ibb(raw_tokens, is_token_nonempty)
    token_count = len(token_from_token_index) 
    is_job_from_token_index = [ token=='Job' for token in token_from_token_index ] 
    token_index_from_job_index = where(is_job_from_token_index) 
    job_count = len(token_index_from_job_index)
    is_valid_from_job_index = [False] * job_count
    job_id_from_job_index = [None] * job_count
    for job_index in range(job_count) :        
        job_token_index = token_index_from_job_index[job_index]
        if job_token_index+3 >= token_count :
            # The token list is not long enough for this to be a valid job
            continue
        if token_from_token_index[job_token_index+2] != 'is' :
            continue
        if token_from_token_index[job_token_index+3] != 'submitted' :
            continue
        job_id_token = token_from_token_index[job_token_index+1]
        if len(job_id_token)<2 :
            continue
        if job_id_token[0] != '<' or job_id_token[-1] != '>' :
            continue
        job_id_as_string = job_id_token[1:-1]
        try :
            job_id = int(job_id_as_string) 
        except ValueError :
            continue
        # Stuff the job_id into the array, and not that it's valid
        job_id_from_job_index[job_index] = job_id
        is_valid_from_job_index[job_index] = True
    result = ibb(job_id_from_job_index, is_valid_from_job_index)
    return result



def scrape_bjobs_stdout_for_job_ids(stdout) :
    line_from_line_index = stdout.splitlines()
    line_count = len(line_from_line_index)
    is_valid_from_line_index = [False] * line_count
    job_id_from_line_index = [None] * line_count
    for line_index in range(line_count) :
        line = line_from_line_index[line_index]
        token_from_token_index = line.strip().split()
        token_count = len(token_from_token_index)
        if token_count == 0 :
            continue
        first_token = token_from_token_index[0]
        if first_token == 'JOBID' :
            continue  # this is the header line
        job_id_as_string = first_token
        try :
            job_id = int(job_id_as_string) 
        except ValueError :
            continue
        # Stuff the job_id into the array, and not that it's valid
        job_id_from_line_index[line_index] = job_id
        is_valid_from_line_index[line_index] = True
    result = ibb(job_id_from_line_index, is_valid_from_line_index)
    return result



def main() :
    # Make sure we're in the same folder as this script
    this_script_path = os.path.realpath(__file__)
    this_folder_path = os.path.dirname(this_script_path)
    os.chdir(this_folder_path)

    # # Make a fresh copy of the flyvisionbox "GRuFf" folder
    # # This is the local version of /groups/reiser/flyvisionbox
    # read_only_gruff_folder_path = os.path.join(this_folder_path, 'flyvisionbox-data-test-2022-04-22-single-read-only')
    # if os.path.exists(gruff_folder_path) :
    #     run_subprocess(['rm', '-rf', gruff_folder_path])
    # run_subprocess(['cp', '-R', '-T', read_only_gruff_folder_path, gruff_folder_path])
    gruff_folder_path = '/groups/reiser/flyvisionbox'

    # For historical reasons, the code uses 'checkpoint' folders with names like:
    #
    # 00_incoming
    # 00_quarantine_not_split
    # 01_quarantine_not_compressed
    # 01_sbfmf_compressed
    # 02_fotracked
    # 04_loaded
    # 04_quarantine_not_loaded
    # 05_analyzed
    # 99_aside
    #
    # We want to clear these out, or at least the ones that we will touch
    incoming_folder_path = os.path.join(this_folder_path, '00_incoming')
    # run_subprocess(['rm', '-rf', incoming_folder_path])
    run_subprocess(['rm', '-rf', './00_quarantine_not_split'])
    run_subprocess(['rm', '-rf', './01_quarantine_not_compressed'])
    #run_subprocess(['rm', '-rf', './01_sbfmf_compressed'])
    run_subprocess(['rm', '-rf', './02_fotracked'])

    # # And now make a fresh 00_incoming folder
    # os.mkdir(incoming_folder_path)

    # # The gruff folder should contain a folder named "box_data", which
    # # should contain experiment folders.  We want to run the pipeline
    # # on all of these.
    # # We make this happen my making symlinks to each one in the 00_incoming folder
    # box_data_folder_path = os.path.join(gruff_folder_path, 'box_data')
    # name_from_experiment_index = os.listdir(box_data_folder_path)
    # path_from_experiment_index = [ os.path.join(box_data_folder_path, name) for name in name_from_experiment_index ]
    # experiment_count = len(name_from_experiment_index)
    # for experiment_index in range(experiment_count) :
    #     experiment_folder_path = path_from_experiment_index[experiment_index]
    #     run_subprocess(['ln', '-s', experiment_folder_path, incoming_folder_path])

    # Count and report how many experiments will be analyzed
    box_data_folder_path = os.path.join(gruff_folder_path, 'box_data')
    name_from_experiment_index = os.listdir(box_data_folder_path)
    #path_from_experiment_index = [ os.path.join(box_data_folder_path, name) for name in name_from_experiment_index ]
    experiment_count = len(name_from_experiment_index)
    if experiment_count == 0 :
        printfe('No experiments to track in %s.\n' % incoming_folder_path)
        return
    elif experiment_count == 1 :
        printfe('There is 1 experiment that will be tracked.\n')
    else :
        printfe('There are %d experiments that will be tracked.\n' % experiment_count)


    # Each experiment consists of multiple 'protocols' (usually two, named 01_something and 02_something).
    # Within each protocol, there are several sequences, e.g. seq1, seq2, seq 8.
    # There's a .avi video for each sequence.
    # Each video is a video of six tubes, each with a dozen or so flies in it.

    # # The first pipeline stage is to split each .avi video into six videos,
    # # one for each tube.
    # printfe('\n\n\n***Stage 1***\n')
    # splitter_script_path = os.path.join(this_folder_path, 'scripts', 'TubeSplitter', 'avi_extract.sh')
    # (stdout, stderr) = run_subprocess_and_return_stdout_and_stderr([splitter_script_path])
    # printe('stdout:')
    # printe(stdout)
    # printe('stderr:')
    # printe(stderr)
    # job_ids = scrape_bsub_stdout_for_job_ids(stdout)
    # status_from_job_index = bwait(job_ids)
    # printe('tube-splitter job statuses: ', status_from_job_index)
    # did_all_jobs_work = all([status==+1 for status in status_from_job_index])
    # if not did_all_jobs_work :
    #     raise RuntimeError('Some jobs failed in tube-splitting stage')

    # # The second pipeline stage is to convert each per-tube .avi to a .sbfmf
    # # Annoyingly, this one doesn't spit out the job id's, so we have to do a bjobs
    # # before and one just after, and the setdiff is the job id list
    # printfe('\n\n\n***Stage 2***\n')
    # splitter_script_path = os.path.join(this_folder_path, 'scripts', 'SBFMFConversion', 'avi_sbfmf_conversion.sh')
    # stdout = run_subprocess_and_return_stdout(['bjobs'])
    # job_ids_before = scrape_bjobs_stdout_for_job_ids(stdout)
    # run_subprocess([splitter_script_path])
    # stdout = run_subprocess_and_return_stdout(['bjobs'])
    # job_ids_after = scrape_bjobs_stdout_for_job_ids(stdout)
    # job_ids = listsetdiff(job_ids_after, job_ids_before)
    # status_from_job_index = bwait(job_ids)
    # printe('sbfmf-conversion job statuses: ', status_from_job_index)
    # did_all_jobs_work = all([status==+1 for status in status_from_job_index])
    # if not did_all_jobs_work :
    #     raise RuntimeError('Some jobs failed in sbfmf-conversion stage')

    # The third pipeline stage does the actual tracking
    printfe('\n\n\n***Stage 3***\n')
    splitter_script_path = os.path.join(this_folder_path, 'scripts', 'FlyTracking', 'fotrak.sh')
    (stdout, stderr) = run_subprocess_and_return_stdout_and_stderr([splitter_script_path])
    printe('stdout:')
    printe(stdout)
    printe('stderr:')
    printe(stderr)
    job_ids = scrape_bsub_stdout_for_job_ids(stdout)
    status_from_job_index = bwait(job_ids)
    printe('fly-tracking job statuses: ', status_from_job_index)
    did_all_jobs_work = all([status==+1 for status in status_from_job_index])
    if not did_all_jobs_work :
        raise RuntimeError('Some jobs failed in fly-tracking stage')

    # Declare victory
    printfe("Pipeline finished successfully.\n")



# If called from command line, run main()
if __name__ == "__main__":
    main()
