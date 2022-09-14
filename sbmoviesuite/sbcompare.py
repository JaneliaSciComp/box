"""

calculate errors between two movie files; currently does mean squared 
difference per pixel (and max thereof)


djo, 4/08

"""



# ------------------------- imports -------------------------
# std lib
import glob
import os
import sys

# numeric 
import numpy as num

# within our lib
from sbmovielib.movies import Avi
from sbmovielib.FlyMovieFormat import FlyMovie
from sbmovielib.sequence import MovieSequence


# ------------------------- openmovie() -------------------------
def openmovie(filename):
    """
    open a movie
    
    input: filename
    output: appropriate movie object
    """
    
    basename, ext = os.path.splitext(filename)
    if ext == ".avi":
        movie = Avi(filename, fmfmode=True)
    elif ext == ".fmf" or ext == ".sbfmf":
        movie = FlyMovie(filename)
    else:
        raise ValueError("don't know how to open %s" % filename)
    
    return movie
    
    # end openmovie()

# ------------------------- calcerrors() -------------------------
def calcerrors(movie1, movie2):
    """
    input: two movie objects
    output: (mean, max) squared error
    """
    
    # sizes
    moviesize1 = (movie1.get_width(), movie1.get_height(),  movie1.get_n_frames())
    moviesize2 = (movie2.get_width(), movie2.get_height(),  movie2.get_n_frames())
    
    print "movie 1 is size %dx%d, %d frames" % moviesize1
    print "movie 2 is size %dx%d, %d frames" % moviesize2
    if moviesize1 != moviesize2:
        print "sizes differ; quitting"
        sys.exit()
    
    errorsum = 0
    errormax = 0
    imerror = num.zeros((moviesize1[0], moviesize1[1]))
    for i in range(moviesize1[2]):
        if i % 50 == 0:
            print "working on frame %d" % i
        frame1, time1 = movie1.get_frame(i)
        frame2, time2 = movie2.get_frame(i)
        imerror = frame1 - frame2
        num.power(imerror, 2, imerror)
        errorsum += imerror.mean()
        errormax = max(errormax, imerror.max())
    
    return errorsum / moviesize1[2], errormax
    
    # end calcerrors()

# ------------------------- main() -------------------------
def main():
    """
    main function; separated out for packaging purposes
    """
    
    if len(sys.argv) < 3:
        print "usage: %s file1 file2" % __file__
        sys.exit()
    
    if '-s' in sys.argv:
        # compare two sequences
        if len(sys.argv) < 4 or sys.argv[1] != '-s':
            print "usage: %s -s sequence1 sequence2" % __file__
            print "     (use '#' for * wildcard)"
            sys.exit()
        sequence1 = sys.argv[2]
        sequence2 = sys.argv[3]
        if sequence1.count('#') != 1 or sequence2.count('#') != 1:
            print "the index indicator '#' must appear exactly once in each pattern"
            sys.exit()
        sequence1 = sequence1.replace('#', '*')
        sequence2 = sequence2.replace('#', '*')
        seq1list = glob.glob(sequence1)
        seq1list.sort()
        seq2list = glob.glob(sequence2)
        seq2list.sort()
        movie1 = MovieSequence()
        print "sequence 1 contains:"
        for fn in seq1list:
            print "\t%s" % fn
            movie1.addmovie(fn)
        movie2 = MovieSequence()
        print "sequence 2 contains:"
        for fn in seq2list:
            print "\t%s" % fn
            movie2.addmovie(fn)
        if movie1.get_n_frames() != movie2.get_n_frames():
            print ("movie 1 has %d frames; movie 2 has %d; mismatch!" % 
                (movie1.get_n_frames(), movie2.get_n_frames()))
            sys.exit()
    else:
        # compare two files
        file1 = sys.argv[1]
        file2 = sys.argv[2]
        print "file 1 =", file1
        print "file 2 =", file2
        movie1 = openmovie(file1)
        movie2 = openmovie(file2)
    
    # at this point, we can finally operate on the movies:
    meanerr, maxerr = calcerrors(movie1, movie2)
    
    print
    print "mean square error =", meanerr
    print "max square error =", maxerr
    
    # end main()
    
# ------------------------- script start -------------------------
if __name__ == "__main__":
    main()
