import sage
import os.path, sys
import subprocess as sub

if len(sys.argv) < 2:
    print 'Usage:\n\tupdate_box_imagery <experiment path>'
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
    
    imageFamily = sage.ImageFamily(db, 'fly_olympiad_box', 'http://img.int.janelia.org/flyolympiad-data/fly_olympiad_box/', dataDir + '/', olympiadLab)
    
    # Check which images have been linked.
    images = imageFamily.findImages(experiment)
    for image in images:
        if image.name.endswith('.avi'):
            # Update the links to the sequence AVI's to point to the MP4's.
            mp4Path = image.name[0:-3] + 'mp4'
            imageFamily.updateImage(image, mp4Path, line = image.line, experiment = experiment, isRepresentative = image.isRepresentative, display = image.display, creator = image.creator, imageType = 'box_sequence_movie')
    
    db.commitChanges()
    print experimentName + ' imagery updated successfully.'
except:
    (exceptionType, exceptionValue, exceptionTraceback) = sys.exc_info()
    print experimentName + ' imagery failed to update: ' + str(exceptionValue)
    raise
