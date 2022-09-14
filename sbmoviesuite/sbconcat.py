#!/bin/env python
"""

concatenate a number of sbfmf files; takes all .sbfmf files in 
a directory, sorts them lexically, and concatenates them into
a single .sbfmf file

usage: sbconcat.py dirname outputfilename

existing files will be overwritten!


parts of compressfmf.py were incorporated into this file; really 
I should have written a proper set of sbfmf tools (read, write,
manipulate), but I do not currently have the time


to do:
-- version number (from overall sbmoviesuite version)


djo, 5/09

"""


# ------------------------- imports -------------------------
# std lib
import os
import struct
import sys

import numpy

# within our lib
from sbmovielib.FlyMovieFormat import FlyMovie



# ------------------------- main() -------------------------
def main():
    """
    does the conversion; this is required so the egg packaging
    system can properly unpack it when installing
    """
    
    c = sbfmfConcatenator()
    
    # end main()

# ------------------------- class sbfmfConcatenator -------------------------
class sbfmfConcatenator(object):
    """
    class for concatenating sbfmf files
    """
    # ......................... __init__ .........................
    def __init__(self):
        """
        initializer contains much of the logic, too (at least until
        I refactor it!)
        """
        
        
        print
        print "sbconcatenate.py"
        print
        
        
        # deal with input:
        if len(sys.argv) < 3:
            print "usage: sbconcat.py directory outputfilename"
            print
            sys.exit(0)
        else:
            self.dirname = sys.argv[1]
            self.outputfilename = sys.argv[2]
        
        # if output file exists, delete it before we accidentally
        #   process it!
        if os.path.exists(self.outputfilename):
            os.remove(self.outputfilename)
        
        # process input files (and sort)
        self.filenames = list(sorted(os.path.join(self.dirname, item)
            for item in os.listdir(self.dirname) if item.endswith('.sbfmf')))
        
        if not self.filenames:
            print "no files to process!"
            print
            sys.exit(0)
        
        # read metadata from all of them; compare metadat for all
        #   against that of the first movie
        self.movies = {}
        firstfn = self.filenames[0]
        for fn in self.filenames:
            self.movies[fn] = FlyMovie(fn)
            if fn != firstfn:
                movie = self.movies[fn]
                if (
                    self.nx != movie.get_width() or
                    self.ny != movie.get_height() or
                    self.difference_mode != movie.difference_mode or
                    not (self.bgcenter == movie.bgcenter).all() or
                    not (self.bgstd == movie.bgstd).all()
                    ):
                    print ("movie %s's metadata doesn't match %s's" %
                        (fn, firstfn))
                    sys.exit(0)
            else:
                # first time through, gather data from first movie
                firstmovie = self.movies[fn]
                self.nx, self.ny = firstmovie.get_width(), firstmovie.get_height()
                self.bgcenter = firstmovie.bgcenter
                self.bgstd = firstmovie.bgstd
                self.difference_mode = firstmovie.difference_mode
                # don't check version, as it's ignored; but be aware it's there...
                # version = firstmovie.version
        
        
        # new movie length; relies on cheat above
        self.nframes = sum(item.get_n_frames() for item in self.movies.values())
        
        # open file, write new header;
        print "writing new file %s with %d frames" % (self.outputfilename, self.nframes)
        self.outfile = open(self.outputfilename, 'wb')
        self.writesbfmfheader()
        
        
        # cycle over files and frames, and write frames
        
        # this is for the index pointers:
        self.framelocs = numpy.zeros(self.nframes)
        framecount = 0
        for fn in self.filenames:
            print "working on %s..." % fn
            currmovie = self.movies[fn]
            for k in range(currmovie.get_n_frames()):
                seek_to = currmovie.framelocs[k]
                # int() is needed to avoid weird 64-bit bug:
                seek_to = int(seek_to)
                currmovie.file.seek(seek_to)
                
                # read in frame data:
                format = '<Id'
                npixels, timestamp = struct.unpack(format,
                    currmovie.file.read(struct.calcsize(format)))
                indexdata = currmovie.file.read(npixels*4)
                valuedata = currmovie.file.read(npixels*1)
                
                # write out frame data:
                # record index position
                self.framelocs[framecount] = self.outfile.tell()
                
                # write number of pixels and time stamp; index data is stored
                #   as 32-bit ints, so actual # pixels is just len/4:
                n = len(indexdata) // 4
                self.outfile.write(struct.pack("<Id", n, timestamp))
                
                # and data:
                self.outfile.write(indexdata)
                self.outfile.write(valuedata)
                
                framecount += 1
        
        # write out the index, then back up and write out the
        #   index location in the header:
        
        indexloc = self.outfile.tell()
        for i in range(len(self.framelocs)):
            self.outfile.write(struct.pack("<Q",self.framelocs[i]))

        # write the location of the index
        self.outfile.seek(self.indexptrloc)
        self.outfile.write(struct.pack("<Q",indexloc))            
        
        
        # we're done!
        self.outfile.close()
        
        print "done!"
        
        # end __init__()
    
    # ......................... writesbfmfheader() .........................
    def writesbfmfheader(self):
        """
        write the header
        """
        
        # stolen heavily from compressfmf.py:
        
        # version doesn't matter, use the one I stole:
        originalversion = "0.3b"
        self.outfile.write(struct.pack("<I",len(originalversion)))
        self.outfile.write(originalversion)
        self.outfile.write(struct.pack("<4I",int(self.ny),int(self.nx),
            int(self.nframes),int(self.difference_mode)))
        
        '''
        # unneeded?
        # compute the location of the standard deviation image
        stdloc = self.outfile.tell() + struct.calcsize("<B")*self.nr*self.nc

        # compute the location of the first frame
        ffloc = stdloc + struct.calcsize("<d")*self.nr*self.nc
        '''
        
        # where do we write the location of the index -- this is always the same
        self.indexptrloc = self.outfile.tell()
        
        # write a placeholder for the index location
        self.outfile.write(struct.pack("<Q",0))
        
        # write the background image
        self.outfile.write(self.bgcenter)
        
        # write the standard deviation image
        self.outfile.write(self.bgstd)        
        
        # end writesbfmfheader()
    
    
    # end class sbfmfConcatenator



# ------------------------- script start -------------------------
if __name__ == "__main__":
    main()
