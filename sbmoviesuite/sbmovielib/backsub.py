"""

backsub routines

originally from backsup.py by Kristin Branson; version rec'd from
her on 16 Apr 08

modified by Donald J. Olbris for use in a stand-alone AVI to sbfmf 
convertor

changes:
-- removed unneeded FlyMovieFormat import
-- comment out all print statements

original code is GPL (2?), so therefore this is, too

djo, 4/08

"""

import numpy as num
import scipy.ndimage.morphology as morph
# import motmot.FlyMovieFormat as fmf

class BackSub:

    def __init__(self,movie=None,
                 n_bg_std_thresh_low=10,n_bg_std_thresh_high=20,
                 est_algorithm='Median',normalize_by='Standard Deviation',
                 difference_mode='Light on Dark',
                 bg_nframes=100,bg_mask=None,
                 startframe=0,endframe=num.inf,
                 bg_std_min=1.,bg_std_max=10.):
        """        Background estimation and subtraction routines.
        Inputs:
        movie: FlyMovie
        n_bg_std_thresh_low: lower threshold for background subtraction
        n_bg_std_thresh_high [-1]: higher threshold for background subtraction.
          if less than n_bg_std_thresh_low, then hysteresis is not used
        est_algorithm ['Median']: algorithm for computing the background model
          Possible values: 'Median', 'Mean'
        normalize_by ['Std']: what to normalize image by
          Possible values: 'Std', 'Brightness'
        difference_mode ['Other']: Whether we care about positive differences
          from the background, negative differences from the background, or
          both
          Possible values: 'LightOnDark', 'DarkOnLight', 'Other'
        bg_nframes [100]: Number of frames from which to estimate the background
          model
        bg_mask [None]: Pixels that are always classified as background.
        """

        # get some info about the movie
        self.movie = movie
        if movie is None:
            self.nr = 0
            self.nc = 0
            self.nframes = 0
        else:
            self.nr = self.movie.get_height()
            self.nc = self.movie.get_width()
            self.nframes = self.movie.get_n_frames()

        # mask of pixels that are always background
        if bg_mask is None:
            self.bg_mask = num.zeros((self.nr,self.nc),dtype=num.bool)
        else:
            self.bg_mask = bg_mask

        self.n_bg_std_thresh_low = n_bg_std_thresh_low
        self.n_bg_std_thresh_high = n_bg_std_thresh_high
        self.est_algorithm = est_algorithm
        self.normalize_by = normalize_by
        self.difference_mode = difference_mode
        self.bg_nframes = bg_nframes
        self.startframe = max(0,startframe)
        self.endframe = endframe
        self.bg_std_min = bg_std_min
        self.bg_std_max = bg_std_max
            
    def meanstd( self ):
        """
        Compute the background image and deviation as the mean and
        standard deviation.
        """

        if self.movie is None:
            return

        # we will estimate background from evenly spaced frames between
        # startframe and endframe
        bg_nframes = min(self.nframes,self.bg_nframes)
        endframe = min(self.endframe,self.nframes-1)
        nframes = endframe - self.startframe + 1
        nframesskip = int(num.floor(nframes/bg_nframes))

        # initialize mean and std to 0
        self.mean = num.zeros((self.nr,self.nc))
        self.std = num.zeros((self.nr,self.nc))

        # main computation
        for i in range(self.startframe,endframe+1,nframesskip):
            # read in the data
            im, stamp = self.movie.get_frame( int(i) )
            im = im.astype( num.float )
            # add to the mean
            self.mean += im
            # add to the variance
            self.std += im**2

        # normalize
        self.mean /= num.double(bg_nframes)
        self.std /= num.double(bg_nframes)
        # actually compute variance, std
        self.std = num.sqrt(self.std - self.mean**2)

    def medmad( self ):

        if self.movie is None:
            return

        # shortcut names for oft-used values
        fp = self.movie.file

        # we will estimate background from evenly spaced frames between
        # startframe and endframe
        bg_nframes = min(self.nframes,self.bg_nframes)
        endframe = min(self.endframe,self.nframes-1)
        nframes = endframe - self.startframe + 1
        nframesskip = int(num.floor(nframes/bg_nframes))

        # sizes of stuff
        bytesperchunk = self.movie.bytes_per_chunk
        
        # not sure why this is here, but I'm silencing it (djo) 
        # if num.mod(self.movie.bits_per_pixel,8) != 0:
        #     print "Not sure what will happen if bytesperpixel is non-integer!!"
        
        bytesperpixel = self.movie.bits_per_pixel/8.
        headersize = self.movie.chunk_start+self.movie.timestamp_len
        framesize = self.nr*self.nc
        nbytes = num.int(self.nr*self.nc*bytesperpixel)

        # which frame is the middle frame for computing the median?
        iseven = num.mod(bg_nframes,2) == 0
        middle1 = num.int(num.floor(bg_nframes/2))
        print "middle1: %s" % repr(middle1)
        middle2 = middle1-1

        # number of rows to read in at a time; based on the assumption 
        # that we comfortably hold 100*(400x400) frames in memory. 
        nrsmall = num.int(num.floor(100.0*400.0*400.0/num.double(self.nc)/num.double(bg_nframes)))
        if nrsmall < 1:
            nrsmall = 1
        if nrsmall > self.nr:
            nrsmall = self.nr
        # number of rows left in the last iteration might be less than nrsmall 
        nrsmalllast = num.mod(self.nr, nrsmall)
        # if evenly divides,  set last number of rows to nrsmall
        if nrsmalllast == 0:
            nrsmalllast = nrsmall
        # number of pixels corresponding to nrsmall rows
        nbytessmall = num.int(nrsmall*self.nc*bytesperpixel)
        # number of pixels corresponding to nrsmalllast rows
        nbytessmalllast = num.int(nrsmalllast*self.nc*bytesperpixel)
        # buffer holds the pixels for each frame that are read in. 
        # it holds npixelssmall for each frame of nframes 
        buffersize = nbytessmall*bg_nframes
        # after we read in npixelssmall for a frame, we must seek forward
        # seekperframe 
        seekperframe = bytesperchunk*nframesskip-nbytessmall
        # in the last iteration, we only read in npixelssmalllast, so we
        # need to seek forward more
        seekperframelast = bytesperchunk*nframesskip-nbytessmalllast

        # allocate memory for median and mad
        self.med = num.zeros(framesize)
        self.mad = num.zeros(framesize)

        for imageoffset in range(0,nbytes,nbytessmall):
            
            # print "image offset = %d."%imageoffset

            # if this is the last iteration, there may not be npixelssmall left
            # store in npixelscurr the number of pixels that are to be read in,
            # store in seekperframecurr the amount to seek after reading.
            imageoffsetnext = imageoffset+nbytessmall
            if imageoffsetnext > nbytes:
                nbytescurr = nbytessmalllast
                seekperframecurr = seekperframelast
                imageoffsetnext = nbytes
            else:
                nbytescurr = nbytessmall
                seekperframecurr = seekperframe

            # allocate memory for buffer that holds data read in in current pass
            buf = num.zeros((bg_nframes,nbytescurr),dtype=num.uint8)

            # seek to pixel imageoffset of the first frame
            fp.seek(imageoffset+headersize+self.startframe*bytesperchunk,0)

            # print 'Reading ...'

            # loop through frames
            for i in range(bg_nframes):

                # seek to the desired part of the movie; 
                # skip bytesperchunk - the amount we read in in the last frame 
                if i > 0:
                    fp.seek(seekperframecurr,1)
                
                # read nrsmall rows
                data = fp.read(nbytescurr)
                if data == '':
                    raise NoMoreFramesException('EOF')
                buf[i,:] = num.fromstring(data,num.uint8)

            # compute the median and median absolute difference at each 
            # pixel location
            # print 'Computing ...'
            # sort all the histories to get the median
            buf = buf.transpose()
            buf.sort(axis=1,kind='mergesort')
            # store the median
            self.med[imageoffset:imageoffsetnext] = buf[:,middle1]
            if iseven:
                self.med[imageoffset:imageoffsetnext] += buf[:,middle2]
                self.med[imageoffset:imageoffsetnext] /= 2.
                
            # store the absolute difference
            buf = num.double(buf)
            for j in range(bg_nframes):
                buf[:,j] = num.abs(buf[:,j] - self.med[imageoffset:imageoffsetnext])

            # sort
            buf.sort(axis=1,kind='mergesort')

            # store the median absolute difference
            self.mad[imageoffset:imageoffsetnext] = buf[:,middle1]
            if iseven:
                self.mad[imageoffset:imageoffsetnext] += buf[:,middle2]
                self.mad[imageoffset:imageoffsetnext] /= 2.

            #self.mad[imageoffset:imageoffsetnext] = buf[:,madorder1]*madweight1 + \
            #                                        buf[:,madorder2]*madweight2

        # estimate standard deviation assuming a Gaussian distribution
        # from the fact that half the data falls within mad
        # MADTOSTDFACTOR = 1./norminv(.75)
        MADTOSTDFACTOR = 1.482602
        self.mad *= MADTOSTDFACTOR
        
        self.mad.shape = [self.nr,self.nc]
        self.med.shape = [self.nr,self.nc]

    def est_bg(self):

        if self.movie is None:
            return

        # make sure number of background frames is at most number of frames in movie
        oldbg_nframes = self.bg_nframes
        self.bg_nframes = min(self.bg_nframes,self.nframes)

        if self.isuptodate():
            return

        if self.est_algorithm == 'Median':
            self.medmad()
            self.center = self.med.copy()
        else:
            self.meanstd()
            self.center = self.mean.copy()

        self.set_dev()

        self.bg_nframes = oldbg_nframes

        self.store_last_computed()

    def store_last_computed(self):

        self._last_bg_nframes = min(self.nframes,self.bg_nframes)
        self._last_est_algorithm = self.est_algorithm
        self._last_startframe = self.startframe
        self._last_endframe = min(self.endframe,self.nframes-1)

    def isuptodate(self):

        # haven't computed yet
        if not self.iscomputed():
            return False

        return (self._last_startframe == self.startframe) and \
               (self._last_endframe == min(self.endframe,self.nframes-1)) and \
               (self._last_est_algorithm == self.est_algorithm) and \
               (self._last_bg_nframes == min(self.bg_nframes,self.nframes))

    def iscomputed(self):
        return hasattr(self,'_last_startframe')

    def sub_bg(self,im):

        if self.movie is None:
            return

        if self.difference_mode == 'Light on Dark':
            self.dfore = im - self.center
            self.dfore[self.dfore<0] = 0
        elif self.difference_mode == 'Dark on Light':
            self.dfore = self.center - im
            self.dfore[self.dfore<0] = 0
        else:
            self.dfore = num.zeros(im.shape)
            self.dfore = num.maximum(im-self.center,self.center-im)

        self.isfore = self.dfore > self.thresh_low
        if self.n_bg_std_thresh_high > self.n_bg_std_thresh_low:
            bwhigh = self.dfore > self.thresh_high
            self.isfore = morph.binary_propagation(self.dfore>self.thresh_high,
                                                   mask=self.isfore
)
        self.isfore[self.bg_mask] = False
                    
    def get_sub_bg(self,im):

        if self.movie is None:
            return
        sub_bg(im)
        return(self.dfore,self.isfore)
        
    def get_bg_center(self):
        if self.movie is None:
            return None
        return self.center

    def get_bg_dev(self):
        if self.movie is None:
            return None
        return self.dev

    def set_normalize_by(self,normalize_by):
        self.normalize_by = normalize_by
        self.set_dev()

    def set_dev(self):

        if self.movie is None:
            return
        if self.normalize_by == 'Standard Deviation':
            if self.est_algorithm == 'Median':
                if hasattr(self,'mad') and (self.mad is not None):
                    self.dev = self.mad.copy()
                    # print 'set_dev to mad'
            else:
                if hasattr(self,'std') and (self.std is not None):
                    self.dev = self.std.copy()
                    # print 'set_dev to std'
        else:
            if hasattr(self,'center') and (self.center is not None):
                self.dev = self.center.copy()
                # print 'set_dev to center'

        if (not hasattr(self,'dev')) or (self.dev is None):
            return
        self.dev[self.dev < self.bg_std_min] = self.bg_std_min
        self.dev[self.dev > self.bg_std_max] = self.bg_std_max
        self.thresh_low = self.dev*self.n_bg_std_thresh_low
        if self.n_bg_std_thresh_high > self.n_bg_std_thresh_low:
            self.thresh_high = self.dev*self.n_bg_std_thresh_high

    def set_min_std(self,bg_std_min):
        self.bg_std_min = bg_std_min
        self.set_dev()

    def set_max_std(self,bg_std_max):
        self.bg_std_max = bg_std_max
        self.set_dev()

    def set_movie(self,movie):

        if self.iscomputed():
            delattr(self,'_last_bg_nframes')
            delattr(self,'_last_est_algorithm')
            delattr(self,'_last_startframe')
            delattr(self,'_last_endframe')

        self.movie = movie

        self.nr = self.movie.get_height()
        self.nc = self.movie.get_width()
        self.nframes = self.movie.get_n_frames()
        
        # mask of pixels that are always background
        if (self.bg_mask is None) or \
           (not (self.bg_mask.shape[0] == self.nr)) or \
           (not (self.bg_mask.shape[1] == self.nc)):
            self.bg_mask = num.zeros((self.nr,self.nc),dtype=bool)

    def __print__(self):

        s = '['
        s += '\n  Movie: ' + self.movie.filename
        s += '\n  Algorithm: ' + self.est_algorithm
        s += '\n  NFrames: ' + str(self.bg_nframes)
        s += '\n  Startframe: ' + str(self.startframe)
        s += '\n  Endframe: ' + str(self.endframe)
        s += '\n  MinStd: ' + str(self.bg_std_min)
        s += '\n  MaxStd: ' + str(self.bg_std_max)
        s += '\n  LowThresh: ' + str(self.n_bg_std_thresh_low)
        s += '\n  HighThresh: ' + str(self.n_bg_std_thresh_high)
        s += '\n  DifferenceMode: ' + str(self.difference_mode)
        s += '\n  NormalizeBy: ' + str(self.normalize_by)
        s += '\n]'

        return s

    def __str__(self):

        return self.__print__()
