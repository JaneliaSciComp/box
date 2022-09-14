import sbmovielib.FlyMovieFormat as FlyMovieFormat
import sbmovielib.movies as movies
import sbconvert
import sys
import optparse
import os.path
import numpy as num
from sbmovielib.version import __version__
from sbmovielib import util
import scipy.ndimage.filters
import logging
import time

class ComputeDiagnostics:

    def __init__(self,params,sbfmffilename):

        self.params = params
        self.sbfmffilename = sbfmffilename

        # look for avi with the same base name
        [path,name] = os.path.split(sbfmffilename)
        [name,ext] = os.path.splitext(name)
        avifilename = os.path.join(path,name+".avi")
        if not os.path.exists(avifilename):
            print "avifile %s corresponding to %s does not exist, skipping"%(avifilename,sbfmffilename)

        self.sbfmfmovie = FlyMovieFormat.FlyMovie(sbfmffilename)
        self.avimovie = movies.Avi(avifilename,fmfmode=False)

        self.nframes = min(self.sbfmfmovie.get_n_frames(),self.avimovie.get_n_frames)
        self.nr = self.sbfmfmovie.get_height()
        self.nc = self.sbfmfmovie.get_width()

        self.initialize_diagnostics()
        self.allocate_diagnostics()

        return

    # end __init__

    def initialize_diagnostics(self):

        """
        initialize diagnostic statistics (added by KB)
        """

        # stuff already in compressfmf
        self.error = 0
        self.maxerror = 0

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

    def allocate_diagnostics(self):
        """
        allocate space for temporary variables used when computing diagnostics (added by KB)
        """

        self.diagnostic_windowerror = num.zeros((self.nr,self.nc))

        # we now know the size of the image, so compute the header,
        # index size:        
        # background mean, std each take nr*nc
        # index takes nframes*8
        self.diagnostic_compressionrate = \
            self.nr*self.nc*2 + \
            self.nframes * 8

        return

    # end allocate_diagnostics

    def compute_diagnostics(self):

        self.sbfmfmovie.seek(0)
        self.avimovie.seek(0)

        for i in range(self.nframes):

            self.compute_diagnostics_frame()
            print str(self.getdiagnostics())

    def compute_diagnostics_frame(self):

        (sbfmfframe,sbfmftimestamp) = self.sbfmfmovie.get_next_frame()
        (aviframe,avitimestamp) = self.avimovie.get_next_frame()

        # this is okay cuz sbfmfframe is a float
        imerror = sbfmfframe - aviframe
        # this may be dangerous, since these are both uint8s. 
        # trying to do the same thing as compressfmf
        num.power(imerror, 2, imerror)

        self.error += imerror.mean()
        self.maxerror = max(self.maxerror, imerror.max())
        # locations of foreground pixels
        n = self.sbfmfmovie.sbfmf_npixels

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
        diagnostics["error"] = self.error / self.nframes
        diagnostics["maxerror"] = self.maxerror
        diagnostics["meanmaxwindowerror"] = self.diagnostic_meanmaxwindowerror / self.diagnostic_nframes
        diagnostics["maxmaxwindowerror"] = self.diagnostic_maxmaxwindowerror

        # approximate the fmf size (ignoring header stuff)
        fmfsz = self.nr*self.nc*self.diagnostic_nframes
        # compression rate
        diagnostics["compressionrate"] = float(self.diagnostic_compressionrate) / float(fmfsz)

        return diagnostics

        # end getdiagnostics()

    def finish(self):

        diagnostics = self.getdiagnostics()
        self.sbfmfmovie.close()
        self.avimovie.close()

        # in principle, multiple instances could try to write to the
        #   summary file at once; in the absence of a dead-easy 
        #   cross-platform locking solution, I'll just put a 
        #   try clause to catch any utter failures; the info is
        #   written to the log file and std out anyway
        newsummary = not os.path.exists(self.params["summaryfile"])
        f = open(self.params["summaryfile"], 'a')
        if newsummary:
            # write heading line
            f.write("date\t  time\tfile\t\tnframes\t\tmean errror\tmax error\t\tmean window error\t\tmax window error\t\tcompression rate\n")

        # write the data line
        f.write("%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\n" % (time.strftime("%d %b %y %H:%M"),
                                                  self.sbfmffilename, self.nframes, diagnostics["error"], diagnostics["maxerror"], diagnostics["meanmaxwindowerror"], diagnostics["maxmaxwindowerror"], diagnostics["compressionrate"]))
        f.close()
    
def main():

    # use optparse module for command-line options:
    usage = "usage: %prog [options]"
    parser = optparse.OptionParser(usage=usage, version="%%prog %s" % __version__)
    parser.add_option("-p", "--pfile", dest="pfilename", default=util.defaultpfilename, 
                      help="optional parameter file name")
    parser.add_option("-d", action="store_true", dest="debug",
                      default=False, help="set all logging output to debug level (very verbose)")
    (options, args) = parser.parse_args()

    # read parameters
    params = sbconvert.readparams(options)

    if not params["docomputediagnostics"]:
        print "docomputediagnostics being set to True, even though False in parameters"
        params["docomputediagnostics"] = True
    
    if params["writefiles"]:
        print "writefiles being set to False, even though True in parameters"
        params["writefiles"] = False    

    if params["overwrite"]:
        print "overwrite being set to False, even though True in parameters"
        params["overwrite"] = False    

    if not params["convert"]:
        print "convert being set to True, even though False in parameters"
        params["convert"] = True

    # start logging (screen and/or file)
    sbconvert.startlogging(options, params)

    if not args:
        # if no filenames, go through current dir for candidates
        args = os.listdir('.')

    print "args = " + str(args)

    for arg in args:
        
        [name,ext] = os.path.splitext(arg)
        if ext == ".sbfmf":

            # set summaryfile to be in destination directory
            [summarypath,summaryname] = os.path.split(params["summaryfile"])
            [sbfmfpath,sbfmfname] = os.path.split(arg)
            params["summaryfile"] = os.path.join(sbfmfpath,summaryname)

            computer = ComputeDiagnostics(params,arg)
            computer.compute_diagnostics()
            diagnostics = computer.getdiagnostics()
            logging.info("diagnostics for %s:\n"%arg + str(diagnostics))
            computer.finish()

    return 0

# ------------------------- script start -------------------------
if __name__ == "__main__":
    main()

