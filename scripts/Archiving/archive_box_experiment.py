# 

import sage
import os.path, sys, shutil, glob
import subprocess as sub

if len(sys.argv) < 2:
    print 'Usage:\n\tarchive_box_experiment <experiment path>'
    sys.exit(-1)

def pipelineSetting(settingName):
    # Lookup the setting using the pipeline_settings.pl tool in the Tools directory near this script.
    toolPath = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(sys.argv[0]))), 'Tools', 'pipeline_settings.pl')
    p = sub.Popen([toolPath, settingName], stdout=sub.PIPE, stderr=sub.PIPE)
    output, errors = p.communicate()
    if p.returncode != 0:
        raise ValueError('Could not look up the \'' + settingName + '\' pipeline setting.')
    else:
        return output.strip()

experimentPath = sys.argv[1]
experimentName = os.path.basename(experimentPath)

sageEnv = pipelineSetting('sage_env')

try:
    # Make sure the directory really exists.
    if not os.path.exists(experimentPath):
        raise IOError, 'No experiment directory found at ' + experimentPath
    
    # Connect to SAGE and get the CV's we'll need to use.
    db = sage.Connection(paramsPath = '/groups/flyprojects/home/olympiad/config/SAGE-' + sageEnv + '.config')
    flyCV = sage.CV('fly')
    boxCV = sage.CV('fly_olympiad_box')
    olympiadCV = sage.CV('fly_olympiad')
    qcCV = sage.CV('fly_olympiad_qc')
    olympiadLab = sage.Lab('olympiad')
    
    # Make sure the experiment exists in SAGE.
    experiments = db.findExperiments(name = experimentName, typeTerm = boxCV.term('box'), lab = olympiadLab)
    if len(experiments) == 0:
        raise ValueError, 'Could not find the \'' + experimentName + '\' experiment in SAGE.' 
    experiment = experiments[0]
    
    # Check if it's OK to archive.
    if experiment.getProperty(qcCV.term('manual_pf')) == 'F':
        pass    # The user already flagged the experiment as failed.  Don't archive but there's no need to generate a ticket.
    elif experiment.getProperty(qcCV.term('automated_pf')) != 'P':
        # The experiment failed at some previous stage in the pipeline.
        raise ValueError, 'The experiment did not make it through the pipeline successfully, no archiving will be done.'
    elif not os.path.exists(os.path.join(experimentPath, pipelineSetting('output_dir_name'), 'comparison_summary.pdf')):
        # The experiment failed at some previous stage in the pipeline.
        raise ValueError, 'The experiment''s comparison summary PDF was not generated, no archiving will be done.'
    else:
        # It's OK to archive the experiment.
        archiveBehavior = experiment.getProperty(flyCV.term('archive_behavior'))
        if archiveBehavior is None or archiveBehavior == 'default':
            pass
        else:
            # The experiment should be archived.
            archiveDir = experiment.getProperty(flyCV.term('archive_path'))
            if not os.path.exists(archiveDir):
                raise ValueError, 'Could not find the archive location for \'' + experimentName + '\''
            
            destPath = os.path.join(archiveDir, experimentName)
            
            if archiveBehavior == 'move':
                # Move the experiment to the non-Olympiad archive space
                print 'Moving \'' + experimentName + '\' to ' + archiveDir + '...'
                shutil.move(experimentPath, archiveDir)
                os.symlink(destPath, experimentPath)
                experiment.setProperty(olympiadCV.term('archived'), True)
            elif archiveBehavior == 'copy':
                # Copy the experiment to the non-Olympiad archive space.
                # Make sure to resolve sym. links so the content isn't lost.
                # (In one shell test this took 4.5 minutes.)
                print 'Copying \'' + experimentName + '\' to ' + archiveDir + '...'
                shutil.copytree(experimentPath, destPath, symlinks = True)
                experiment.setProperty(olympiadCV.term('archived'), True)
            elif archiveBehavior == 'copy_and_remove_sbfmf':
                print 'Copying \'' + experimentName + '\' to ' + archiveDir + '...'
                shutil.copytree(experimentPath, destPath, symlinks = True)
                print 'Removing SBFMF\'s...'
                sbfmfPaths = glob.glob(os.path.join(experimentPath, '*', '*_sbfmf'))
                for sbfmfPath in sbfmfPaths:
                    shutil.rmtree(sbfmfPath)
                experiment.setProperty(olympiadCV.term('archived'), True)
            else:
                raise ValueError, 'Unknown behavior action: ' + archiveBehavior
        
        print '\'' + experimentName + '\' archiving complete.'
except:
    (exceptionType, exceptionValue, exceptionTraceback) = sys.exc_info()
    print experimentName + ' failed to archive: ' + str(exceptionValue)
    raise
