import getopt, os.path, struct, sys
import numpy as N

this_script_path = os.path.realpath(__file__)
tube_splitter_folder_path = os.path.dirname(this_script_path)
scripts_folder_path = os.path.dirname(tube_splitter_folder_path)
box_root_folder_path = os.path.dirname(scripts_folder_path)
sbmoviesuite_folder_path = os.path.join(box_root_folder_path, 'sbmoviesuite')  # used to be /misc/sc/sbmoviesuite

sys.path += [sbmoviesuite_folder_path]
from sbmovielib import movies

# Parse the command line arguments.
try:
    opts, args = getopt.getopt(sys.argv[1:], "r:b", ["roi-file=", "crop-borders"])
except getopt.GetoptError, err:
    print str(err) # will print something like "option -a not recognized"
    print 'Usage: python extract_tubes.py [-r|--roi-file file] [-b] file\n         -r  the path to a file containing regions of interest, one per line: x y w h\n         -b  crop dark borders from the left and right sides'
    sys.exit(1)
roiFile = None
cropLeftRight = False
for option, argument in opts:
    if option in ("-r", "--roi-file"):
        roiFile = argument
    elif option in ("-b", "--crop-borders"):
        cropLeftRight = True
    else:
        assert False, "unhandled option"
aviPath = args[0]

# Open the movie with the sbmoviesuite to get its metadata.
try:
    aviMovie = movies.Avi(aviPath)
except:
    print aviPath + ' does not appear to be an AVI file.'
    sys.exit(1)

# Read in the raw frame data.
aviFile = open(aviPath, 'rb')
aviHeader = aviFile.read(aviMovie.data_start)
buffer = aviFile.read((aviMovie.buf_size + 8) * aviMovie.n_frames)
aviFooter = aviFile.read()
aviFile.close()

# Create a numpy array of the data.
array = N.frombuffer(buffer, N.uint8)
del buffer
array.shape = (aviMovie.n_frames, aviMovie.buf_size + 8)

# Chop off the eight byte RIFF header of each frame.
array = array[:, 8:]

# Convert to a 3D array. (time/frame x height x width)
array.shape = (aviMovie.n_frames, aviMovie.height, aviMovie.get_width())

# To show a frame:
#import matplotlib.pyplot as pyplot
#from matplotlib import cm
#pyplot.matshow(array[0], origin = 'lower', cmap = cm.Greys_r)

# Get the boundaries of each tube.
tubeROIs = []
if roiFile:
    # Read the tube boundaries from an roiFile.  There should be one line for each tube in the file with the following fields:
    #     x y w h
    roiLines = open(roiFile)
    for roiLine in roiLines:
        x, y, w, h = [int(value) for value in roiLine.split(',')]
        tubeROIs += [(x, x + w, aviMovie.height - y, aviMovie.height - y - h)]
    roiLines.close()
else:
    leftCol = 0
    rightCol = aviMovie.width - 1
    
    # Chop off black left and right borders
    if cropLeftRight:
        colIsDark = N.average(array[0], axis = 0) < 48
        while colIsDark[leftCol]:
            leftCol += 1
        while colIsDark[rightCol]:
            rightCol -= 1
    leftCol = leftCol / 4 * 4
    rightCol = (rightCol + 3) / 4 * 4
    
    # Detect the boundaries of the tubes.
    # Grab a 16 pixel wide column at the middle of the first frame and get the average value of each row.
    # A sequence of five rows each with an average value less than 48 is considered a separation.
    midColumn = (leftCol + rightCol) / 2
    rowIsDark = N.average(array[0, :, midColumn - 8:midColumn + 8], axis = 1) < 48
    topRow = (len(rowIsDark) - 1) / 4 * 4
    for row in range(len(rowIsDark) - 1, -1, -1):
        if (row == 0 and topRow > 30) or (row < topRow - 60 and rowIsDark[row - 2] and rowIsDark[row - 1] and rowIsDark[row] and rowIsDark[row + 1] and rowIsDark[row + 2]):
            bottomRow = row / 4 * 4
            tubeROIs += [(leftCol, rightCol, topRow, bottomRow)]
            topRow = bottomRow

# Create the tube movies.
for tubeNum in range(len(tubeROIs)):
    leftCol, rightCol, topRow, bottomRow = tubeROIs[tubeNum]
    
    # Extract the frames for a tube
    newHeight = topRow - bottomRow
    newWidth = rightCol - leftCol
    tubeChunk = array[:, bottomRow:topRow, leftCol:rightCol].copy()  # must make a copy to allow modifications
    
    # Add the 8 byte RIFF frame headers
    frameSize = newHeight * newWidth
    frameHeaderHex = struct.pack('=4sL', '00db', frameSize)
    frameHeader = [ord(c) for c in frameHeaderHex]
    tubeChunk.shape = (aviMovie.n_frames, frameSize)
    tubeChunk = N.insert(tubeChunk, [0] * len(frameHeader), frameHeader, axis = 1)
    
    # Create the tube movie.
    tubePath = os.path.splitext(aviPath)[0] + '_tube' + str(tubeNum + 1) + '.avi'
    tubeFile = open(tubePath, 'wb')
    
    # Create the AVI header and footer to wrap around the frames.
    # Format from <http://msdn.microsoft.com/en-us/library/dd318189(VS.85).aspx>
    
    # Create the stream header chunk.
    streamHeader = struct.pack('=4s4sLHHLLLLLLLLHHHH', 'vids', 'DIB ', 0, 0, 0, 0, 100, 2500, 0, aviMovie.n_frames, frameSize, 0, 0, 0, 0, newWidth, newHeight)
    strhChunk = 'strh' + struct.pack('=L', len(streamHeader)) + streamHeader
    
    # Create the stream format chunk.
    bitmapInfoHeader = struct.pack('=LLLHHLLLLLL', 40, newWidth, newHeight, 1, 8, 0, frameSize, 0, 0, 256, 0)
    colorMap = ''
    for i in range(0, 256):
       colorMap += chr(i) * 3 + chr(0)
    strfChunk = 'strf' + struct.pack('=L', len(bitmapInfoHeader) + len(colorMap)) + bitmapInfoHeader + colorMap
    
    # Create the movi chunk.
    moviChunk = 'LIST' + struct.pack('=L', 4 + aviMovie.n_frames * (frameSize + 8)) + 'movi'
    
    # Create the index chunk.
    indices = ''
    for i in range(0, aviMovie.n_frames):
        indices += struct.pack('=4sLLL', '00db', 16, i * (frameSize + 8), frameSize + 8)
    idx1Chunk = struct.pack('=4sL', 'idx1', len(indices)) + indices
    
    # Create the AVI header chunk.
    aviHeaderChunk = struct.pack('=4sLLLLLLLLLLLLLLL', 'avih', 56, 40000, 6210000, 0, 2048 + 16, aviMovie.n_frames, 0, 1, frameSize, newWidth, newHeight, 0, 0, 0, 0)
    
    # Put it all together.
    strlChunk = 'LIST' + struct.pack('=L', 4 + len(strhChunk) + len(strfChunk)) + 'strl' + strhChunk + strfChunk
    hdrlChunk = 'LIST' + struct.pack('=L', 4 + len(aviHeaderChunk) + len(strlChunk)) + 'hdrl' + aviHeaderChunk + strlChunk
    riffChunk = 'RIFF' + struct.pack('=L', 4096 + N.size(tubeChunk) + len(idx1Chunk)) + 'AVI ' + hdrlChunk
    padLength = 4096 - len(riffChunk) - len(moviChunk)
    junkChunk = 'JUNK' + struct.pack('=L', padLength - 8) + chr(0) * (padLength - 8)    # padding so that first data chunk is 2K aligned
    
    # Write it all out
    tubeFile.write(riffChunk)
    tubeFile.write(junkChunk)
    tubeFile.write(moviChunk)
    tubeChunk.tofile(tubeFile)
    tubeFile.write(idx1Chunk)
    
    tubeFile.close()
    
    del tubeChunk
