import glob
import os.path
import sys
import re

import sage
import scipy.io

import subprocess as sub


def pipelineSetting(settingName):
    # Lookup the setting using the pipeline_settings.pl tool in the Tools directory near this script.
    toolPath = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(sys.argv[0]))), 'Tools', 'pipeline_settings.pl')
    p = sub.Popen([toolPath, settingName], stdout=sub.PIPE, stderr=sub.PIPE)
    output, errors = p.communicate()
    if p.returncode != 0:
        raise ValueError('Could not look up the \'' + settingName + '\' pipeline setting.')
    else:
        return output.strip()

# The list of fields to load for each sequence.  The fields that are duplicates of the analysis_info data have been filtered out.
fields = {}
fields[1.4] = {}
fields[1.4][1] = ['mov_frac', 'med_vel', 'Q3_vel', 'tracked_num']
fields[1.4][2] = ['peak_mov_frac', 'peak_med_vel', 'long_after_med_vel', 'baseline_mov_frac', 'baseline_med_vel', 'startle_resp', 'tracked_num', 'average_ts_med_vel']
fields[1.4][3] = ['tracked_num', 'mean_motion_resp', 'std_motion_resp', 'motion_resp_diff']
fields[1.4][4] = ['Side_diff', 'tracked_num', 'med_vel_X', 'med_disp_X', 'disp_max', 'disp_rise']
fields[1.4][5] = ['Side_diff', 'tracked_num', 'med_vel_X', 'med_disp_X', 'disp_end', 'disp_peak', 'disp_peak_SE']
fields[1.5] = {}
fields[1.5][1] = ['mov_frac', 'max_mov_frac', 'med_vel', 'max_vel', 'Q3_vel', 'tracked_num', 'max_tracked_num', 'min_tracked_num']
fields[1.5][2] = fields[1.5][1] + ['peak_mov_frac', 'peak_med_vel', 'long_after_med_vel', 'baseline_mov_frac', 'baseline_med_vel', 'startle_resp', 'average_ts_med_vel']
fields[1.5][3] = fields[1.5][1] + ['mean_motion_resp', 'std_motion_resp', 'motion_resp_diff']
fields[1.5][4] = fields[1.5][1] + ['Side_diff', 'med_vel_x', 'med_disp_x', 'disp_max', 'disp_rise', 'disp_norm_max']
fields[1.5][5] = fields[1.5][1] + ['Side_diff', 'med_vel_x', 'med_disp_x', 'disp_end', 'disp_peak', 'disp_peak_SE', 'UVG_pref_diff', 'UVG_cross']
fields[1.6] = {}
fields[1.6][1] = ['mov_frac', 'max_mov_frac', 'med_vel', 'max_vel', 'Q3_vel', 'tracked_num', 'max_tracked_num', 'min_tracked_num']
fields[1.6][2] = fields[1.6][1] + ['peak_mov_frac', 'peak_med_vel', 'long_after_med_vel', 'baseline_mov_frac', 'baseline_med_vel', 'startle_resp', 'average_ts_med_vel']
fields[1.6][3] = fields[1.6][1] + ['mean_motion_resp', 'std_motion_resp', 'motion_resp_diff']
fields[1.6][4] = fields[1.6][1] + ['Side_diff', 'med_vel_x', 'med_disp_x', 'disp_max', 'disp_rise', 'disp_norm_max']
fields[1.6][5] = fields[1.6][1] + ['Side_diff', 'med_vel_x', 'med_disp_x', 'disp_end', 'disp_peak', 'disp_peak_SE', 'UVG_pref_diff', 'UVG_cross']
fields[1.7] = {}
fields[1.7][1] = ['mov_frac', 'max_mov_frac', 'med_vel', 'max_vel', 'Q3_vel', 'tracked_num', 'max_tracked_num', 'min_tracked_num']
fields[1.7][2] = fields[1.7][1] + ['peak_mov_frac', 'peak_med_vel', 'long_after_med_vel', 'baseline_mov_frac', 'baseline_med_vel', 'startle_resp', 'average_ts_med_vel']
fields[1.7][3] = fields[1.7][1] + ['mean_motion_resp', 'std_motion_resp', 'motion_resp_diff']
fields[1.7][4] = fields[1.7][1] + ['Side_diff', 'med_vel_x', 'med_disp_x', 'disp_max', 'disp_rise', 'disp_norm_max', 'disp_max_time', 'disp_end']
fields[1.7][5] = fields[1.7][1] + ['Side_diff', 'med_vel_x', 'med_disp_x', 'disp_end', 'disp_peak', 'disp_peak_SE', 'UVG_pref_diff', 'UVG_cross']
fields[1.8] = {}
fields[1.8][1] = ['mov_frac', 'max_mov_frac', 'med_vel', 'max_vel', 'Q3_vel', 'tracked_num', 'max_tracked_num', 'min_tracked_num']
fields[1.8][2] = fields[1.8][1] + ['peak_mov_frac', 'peak_med_vel', 'long_after_med_vel', 'baseline_mov_frac', 'baseline_med_vel', 'startle_resp', 'average_ts_med_vel']
fields[1.8][3] = fields[1.8][1] + ['mean_motion_resp', 'std_motion_resp', 'motion_resp_diff', 'direction_index', 'mean_dir_index', 'std_dir_index', 'dir_index_diff']
fields[1.8][4] = fields[1.8][1] + ['med_vel_x', 'med_disp_x', 'disp_max', 'disp_rise', 'disp_norm_max', 'disp_max_time', 'disp_end', 'direction_index', 'mean_cum_dir_index', 'cum_dir_index_max', 'cum_dir_index_rise', 'cum_dir_index_max_time', 'cum_dir_index_end']
fields[1.8][5] = fields[1.8][1] + ['med_vel_x', 'med_disp_x', 'disp_end', 'disp_peak', 'disp_peak_SE', 'UVG_pref_diff', 'UVG_cross', 'direction_index', 'mean_cum_dir_index', 'cum_dir_index_end', 'cum_dir_index_peak', 'cum_dir_index_peak_SE', 'UVG_pref_diff_dir_index', 'UVG_cross_dir_index']

# The list of plots generated.
plots = {}
plots[1.5] = ['comparison_summary']
plots[1.6] = plots[1.5]
plots[1.7] = plots[1.6]
plots[1.8] = ['med_vel_comparison_summary']
tempPlots = {}
tempPlots[1.5] = ['seq2_median_velocity_averaged', 'seq2_median_velocity', 'seq3_LinMotion_median_x_velocity_&_average', 'seq4_avg_vel_disp', 'seq4_median_velocity_x&PI', 'seq5_avg_vel_disp', 'seq5_median_velocity_x&PI']
tempPlots[1.6] = tempPlots[1.5]
tempPlots[1.7] = tempPlots[1.6]
tempPlots[1.8] = ['seq2_mean_med_vel', 'seq2_med_vel', 'seq3_LinMotion_median_x_velocity_and_average', 'seq4_avg_vel_disp', 'seq4_med_vel_x_and_DI', 'seq5_avg_vel_disp', 'seq5_med_vel_x_and_DI']

experimentPath = sys.argv[1]
experimentName = os.path.basename(experimentPath)

sageEnv = pipelineSetting('sage_env')
dataDir = pipelineSetting('data_root')

try:
    # Make sure the directory really exists.
    if not os.path.exists(experimentPath):
        raise IOError, 'No experiment directory found at ' + experimentPath
    
    db = sage.Connection(paramsPath = '/groups/flyprojects/home/olympiad/config/SAGE-' + sageEnv + '.config')
    cv = sage.CV('fly_olympiad_box')
    olympiadLab = sage.Lab('olympiad')
    
    # Make sure the experiment exists in SAGE.
    experiments = db.findExperiments(name = experimentName, typeTerm = cv.term('box'), lab = olympiadLab)
    if len(experiments) == 0:
        raise ValueError, 'Could not find the \'' + experimentName + '\' experiment in SAGE.' 
    experiment = experiments[0]
    
    imageFamily = sage.ImageFamily(db, 'fly_olympiad_box', 'http://img.int.janelia.org/flyolympiad-data/fly_olympiad_box/', dataDir, olympiadLab)
    
    # Check which images have been linked.
    images = imageFamily.findImages(experiment)
    imageDict = {}
    avisLinked = False
    sbfmfsLinked = False
    for image in images:
        imageDict[image.name] = image
        if image.name.endswith('.avi'):
            avisLinked = True
        elif image.name.endswith('.sbfmf'):
            sbfmfsLinked = True
    
    # Get the list of temperature sub-folders from the top-level .exp file (which is really a .mat file)
    expPath = os.path.join(experimentPath, experimentName + '.exp')
    mat = scipy.io.loadmat(expPath, struct_as_record = True)
    actionList = mat['experiment']['actionlist'][0, 0]
    actionSource = mat['experiment']['actionsource'][0, 0][0]
    tempCount = actionSource.shape[0]
    
    # Make an easily indexed set of all tracking sessions for the experiment.
    trackingSessions = {}
    for session in experiment.findSessions(typeTerm = cv.term('tracking')):
        version = session.getProperty(cv.term('version'))
        region = int(session.getProperty(cv.term('region')))
        sequence = int(session.getProperty(cv.term('sequence')))
        temperature = float(session.getProperty(sage.CV('fly').term('temperature_setpoint')))
        if temperature not in trackingSessions:
            trackingSessions[temperature] = {}
        if version not in trackingSessions[temperature]:
            trackingSessions[temperature][version] = {}
        if sequence not in trackingSessions[temperature][version]:
            trackingSessions[temperature][version][sequence] = {}
        trackingSessions[temperature][version][sequence][region] = session
    # Make an easily indexed set of all analysis sessions for the experiment.
    analysisSessions = {}
    for session in experiment.findSessions(typeTerm = cv.term('analysis')):
        version = float(session.getProperty(cv.term('version')))
        region = int(session.getProperty(cv.term('region')))
        sequence = int(session.getProperty(cv.term('sequence')))
        temperature = float(session.getProperty(cv.term('temperature')))
        if temperature not in analysisSessions:
            analysisSessions[temperature] = {}
        if version not in analysisSessions[temperature]:
            analysisSessions[temperature][version] = {}
        if sequence not in analysisSessions[temperature][version]:
            analysisSessions[temperature][version][sequence] = {}
        analysisSessions[temperature][version][sequence][region] = session
    # Keep track of whether all tubes are running the same line.
    commonLine = None
    
    # Load the analysis from all output directories. (Output, Output_1.1_1.6, etc.)
    outputDirs = glob.glob(os.path.join(experimentPath, 'Output*'))
    outputRE = re.compile("^Output_(\d+\.\d+(\.\d+)?)_(\d+\.\d+)$")
    for outputDir in outputDirs:
        outputDirName = os.path.basename(outputDir)
        match = outputRE.match(outputDirName)
        if match:
            trackingVersion = match.groups()[0]
        else:
            trackingVersion = None
        for tempIndex in actionSource:
            action = actionList[0,tempIndex - 1]
            protocol = action['name'][0]
            temperature = float(action['T'][0,0])
            
            tempPrefix = '%02d_%s_%02d' % (tempIndex, protocol, temperature)
            shortTempPrefix = '%02d_%s' % (tempIndex, protocol)
            
            # Make sure the analysis results file is there.
            analysisPath = os.path.join(outputDir, tempPrefix + '_analysis_results.mat')
            if not os.path.exists(analysisPath):
                raise IOError, 'No analysis results file found at ' + analysisPath
            
            # Load the file and make sure the analysis_results field is present.
            mat = scipy.io.loadmat(analysisPath, struct_as_record = True)
            if 'analysis_results' not in mat:
                raise ValueError, 'No analysis_results field found in the analysis results file.'
            analysisResults = mat['analysis_results']
            
            for tubeNum in range(1, 7):
                tubeAnalysis = analysisResults[0, tubeNum - 1]
                
                # Figure out which version of the analysis this is.
                if tubeAnalysis['analysis_version'].size > 0:
                    analysisVersion = tubeAnalysis['analysis_version'][0,0]
                    if not analysisVersion in fields or not analysisVersion in plots or not analysisVersion in tempPlots:
                        raise ValueError, 'Unknown analysis version: ' + str(analysisVersion)
                if analysisVersion is None:
                    raise ValueError, 'Could not determine analysis version.'
                if not trackingVersion:
                    if analysisVersion == 1.5:
                        trackingVersion = 1.0
                    elif analysisVersion == 1.6:
                        trackingVersion = 1.1
                    elif analysisVersion == 1.7:
                        trackingVersion = 1.1
                    else:
                        raise ValueError, 'Could not determine which tracking version goes with analysis version ' + str(analysisVersion)
                
                # Look up the region session so we know which line was in the tube.
                sessions = experiment.findSessions(name = str(tubeNum), typeTerm = cv.term('region'))
                if len(sessions) != 1:
                    raise ValueError, 'Could not find the session for tube ' + str(tubeNum) + ' of experiment ' + experimentName
                tubeSession = sessions[0];
                
                if commonLine is None:
                    commonLine = tubeSession.line
                elif commonLine != tubeSession.line:
                    commonLine = False
                
                for seqNum in range(1, 6):
                    try:
                        trackingSession = trackingSessions[temperature][trackingVersion][seqNum][tubeNum]
                    except:
                        trackingSession = None  
                    try:
                        analysisSession = analysisSessions[temperature][analysisVersion][seqNum][tubeNum]
                    except:
                        analysisSession = None
                    if not analysisSession:
                        # Create an "analysis" session.
                        analysisSession = experiment.createSession('Analysis %.1f of tracking %s for tube %d, sequence %d @ %g degrees' % (analysisVersion, trackingVersion, tubeNum, seqNum, temperature), cv.term('analysis'), tubeSession.line, olympiadLab)
                        analysisSession.setProperty(cv.term('version'), analysisVersion)
                        analysisSession.setProperty(cv.term('region'), tubeNum)
                        analysisSession.setProperty(cv.term('sequence'), seqNum)
                        analysisSession.setProperty(cv.term('temperature'), temperature)
                        
                        # Create session relatiosnships between the analysis session and the tube session and the equivalent tracking session.
                        analysisSession.createRelationship(tubeSession, cv.term('was_performed_in'))
                        if trackingSession:
                            analysisSession.createRelationship(trackingSession, sage.CV('schema').term('is_derived_from'))
                        
                        # Attach the score arrays to the session.
                        seqStruct = tubeAnalysis['seq' + str(seqNum)]
                        for fieldName in fields[analysisVersion][seqNum]:
                            matrix = seqStruct[fieldName][0,0]
                            analysisSession.storeScoreArray(cv.term(fieldName), matrix, dataType = 'half')
                    
                    if not sbfmfsLinked:
                        # Store links to the SBFMF files.
                        sbfmfPath = '%s/%s/%s_tube%d_sbfmf/%s_seq%d_tube%d.sbfmf' % (experimentName, tempPrefix, shortTempPrefix, tubeNum, shortTempPrefix, seqNum, tubeNum)
                        imageFamily.addImage(sbfmfPath, experiment = experiment, line = tubeSession.line, creator = 'Box Pipeline', imageType = 'tube_sequence_movie')
             
            if analysisVersion is not None:
                # Store links to the temperature specific plots that haven't already been loaded.
                for plotName in tempPlots[analysisVersion]:
                    pdfName = experimentName + '/' + outputDirName + '/' + tempPrefix + '_' + plotName + '.pdf'
                    if pdfName not in imageDict:
                        imageFamily.addImage(pdfName, experiment = experiment, line = None if commonLine == False else commonLine, creator = 'Box Pipeline', imageType = plotName)
                    pngName = experimentName + '/' + outputDirName + '/' + tempPrefix + '_' + plotName + '.png'
                    if pngName not in imageDict:
                        imageFamily.addImage(pngName, experiment = experiment, line = None if commonLine == False else commonLine, creator = 'Box Pipeline', imageType = plotName)
             
            if not avisLinked:
                # Store links to the sequence AVI's.
                for seqNum in range(1, 6):
                    aviPath = '%s/%s/%s_seq%d.avi' % (experimentName, tempPrefix, shortTempPrefix, seqNum)
                    # If the AVI hasn't been replaced by an MP4 then link it in SAGE.
                    if os.path.exists(os.path.join(imageFamily.pathBase, aviPath)) and aviPath not in imageDict:
                        imageFamily.addImage(aviPath, experiment = experiment, line = tubeSession.line, creator = 'Box Pipeline', imageType = 'box_sequence_movie')
                
        if analysisVersion is not None:
            # Store links to the global plots.
            for plotName in plots[analysisVersion]:
                pdfName = experimentName + '/' + outputDirName + '/' + plotName + '.pdf'
                if pdfName not in imageDict:
                    imageFamily.addImage(pdfName, experiment = experiment, line = None if commonLine == False else commonLine, creator = 'Box Pipeline', imageType = 'comparison_summary_plot')
                pngName = experimentName + '/' + outputDirName + '/' + plotName + '.png'
                if pngName not in imageDict:
                    imageFamily.addImage(pngName, experiment = experiment, line = None if commonLine == False else commonLine, creator = 'Box Pipeline', imageType = 'comparison_summary_plot')
        
        # Make sure we don't try to link the SBFMF's and AVI's for the next "Output" folder.
        sbfmfsLinked = True
        avisLinked = True
    db.commitChanges()
    print experimentName + ' loaded successfully.'
except:
    (exceptionType, exceptionValue, exceptionTraceback) = sys.exc_info()
    print experimentName + ' failed to load: ' + str(exceptionValue)
    raise
