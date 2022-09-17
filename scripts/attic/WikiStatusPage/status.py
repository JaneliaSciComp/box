import getopt, os, os.path, re, sys
import myglob as glob
import wikilib
import wikiconfig

exit

try:
    options, directories = getopt.getopt(sys.argv[1:], 'dp:')
except getopt.GetoptError, err:
    print >> sys.stderr, str(err)
    print >> sys.stderr, 'Usage: python status.py [-d] folder1 [folder2 ... [folderN]] > Status.csv\n    -d = include directory name column'
    sys.exit(2)

includeDirName = False
pageID = None

for opt, arg in options:
	if opt == '-d':
		includeDirName = True
	elif opt == '-p':
		pageID = arg
		contents = ''

# Generate the header
if pageID is None:
	if includeDirName:
		print 'Directory\t',
	print 'Line\tRun Date/Time\tBox\t# Split\t# SBFMF\t# Tracked\tMerged\tAnalyzed'
else:
	if includeDirName:
		contents = 'Directory\t'
	contents += 'Line\tRun Date/Time\tBox\t# Split\t# SBFMF\t# Tracked\tMerged\tAnalyzed\n'

for dirPath in directories:
    if not os.path.exists(dirPath):
        raise ValueError, 'The directory \'' + dirPath + '\' does not exist.'
    dirName = '' if not includeDirName else os.path.basename(dirPath) + '\t'
    for experimentName in sorted(os.listdir(dirPath)):
        match = re.match(r'(.*)_([A-Za-z]+)_([0-9]{4})([0-9]{2})([0-9]{2})T([0-9]{2})([0-9]{2})([0-9]{2})$', experimentName)
        if match:
            line, boxName, year, month, day, hours, minutes, seconds = match.groups()
            experimentPath = os.path.join(dirPath, experimentName)
            if os.path.isdir(experimentPath):
                numSplit = len(glob.glob(os.path.join(experimentPath, '[0-9]*_[0-9.]*_[0-9]*', '[0-9]*_[0-9.]*_seq[0-9]*_tube[0-9]*.avi')))
                numSbfmf = len(glob.glob(os.path.join(experimentPath, '[0-9]*_[0-9.]*_[0-9]*', '[0-9]*_[0-9.]*_tube[0-9]_sbfmf', '[0-9]*_[0-9.]*_seq[0-9]*_tube[0-9].sbfmf')))
                numTracked = len(glob.glob(os.path.join(experimentPath, 'Output', '[0-9]*_[0-9.]*_[0-9]*', '[0-9]*_[0-9.]*_seq[0-9]*_tube[0-9]*', 'analysis_info.mat')))
                merged = len(glob.glob(os.path.join(experimentPath, 'Output', 'success*.mat')))
                analyzed = os.path.exists(os.path.join(experimentPath, 'comparison_summary.pdf'))
                line = '%s%s\t%s/%s/%s %s:%s:%s\t%s\t%d\t%d\t%d\t%s\t%s' % (dirName, line, year, month, day, hours, minutes, seconds, boxName, numSplit, numSbfmf, numTracked, 'Y' if merged else 'N', 'Y' if analyzed else 'N')
                if pageID is None:
                	print line
                else:
                	contents += line + '\n'

if pageID is not None:
	# Attach the status to the indicated wiki page...
	wiki = wikilib.wikiproxy(wikilib.productionwikiurl, wikiconfig.username, wikiconfig.password)
	result = wiki.addattachment(pageID, contents, filename='Status.csv', mimetype='text/csv')
	if not isinstance(result, dict) or not 'id' in result:
   		print >> sys.stderr, 'Could not attach status to page:\n' + str(result)
		sys.exit(1)
