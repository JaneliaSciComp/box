#!/usr/bin/env python
"""

this script prints out the size of each avi, fmf, or sbfmf
filename passed to it


djo, 5/08

"""


# ------------------------- imports -------------------------
import os
import sys


from sbmovielib.FlyMovieFormat import FlyMovie
from sbmovielib.movies import Avi



# ------------------------- main() -------------------------
def main():
    """
    run the main function
    """
    
    if len(sys.argv) < 2:
        print "usage: sbinfo.py [list of movie files]"
        sys.exit()
    
    for fn in sys.argv[1:]:
        if not os.path.exists(fn):
            print "%s not found" % fn
            continue
        if fn.endswith('.avi'):
            movie = Avi(fn, fmfmode=True)
        elif fn.endswith(('.fmf', '.sbfmf')):
            movie = FlyMovie(fn)
        else:
            print "%s isn't a fly movie (avi, fmf, or sbfmf)"
            continue
        print "%s: %d x %d, %d frames" % (fn, movie.get_width(), 
            movie.get_height(), movie.get_n_frames())
    
    # end main()

# ------------------------- script start -------------------------

if __name__ == "__main__":
    main()


