"""

sequence-related routines for sbmovie suite; in 
some cases, we may want to estimate the background
from a sequence of movie files that are segments of
a single movie, and then compress each segment using
the background calculated from the whole movie


djo, 5/08

"""


# ------------------------- imports -------------------------
import os


# sbmovie suite:
from movies import Avi
from FlyMovieFormat import FlyMovie, FlyMovieSaver 


# ------------------------- class MovieSequence -------------------------
class MovieSequence(object):
    """
    hold a group of movies (usual types), and allow frame access as if they
    were one big movie; meant to be used for a small number of
    sequences, as it opens and keeps open all of them
    
    -- enforces .avi, .fmf., .sbfmf file types
    -- enforces same frame size
    
    if one were ambitious, one could make this resemble a FlyMovie
    even more closely by adding more methods; probably not worth
    the effort, though
    """
    # ......................... __init__ .........................
    def __init__(self):
        """
        input: none
        """
        
        # each item: (movie name, movie object, first frame, last frame) 
        self._movielist = []
        self._size = []
        
        # end __init__()
    
    # ......................... addmovie() .........................
    def addmovie(self, filename):
        """
        add a movie to the sequence
        
        input: filename of an avi, fmf, or sbfmf movie
        output: none
        """
        
        base, ext = os.path.splitext(filename)
        if ext == '.avi':
            movie = Avi(filename, fmfmode=True)
        elif ext == '.fmf' or ext == '.sbfmf':
            movie = FlyMovie(filename)
        else:
            raise ValueError("%s is not a recognized movie type (must be avi, fmf, or sbfmf)" % filename)
        
        nframes = movie.get_n_frames()
        
        if self._movielist:
            # add to existing list:
            if (movie.get_width(), movie.get_height()) != self._size:
                raise ValueError("movie %s is not the same size as the others in the sequence" % filename)
            prevmovie = self._movielist[-1]
            firstframe = prevmovie.lastframe + 1
            lastframe = firstframe + nframes - 1
            self._movielist.append(MovieRecord(filename, movie, firstframe, lastframe))
        else:
            # first one:
            self._movielist.append(MovieRecord(filename, movie, 0, nframes - 1))
            self._size = (movie.get_width(), movie.get_height())
        
        # end addmovie()
    
    # ......................... get_frame() .........................
    def get_frame(self, n):
        """
        returns a frame from the sequence
        
        input: frame number; if out of range, you get 
            first or last frame as appropriate
        output: (frame, timestamp)
        """
        
        if n < 0:
            n = 0
        if n >= self.get_n_frames():
            n = self.get_n_frames() - 1 
        
        # brute force search for the frame
        target = None
        for mov in self._movielist:
            if mov.firstframe <= n <= mov.lastframe:
                target = mov
                break
        
        # return the frame--just subtract the offset:
        return target.movie.get_frame(n - target.firstframe)
        
        # end get_frame()
    
    # ......................... get_height() .........................
    def get_height(self):
        """
        height of frames in sequence?
        """
        
        if self._movielist:
            return self._size[1]
        else:
            return 0
        
        # end get_height()
    
    # ......................... get_n_frames() .........................
    def get_n_frames(self):
        """
        how many frames in sequence?
        
        input: none
        output: number of frames overall
        """
        
        if self._movielist:
            return self._movielist[-1].lastframe + 1
        else:
            return 0
        
        # end get_n_frames()
    
    # ......................... get_width() .........................
    def get_width(self):
        """
        width of frame in sequence?
        """
        
        if self._movielist:
            return self._size[0]
        else:
            return 0
        
        # end get_width()
    
    # end class MovieSequence

# ------------------------- condensesequence() -------------------------
def condensesequence(filename, filelist, nframes):
    """
    take nframes frames, regularly spaced, from the
    given list of movies, which are taken to be ordered
    as they will lexically sort (so make sure you
    zero-pad your sequence numbers), and write out a 
    new .fmf movie with only those frames
    
    input:  filename for new movie (should be .fmf file)
            list of movies, in desired sampling sequence
            int nframes > 0
    output: none
    """
    
    # sanity checks
    if not filelist:
        return
    for fn in filelist:
        if not os.path.exists(fn):
            raise IOError("can't find file %s" % fn)
    
    if not filename.endswith('.fmf'):
        raise ValueError("output movie is in FlyMovieFormat; filename should end in .fmf")
    
    movieseq = MovieSequence()
    for fn in filelist:
        movieseq.addmovie(fn)
    
    # need a frame to write header:
    frame, timestamp = movieseq.get_frame(0)
    outmovie = FlyMovieSaver(filename)
    outmovie._do_v1_header(frame)
    
    totalframes = movieseq.get_n_frames()
    nskip = totalframes // nframes
    
    for i in range(nframes):
        framenum = i * nskip
        frame, timestamp = movieseq.get_frame(framenum)
        outmovie.add_frame(frame, timestamp)
    
    outmovie.close()    
    
    # end condensesequence()


# ------------------------- class MovieRecord -------------------------
class MovieRecord(object):
    """
    a little "struct" class, for clarity and convenience
    """
    # ......................... __init__ .........................
    def __init__(self, filename, movie, firstframe, lastframe):
        
        self.filename = filename
        self.movie = movie
        self.firstframe = firstframe
        self.lastframe = lastframe
        
        # end __init__()
    
    # end class MovieRecord

