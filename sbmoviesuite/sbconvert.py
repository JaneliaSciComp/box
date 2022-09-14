"""

This is the command-line tool for converting avi movie files into 
sbfmf format.

"python sbconvert.py -h" for usage

The parameter file:
- plain text file, filename ends in ".in" 
- whitespace-delimited key/value list
- blank lines allowed
- if first non-blank character is '#', rest ignored (ie, comment line)
- unknown keys cause errors
- repeated keys: last one wins (no error)
- any keys not set are taken from internal defaults


djo, 4/08

"""


# ------------------------- imports -------------------------
# from std lib
import cPickle as pickle
import logging
import optparse
import os
import re
import socket
import sys
import time
import traceback

# from our lib
from sbmovielib.movies import Avi
from sbmovielib import backsub
from sbmovielib.compressfmf import CompressFMF
from sbmovielib.FlyMovieFormat import FlyMovie
from sbmovielib import sequence
from sbmovielib import util
from sbmovielib.version import __version__


# ------------------------- assignbgfiles() -------------------------
def assignbgfiles(inputfiles, params):
    """
    parse through the options and inputs, and sort out:
    -- which sequences need to be created with which files
    -- assign movies (existing or new seq. to be created) 
        to each input file
    
    input: file list; params dict
    output: stem dictionary: stems[filename] = stem;
            filelist dictionary: filelist[stem] = [(i, filename)...]
    """
    
    stems = {}
    filelist = {}
    if params["usesequence"]:
        logging.info("using movie sequences for background subtraction")
        
        # params["sequencesuffix"] should look like "seq#.avi", or
        #   'none' or 'None'; if the latter, ignore the
        #   suffix and use all files
        suffix = params["sequencesuffix"]
        if suffix == "none" or suffix == "None":
            # use all files in current dir that have format in the
            #   allowed list; use an arbitrary "stem":
            filelist["all"] = []
            templist = os.listdir('.')
            templist = filterformats(templist, params)
            # use lexical sort order here:
            templist.sort()
            for i, fn in enumerate(templist):
                filelist["all"].append((i, fn))
                stems[fn] = "all"
        else:
            # get file sequences from sequence suffix
            if suffix.count('#') != 1:
                util.errorquit("sequence suffix must have one # character")
            front, back  = suffix.split('#')
            # this is our regexp:
            restring = r"(.*%s)(\d+)%s" % (front, back)
            seqfinder = re.compile(restring)
            
            # find the stem and sequence number for each filename;
            #   save them per stem
            for fn in inputfiles:
                found = seqfinder.findall(fn)
                # if no match, it's not part of a sequence: 
                if not found:
                    stems[fn] = fn
                    filelist[fn] = [(0, fn)]
                else:
                    stem = found[0][0]
                    n = int(found[0][1])
                    if stem in filelist:
                        filelist[stem].append((n, fn))
                    else:
                        filelist[stem] = [(n, fn)]
                    stems[fn] = stem
    else:
        logging.info("using individual movies for background subtraction")
        for fn in inputfiles:
            stems[fn] = fn
            filelist[fn] = [(0, fn)]
    
    return filelist, stems
    
    # end assignbgfiles()

# ------------------------- calculatebackgrounds() -------------------------
def calculatebackgrounds(bgdict):
    """
    given a dictionary of background objects, call the appropriate
    methods so that the backgrounds are actually calculated
    
    input: dictionary
    output: none
    """
    
    for stem in bgdict:
        bg = bgdict[stem]
        if bg is not None and not bg.iscomputed():
            bg.est_bg()
    
    # end calculatebackgrounds()

# ------------------------- convertfiles() -------------------------
def convertfiles(filelist, stems, bg, params):
    """
    convert files
    
    input:  list of files to convert
            dict mapping filename to stem
            dictionary mapping stem to bg object  
            parameter dictionary
    output: none
    """
    
    # loop over filenames, try to convert those that need it:
    for filename in filelist:
        basename, ext = os.path.splitext(filename)
        
        logging.debug("working on %s" % filename)
        
        if not os.path.exists(basename + '.sbfmf') or params["overwrite"]:
            # convert
            
            # pass in/out files in params:
            params["inputfilename"] = filename
            params["outputfilename"] = basename + '.sbfmf'
            
            logging.info("converting %s" % params["inputfilename"])
            logging.info("output file: %s" % params["outputfilename"])
            
            # do conversion
            # if bg[stem] is None, couldn't create bg, so log and move on
            #   note that if we pass bg=None to the convertor, it'll just
            #   try again, which we don't want
            if bg[stems[filename]] is not None:
                try:
                    converter = CompressFMF(params, bg[stems[filename]])
                    nframes = converter.nframes
                    errors = converter.geterror()
                    
                    # added by KB:
                    # get more diagnostics
                    if params["docomputediagnostics"]:
                        diagnostics = converter.getdiagnostics()

                except:
                    logging.warning("failed to convert %s" % filename)
                    logging.log(15, "\n\nText of the error:\n\n %s" % traceback.format_exc())
                else:
                    # do some logging...
                    logging.info("mean squared error = %s" % errors[0])
                    logging.info("max squared error = %s" % errors[1])

                    # added by KB:
                    # log more diagnostics
                    if params["docomputediagnostics"]:
                        logging.info("mean max squared window error = %s"%diagnostics["meanmaxwindowerror"])
                        logging.info("max max squared window error = %s"%diagnostics["maxmaxwindowerror"])
                        logging.info("compression rate = %s"%diagnostics["compressionrate"])
                    
                    newsummary = not os.path.exists(params["summaryfile"])
                    
                    # in principle, multiple instances could try to write to the
                    #   summary file at once; in the absence of a dead-easy 
                    #   cross-platform locking solution, I'll just put a 
                    #   try clause to catch any utter failures; the info is
                    #   written to the log file and std out anyway
                    try:
                        f = open(params["summaryfile"], 'a')
                        if newsummary:
                            # write heading line
                            if params["docomputediagnostics"]:
                                f.write("date\t  time\tfile\t\tnframes\t\tmean errror\tmax error\t\tmean window error\t\tmax window error\t\tcompression rate\n")
                            else:
                                f.write("date\t  time\tfile\t\tnframes\t\tmean errror\tmax error\n")

                        # write the data line
                        if params["docomputediagnostics"]:
                            f.write("%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\n" % (time.strftime("%d %b %y %H:%M"),
                                                                      params["outputfilename"], nframes, errors[0], errors[1], diagnostics["meanmaxwindowerror"], diagnostics["maxmaxwindowerror"], diagnostics["compressionrate"]))
                        else:
                            f.write("%s\t%s\t%d\t%s\t%s\n" % (time.strftime("%d %b %y %H:%M"),
                                                              params["outputfilename"], nframes, errors[0], errors[1]))
                        f.close()
                    except:
                        logging.warning("couldn't write summary line to summary file; look in log output instead for error estimate")
            else:
                logging.warning("failed to convert %s; background creation failed" % filename)
        else:
            logging.warning("skipping %s; converted file already exists" % filename)
    
    # end convertfiles()

# ------------------------- createbgobjects() -------------------------
def createbgobjects(stems, movies, params):
    """
    create the background subtraction objects
    
    input:  stem dictionary: stems[filename] = stem
            movie dict: movies[stem] = filename of movie
            params dict
    output: bg dict: bg[stem] = BackSub object
    """
    
    bg = {}
    for stem in movies:
        print "**stem = " + str(stem)
        print "**movies[stem] = " + str(movies[stem])
        print '**movies[stem].endswith("avi") = ' + str(movies[stem].endswith(".avi"))
        try:
            if movies[stem].endswith(".avi"):
                print "** trying to create Avi"
                #tempmovie = Avi(movies[stem], fmfmode=True)
                tempmovie = Avi(movies[stem], fmfmode=False)
                print "** created tempmovie"
            elif movies[stem].endswith((".fmf", ".sbfmf")):
                tempmovie = FlyMovie(movies[stem])
            else:
                raise ValueError("unknown movie type for %s" % movies[stem])
        except:
            # failed to create movie for whatever reason
            tempmovie = ""
        
        if tempmovie:
            bg[stem] = backsub.BackSub(
                movie=tempmovie,
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
            # couldn't create background
            logging.warning("background object creation failed for stem %s; " % stem +
                "conversions for corresponding movies will fail!")
            bg[stem] = None
    
    return bg
    
    # end createbgobjects()

# ------------------------- createsequence() -------------------------
def createsequence(stem, filelist, params):
    """
    generate a sequence
    
    input: string stem; list of files, in desired order; params dict
    output: tempfilename
    """
    
    logging.info("found %d files for stem %s:" % (len(filelist), stem))
    for f in filelist:
        logging.info("%s" % os.path.basename(f))
    
    # temp file need not be clever; just use time stamp in filename:
    tempfilename = "temp-%s-%s.fmf" % (stem, time.strftime("%d%b%H%M"))
    # use same folder as input:
    tempfilename = os.path.join(os.path.dirname(filelist[0]), tempfilename)
    logging.info("using temporary movie file %s" % tempfilename)
    
    sequence.condensesequence(tempfilename, filelist, int(params["bg_nframes"]))
    
    return tempfilename
    
    # end createsequence()

# ------------------------- filterformats() -------------------------
def filterformats(filelist, params):
    """
    filter a file list down to the files with the desired
    formats
    
    input: list of files; parameter structure
    output: filtered list of files
    """
    
    # filter: the "inputformats" parameter specifies which formats
    #   to filter out, whether we listed dir or were given filenames:
    inputformats = tuple(".%s" % item for item in params["inputformats"].split(','))
    filelist = [f for f in filelist if f.endswith(inputformats)]
    
    # another filter: prevent us from processing Mac resource forks,
    #   which could have right extensions; exclude filenames starting with "."
    filelist = [f for f in filelist if not f.startswith('.')]
    
    return filelist
    
    # end filterformats()

# ------------------------- getbgfilename() -------------------------
def getbgfilename(stem):
    """
    determines the filename to store a background image for
    
    note: stem = filename (no seq, or non-template seq) or 
        true stem or all
    
    single name: movie.avi --> movie-bg.pickle
    template seq: movie-1.avi, movie-2.avi --> movie--bg.pickle
    arbitrary seq: movie.avi, film.avi --> all-bg.pickle
    
    input: stem
    output: filename
    """
    
    # test for a file extension...this is a big too specific,
    #   but not sure how otherwise to test, because we don't
    #   want to disallow "." in the rest of the filenames
    
    if stem.endswith((".avi", ".fmf")):
        base, ext = os.path.splitext(stem)
    else:
        # this covers both sequences from templates and "all"
        base = stem
    return "%s-bg.pickle" % base
    
    # end getbgfilename()

# ------------------------- loadbgfile() -------------------------
def loadbgfile(filename):
    """
    load a bg object from a file
    
    input: filename
    output: bg object; returns None on any error
    """
    
    if not os.path.exists(filename):
        logging.exception("couldn't find background file %s" % filename)
        return None
    
    try:
        logging.info("loading background file %s" % filename)
        f = open(filename, "rb")
        bg = pickle.load(f)
        f.close()
    except:
        logging.exception("error loading background from %s" % filename)
        bg = None
    return bg
    
    # end loadbgfile()

# ------------------------- readparams() -------------------------
def readparams(options):
    """
    read parameters from an input file into a dictionary
    
    do some processing on the input, too
    
    input: options dictionary
    output: parameters dictionary
    """
    
    
    # if the file exists (user provided or default), read it:
    if os.path.exists(options.pfilename):
        try:
            data = open(options.pfilename).readlines()
        except StandardError:
            util.errorquit("couldn't read parameter file %s" % options.pfilename)
    else:
        # if it's not there and the user provided it, complain:
        if options.pfilename != util.defaultpfilename:
            util.errorquit("couldn't find paramter file %s" % options.pfilename)
        else:
            data = ""
    
    # the default dictionary; if we've read a file, add input data to it
    params = util.parsepfile(util.defaultpfiledata.split('\n'))
    if data:
        try:
            inputparams = util.parsepfile(data)
        except StandardError:
            util.errorquit("couldn't parse parameter file")
        for keyword in inputparams:
            if keyword in params:
                params[keyword] = inputparams[keyword]
            else:
                util.errorquit("unknown keyword %s found" % keyword)
        # note the file we got this from:
        params["parameterfile"] = options.pfilename
    else:
        params["parameterfile"] = "default"
    
    # validate/launder input:
    params = util.validatepfile(params)
    
    # add the version:
    params["version"] = __version__
    
    return params
    
    # end readparams()

# ------------------------- savebgfile() -------------------------
def savebgfile(filename, background):
    """
    save a background object to a file
    
    input: filename and object to save
    output: boolean: successful or not?
    """
    
    try:
        logging.info("saving background file %s" % filename)
        f = open(filename, "wb")
        pickle.dump(background, f, protocol=2)
        f.close()
        status = True
    except:
        logging.exception("error saving background object to %s" % filename)
        status = False
    return status
    
    # end savebgfile()

# ------------------------- startlogging() -------------------------
def startlogging(options, params):
    """
    start up the logs, write out the header
    
    input: options from optparse; params dict
    output: none
    """
    
    # start the logger; configure for screen and file (different levels)
    
    logging.addLevelName(util.loglevels["info-plus"], "INFO-PLUS")
    
    # set up two handlers explicitly; don't use logging.basicConfig():
    # screen:
    screenloglevel = util.loglevels[params["screenloglevel"]]
    console = logging.StreamHandler()
    console.setLevel(screenloglevel)
    formatter = logging.Formatter('%(message)s')
    console.setFormatter(formatter)
    logging.getLogger('').addHandler(console)
    
    # file:
    fileloglevel = util.loglevels[params["fileloglevel"]]
    logfilename =  params["logfile"]
    base, ext = os.path.splitext(logfilename)
    logfilename = "%s-%s-%s%s" % (base, socket.gethostname().split('.')[0], 
        time.strftime("%Y%m%d%H%M%S"), ext)
    filehandler = logging.FileHandler(logfilename, "a") 
    filehandler.setLevel(fileloglevel) 
    formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s') 
    filehandler.setFormatter(formatter) 
    logging.getLogger('').addHandler(filehandler)
    
    # set overall log levels; if debugging, go back and increase level
    #   for each logger as well
    if options.debug:
        console.setLevel(logging.DEBUG)
        filehandler.setLevel(logging.DEBUG)
        logging.getLogger('').setLevel(logging.DEBUG)
    else:
        # usual logging level (not debug)
        logging.getLogger('').setLevel(min(screenloglevel, fileloglevel))
    
    
    # write a header
    logging.info("\n")
    logging.info("sbconvert.py v%s" % __version__)
    logging.info("by Donald J. Olbris")
    logging.info("Started %s" % time.asctime())
    logging.info("Running on %s" % socket.gethostname())
    logging.info("parameter file: %s" % params["parameterfile"])
    logging.info("\n")
    
    # end startlogging()


# ------------------------- main() -------------------------
def main():
    """
    main function (for script packaging purposes); control
    is passed here immediately after the script starts
    """
    
    # ----- start up operations
    # use optparse module for command-line options:
    usage = "usage: %prog [options]"
    parser = optparse.OptionParser(usage=usage, version="%%prog %s" % __version__)
    parser.add_option("-p", "--pfile", dest="pfilename", default=util.defaultpfilename, 
        help="optional parameter file name")
    parser.add_option("-w", "--write-default", action="store_true", dest="writedefault",
        default=False, help="write default parameter file to disk")
    parser.add_option("-d", action="store_true", dest="debug",
        default=False, help="set all logging output to debug level (very verbose)")
    (options, args) = parser.parse_args()
    
    # if desired, write out the default parameter file:
    if options.writedefault:
        util.writedefaultpfile()
        sys.exit()
    
    # read parameters
    params = readparams(options)
    
    # start logging (screen and/or file)
    startlogging(options, params)
    
    # ----- preparation for conversion
    
    # args is the candidate list of files to work with
    if not args:
        print "** no filenames passed in"
        # if no filenames, go through current dir for candidates
        args = os.listdir('.')
    else:
        print "** filenames passed in = " + str(args)
    
    # filter down to the formats desired:
    args = filterformats(args, params)

    print "**args = " + str(args)
    
    
    # keep a list of names of temporary files and remove at the end;
    #   not needed unless you're doing a sequence with shared
    #   background, and then is needed to avoid deleting the file
    #   before it's done being used
    tempfilelist = []
    
    
    # get mapping of files to stems and sequences
    logging.debug("mapping files and sequences")
    filelist, stems = assignbgfiles(args, params)

    print "** filelist = " + str(filelist)
    print "** stems = " + str(stems)
    
    
    movies = {}
    logging.debug("creating sequences (as needed)")
    for stem in filelist:
        # create sequences if needed; if not, original file = movie for bg
        if len(filelist[stem]) > 0:
            filelist[stem].sort()
            filelist[stem] = [item[1] for item in filelist[stem]]
            # if we're reading the bg files, we need not create sequence;
            #   the value of movies[stem] is unused (although the 
            #   key must still be present in the dict)
            if params["readbgfiles"]:
                movies[stem] = "placeholder sequence filename"
            else:
                tempfilename = createsequence(stem, filelist[stem], params)
                movies[stem] = tempfilename
                # record tempfilename (but not movie object)
                tempfilelist.append(tempfilename)
        else:
            # not a sequence, stem = filename
            movies[stem] = stem
    
    
    # new version; allows save/load of background images:
    logging.debug("creating background objects")
    if params["readbgfiles"]:
        # read in background objects; note that loadbgfiles() logs 
        #   its own errors
        # bg[stem] = background object
        bg = {}
        if params["bgfilename"] == "default":
            # for each stem, generate default bg filename; load bg object
            for stem in movies:
                fn = getbgfilename(stem)
                background = loadbgfile(fn)
                if background is not None:
                    bg[stem] = background
                else:
                    # remove movies for this stem from processing list
                    logging.error("due to failure to load background file, " +
                        "removing following files from conversion list:")
                    for i, moviefn in filelist[stem]:
                        logging.info(moviefn)
                        args.remove(moviefn)
                        del stems[moviefn]
                    del movies[stem]
                    # bg[stem] ought not to exist 
        else:
            # user specified a bg file to use
            fn = params["bgfilename"]
            background = loadbgfile(fn)
            if background is not None:
                bg[stem] = background
            else:
                # in the "load one bg file for everything" mode, no bg 
                #   file = no work to be done
                logging.error("due to failure to load background file, " +
                    "removing all files from conversion list")
                args = []
                stems = {}
                bg = {}
    else:
        # don't read bg objects, create them
        bg = createbgobjects(stems, movies, params)
        if params["writebgfiles"]:
            # if you're going to save backgrounds, do the calculation now
            #   instead of deferring it
            logging.info("calculating backgrounds for save")
            calculatebackgrounds(bg)
            for stem in bg:
                fn = getbgfilename(stem)
                if os.path.exists(fn) and not params["overwrite"]:
                    logging.info("background file %s already exists; set 'overwrite' flag if you wish to overwrite it" % fn)
                else:
                    # this function logs its own errors; for now, I
                    #   ignore its True/False status return
                    # don't try to save a failed background:
                    if bg[stem] is not None:
                        status = savebgfile(fn, bg[stem])
    
    
    # ----- conversion and shut down
    if params["convert"]:
        logging.debug("convering files")
        convertfiles(args, stems, bg, params)
    else:
        logging.info("convert flag set to false; no movies converted")
    
    
    # remove temporary files and we're done!
    #   (used to close files, but see if we can avoid it;
    #   painful to track them)
    logging.debug("removing temporary files")
    for filename in tempfilelist:
        if os.path.exists(filename):
            os.remove(filename)
    logging.info("all operations finished\n")
    logging.info("see you later!\n\n")
    
    # end main()


# ------------------------- script start -------------------------
if __name__ == "__main__":
    main()

