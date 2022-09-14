"""

sbfmf compression routines

originally from compressfmf.py by Kristin Branson; version rec'd from
Michael Reiser on Apr 3 2008

modified by Donald J. Olbris for use in a stand-alone AVI to sbfmf 
convertor

this is a major revision; basically, rip out almost everything!
the original file was mostly GUI, wrapping a few comparitively short
compression routines; that's all I need

I needed to add a dummy file object so I could fool the compresser into
not writing output files; the file writes are too heavily 
interconnnected with the compression, and there are also seek/tell calls
on the output file


original code is GPL (v2? not actually clear), so therefore this is, too


djo, 4/08

"""


# ------------------------- imports -------------------------
import logging
import os
import struct
import sys
import time


import numpy as num

import backsub
import FlyMovieFormat
import movies 

# added by KB for window error
import scipy.ndimage.filters

# ------------------------- class DummyFile -------------------------
class DummyFile(object):
    """
    file-like object that knows enough to seek/tell, but doesn't
    actually write any data anywhere; meant to be used to fool
    the below code into thinking it's writing to a file
    
    supports:
    write
    seek/tell: it does track # characters written
    close
    
    doesn't support:
    open
    read
    """
    # ......................... __init__ .........................
    def __init__(self):
        """
        
        input:
        """
        
        # this is the file pointer
        self.loc = 0
        
        # end __init__()
    
    # ......................... close() .........................
    def close(self):
        """
        does nothing
        """
        
        pass
        
        # end close()
    
    # ......................... open() .........................
    def open(self):
        """
        doesn't support
        """
        
        raise NotImplementedError
        
        # end open()
    
    # ......................... read() .........................
    def read(self):
        """
        doesn't support
        """
        
        raise NotImplementedError
        
        # end read()
    
    # ......................... seek() .........................
    def seek(self, loc):
        """
        sets location
        """
        
        self.loc = loc
        
        # end seek()
    
    # ......................... tell() .........................
    def tell(self):
        """
        returns current file position
        """
        
        return self.loc
        
        # end tell()
    
    # ......................... write() .........................
    def write(self, message):
        """
        pretends to write a message
        """
        
        self.loc += len(message)
        
        # end write()
    
    # end class DummyFile


# ------------------------- class CompressFMF -------------------------
class CompressFMF(object):
    # ......................... __init__ .........................
    def __init__(self, params, bg=None):
        """
        input: dictionary of parameters; optional 
            background object
        """

        # housekeeping
        self.params = params
        
        
        # holder for errors
        self.error = 0
        self.maxerror = 0

        # added by KB:
        # initialize all the diagnostic statistics
        if self.params["docomputediagnostics"]:
            self.initialize_diagnostics()
        
        # these are the input parameters:
        self.infilename = params["inputfilename"]
        self.outfilename = params["outputfilename"]
        
        self.indir = os.path.dirname(self.infilename)
        self.outdir = os.path.dirname(self.outfilename)
        
        
        # open the input movie
        self.OpenInputMovie()
        
        # initialize the background model
        # I may pass this in, if I want to calculate it based
        #   on a different movie than the one we're compressing:
        if bg is None:
            self.bg = backsub.BackSub(
                movie=self.inmovie,
                n_bg_std_thresh_low=int(params["n_bg_std_thresh_low"]),
                n_bg_std_thresh_high=int(params["n_bg_std_thresh_high"]),
                est_algorithm=params["est_algorithm"],
                normalize_by=params["normalize_by"],
                difference_mode=params["difference_mode"],
                bg_nframes=int(params["bg_nframes"]),
                bg_std_min=float(params["bg_std_min"]),
                bg_std_max=float(params["bg_std_max"])
                )
        else:
            self.bg = bg
        
        # perform background estimation
        self.bg.est_bg()
        
        logging.log(15, 'Compressing...')
        logging.log(15, 'Input file: ' + self.infilename)
        logging.log(15, 'Output file: ' + self.outfilename)
        logging.log(15, 'Background model parameters:')
        logging.log(15, str(self.bg))
        
        # compress
        self.compress()
        
        # end __init__()
    
    def initialize_diagnostics(self):
        """
        initialize diagnostic statistics (added by KB)
        """

        # Did we lose any important data during compression?

        # window error is the absolute compression error 
        # integrated over small windows, the size of which is
        # set in params (params["diagnosticwindowsize"])
        self.diagnostic_windowsize = int(self.params["diagnosticwindowsize"])
        
        # number of frames we've computed diagnostics for
        self.diagnostic_nframes = 0

        # maximum window error over all windows and frames
        self.diagnostic_maxmaxwindowerror = 0
        # mean of the maximum per-frame window error
        self.diagnostic_meanmaxwindowerror = 0

        # Did we save space?

        # compression rate is the resulting file size divided by the
        # file size for the equivalent FMF
        self.diagnostic_compressionrate = 0

        # Is the background model good?
        # TODO: Continue here

        return
        
        # end initialize_diagnostics()

    def PrintUsage(self):
        print "compressfmf: Reads an FMF movie and outputs a compressed movie.\n\
              The compression scheme will only work if the background is static for\n\
              the entire movie.\n\
              Optional Command Line Arguments:\n\
              --Input=<inmovie.fmf>\n\
              --Output=<outmovie.sbfmf>\n\
              Example:\n\
              compressfmf --Input=movie1.fmf --Output=movie1.sbfmf \n\
              If input is movie1.fmf then output is set to movie1.sbfmf\n\
              "
    
    def OpenInputMovie(self):
        basename, ext = os.path.splitext(self.infilename)
        
        if ext == ".avi":
            self.inmovie = movies.Avi(self.infilename, fmfmode=True)
            #self.inmovie = movies.Avi(self.infilename, fmfmode=False)
        elif ext == ".fmf" or ext == ".sbfmf":
            self.inmovie = FlyMovieFormat.FlyMovie(self.infilename)
        else:
            raise ValueError("unknown format %s" % ext)
        
        self.nr = self.inmovie.get_height()
        self.nc = self.inmovie.get_width()
        self.nframes = self.inmovie.get_n_frames()
        self.currframe = 0

        # added by KB:
        # allocate space for temporary structures
        if self.params["docomputediagnostics"]:
            self.allocate_diagnostics()
        
        # end OpenInputMovie()
    
    def read_frame(self):
        self.im, self.stamp = self.inmovie.get_frame(self.currframe)
    
    def read_next_frame(self):
        self.im, self.stamp = self.inmovie.get_next_frame()
    
    def compress(self):
        """
        Writes the compressed file.
        """
        
        self.starttime = time.time()
        
        nframescompress = self.nframes
        self.framestarts = num.zeros(nframescompress)

        # open the output file; use a dummy if we aren't writing files
        if self.params["writefiles"]:
            self.outfile = open(self.outfilename,'wb')
        else:
            self.outfile = DummyFile()

        # seek to the first frame of the input file
        self.inmovie.seek(self.bg.startframe)

        # write the header
        self.write_header()

        # write the frames
        for self.currframe in range(self.nframes):
            if ((self.currframe - self.bg.startframe) % 25) == 0:
                logging.log(15, 'Frame %d / %d' % (self.currframe - self.bg.startframe, nframescompress))
            self.write_frame()

        # write the index
        self.write_index()

        # close the file
        self.outfile.close()
        
        self.endtime = time.time()

    def write_header(self):
        """
        Writes the header for the file. Format:
        Number of bytes in version string: (I = unsigned int)
        Version Number (string of specified length)
        Number of rows (I = unsigned int)
        Number of columns (I = unsigned int)
        Number of frames (I = unsigned int)
        Difference mode (I = unsigned int):
          0 if light flies on dark background, unsigned mode
          1 if dark flies on light background, unsigned mode
          2 if other, signed mode
        Location of index (Q = unsigned long long)
        Background image (ncols * nrows * double)
        Standard deviation image (ncols * nrows * double)
        """
        # write the number of columns, rows, frames, difference mode
        if self.bg.difference_mode == 'Light on Dark':
            difference_mode = 0
        elif self.bg.difference_mode == 'Dark on Light':
            difference_mode = 1
        else:
            difference_mode = 2
        # version seems to be ignored by the version of FlyMovieFormat.py 
        #   I use (for sbfmf); I wrote my version instead of theirs for
        #   a while, but now I write 0.3b, which is version corresponding
        #   to the code I stole from
        originalversion = "0.3b"
        self.outfile.write(struct.pack("<I",len(originalversion)))
        self.outfile.write(originalversion)
        nframescompress = min(self.bg.endframe,self.nframes-1) - self.bg.startframe + 1
        self.outfile.write(struct.pack("<4I",int(self.nr),int(self.nc),
                                       int(nframescompress),int(difference_mode)))

        # compute the location of the standard deviation image
        stdloc = self.outfile.tell() + struct.calcsize("<B")*self.nr*self.nc

        # compute the location of the first frame
        ffloc = stdloc + struct.calcsize("<d")*self.nr*self.nc

        # where do we write the location of the index -- this is always the same
        self.indexptrloc = self.outfile.tell()

        # write a placeholder for the index location
        self.outfile.write(struct.pack("<Q",0))

        # write the background image
        self.outfile.write(self.bg.center)

        # write the standard deviation image
        self.outfile.write(self.bg.dev)

    def allocate_diagnostics(self):
        """
        allocate space for temporary variables used when computing diagnostics (added by KB)
        """

        # when fmfmode is true, we must flip these
        self.diagnostic_windowerror = num.zeros((self.nc,self.nr))

        # we now know the size of the image, so compute the header,
        # index size:        
        # background mean, std each take nr*nc
        # index takes nframes*8
        self.diagnostic_compressionrate = \
            self.nr*self.nc*2 + \
            self.inmovie.get_n_frames() * 8

        return

        # end allocate_diagnostics

    def write_frame(self):
        """
        Writes the current frame to file. Format for the current frame:
        Number of foreground pixels (I=unsigned int)
        Pixel 1 index ... Pixel n index (I=unsigned int)
        Pixel 1 intensity ... Pixel n intensity (c=char)
        """

        # compute the difference from the background image
        self.read_next_frame()
        self.bg.sub_bg(self.im.astype(float))
        
        # calculate some statistics
        # we need to construct the effective stored array 
        #   in order to calculate the error:
        stored = num.where(self.bg.isfore, self.im, self.bg.center)

        # TO WATCH: if stored and self.im are uint8, this is dangerous
        imerror = self.im - stored
        num.power(imerror, 2, imerror)
        self.error += imerror.mean()
        self.maxerror = max(self.maxerror, imerror.max())
                
        # locations of foreground pixels
        tmp = self.bg.isfore.copy()
        tmp.shape = (self.nr * self.nc,)
        i, = num.nonzero(tmp)

        # values at foreground pixels
        v = self.im[self.bg.isfore]

        # number of foreground pixels
        n = len(i)
        
        # added by KB:
        # calculate some more diagnostic statistics
        if self.params["docomputediagnostics"]:
            self.compute_diagnostics_frame(imerror,n)

        # store the start of this frame
        self.framestarts[self.currframe-self.bg.startframe] = self.outfile.tell()
        
        # write number of pixels and time stamp
        self.outfile.write(struct.pack("<Id", n, self.stamp))
        
        i = i.astype(num.uint32)
        
        self.outfile.write(i)
        self.outfile.write(v)
        
        # end write_frame()
       
    def compute_diagnostics_frame(self,imerror=None,n=None):
        """
        Compute per-frame diagnostics (added by KB)
        
        Inputs:

        imerror: squared difference between compressed and true
        current frame. This is an optional input, and by default
        is None. If it is None, then we read in the next frame
        and compute the squared compression error. We also 
        update the meanerror and maxerror statistics. 
        n: number of pixels stored in the current frame. 
        This is an optional input, and by default
        is None. It is assumed to be None iff imerror is None.
        If it is None, then we compute n. 

        """

        # stuff that is done in write_frame
        # we may want to compute diagnostics without writing
        if imerror is None:

            self.read_next_frame()
            self.bg.sub_bg(self.im.astype(float))
            
            # calculate some statistics
            # we need to construct the effective stored array 
            #   in order to calculate the error:
            stored = num.where(self.bg.isfore, self.im, self.bg.center)
            imerror = self.im - stored
            num.power(imerror, 2, imerror)
            self.error += imerror.mean()
            self.maxerror = max(self.maxerror, imerror.max())

            # locations of foreground pixels
            n = len(num.nonzero(self.bg.isfore))

        # how many frames we've computed diagnostics for 
        # only really nec for debugging
        self.diagnostic_nframes += 1

        # integrate the per-pixel error over windows
        scipy.ndimage.filters.uniform_filter(imerror, 
                                             size=self.diagnostic_windowsize,
                                             output=self.diagnostic_windowerror,
                                             mode='constant', cval=0)
        # To think about: should we be integrating absolute error
        # instead of squared error?
        
        # compute the maximum window error for this frame
        maxwindowerror = num.max(self.diagnostic_windowerror)
    
        # add to the mean, max statistics
        self.diagnostic_meanmaxwindowerror += maxwindowerror
        self.diagnostic_maxmaxwindowerror = max(self.diagnostic_maxmaxwindowerror,maxwindowerror)

        # compression rate: add in the size of this frame 
        # (ignore some header stuff)
        self.diagnostic_compressionrate += 4+n*(4*2+1)

        #print "diagnostics: "
        #print str(self.getdiagnostics())

        # TODO: we should add more statistics here
        
        # end compute_diagnostics_frame
 
    def write_index(self):
        """
        Writes the index at the end of the file. Index consists of nframes unsigned long longs (Q),
        indicating the positions of each frame
        """
        # write the index
        indexloc = self.outfile.tell()
        for i in range(len(self.framestarts)):
            self.outfile.write(struct.pack("<Q",self.framestarts[i]))

        # write the location of the index
        self.outfile.seek(self.indexptrloc)
        self.outfile.write(struct.pack("<Q",indexloc))            
    
    # ......................... geterror() .........................
    def geterror(self):
        """
        returns error if it's been calculated; returns (0, 0)
        if the compression hasn't occured yet
            
        input: none
        output: (mean square error, max squared error)
        """
        
        return (self.error / self.inmovie.get_n_frames(), self.maxerror)
        
        # end geterror()

    def getdiagnostics(self):
        """
        returns all diagnostics computed (added by KB)
        
        input: none
        output: dict diagnostics with fields:
        "error": mean squared compression error over all pixels and frames
        "maxerror": max over all frames of the per-frame mean squared error
        "meanmaxwindowerror": mean over all frames of the per-frame maximum squared window compression error
        "maxmaxwindowerror": maximum squared window compression error
        "compressionrate": the size of the sbfmf file divided by the size of the corresponding fmf file
        """

        # if we're not computing diagnostics, return empty tuple
        if not self.params["docomputediagnostics"]:
            return ()

        # make a tuple of all diagnostics
        diagnostics = dict()
        diagnostics["error"] = self.error / self.inmovie.get_n_frames()
        diagnostics["maxerror"] = self.maxerror
        diagnostics["meanmaxwindowerror"] = self.diagnostic_meanmaxwindowerror / self.diagnostic_nframes
        diagnostics["maxmaxwindowerror"] = self.diagnostic_maxmaxwindowerror

        # approximate the fmf size (ignoring header stuff)
        fmfsz = self.nr*self.nc*self.diagnostic_nframes
        # compression rate
        diagnostics["compressionrate"] = float(self.diagnostic_compressionrate) / float(fmfsz)

        return diagnostics

        # end getdiagnostics()
    
    # ......................... gettime() .........................
    def gettime(self):
        """
        input: none
        output: (total running time, fps)
        """
        
        totaltime = self.endtime - self.starttime
        
        return totaltime, self.inmovie.get_n_frames() / totaltime
        
        # end gettime()
    
    def docomputediagnostics(self):
        return self.params["docomputediagnostics"]
    
    # end class CompressFMF


