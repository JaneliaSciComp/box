"""
Inputs:

Name(s) of SBFMF file(s) to check. If none input, then all SBFMFs in the current directory are checked. 

Options:

  --version             Show program's version number and exit
  -h, --help            Show the help message and exit
  -p PFILENAME, --pfile=PFILENAME
                        Parameter file name (we read summary name from here).
			Default = "sbparam-diagnose.txt"
  -b BOUNDFILENAME, --boundfile=BOUNDFILENAME
                        Name of text file containing bounds output in the previous step.
			Default = "/groups/branson/bransonlab/projects/olympiad/sbfmf_diagnostics/sbfmf_bounds.txt"
  -d DATAFILENAME, --datafile=DATAFILENAME
                        Name of text file containing all the data output in the previous step. 
			Default = "/groups/branson/bransonlab/projects/olympiad/sbfmf_diagnostics/sbfmf_data.txt"

Parameters set at start: None

Outputs: 

1 if the last SBFMF file checked is out of bounds, 0 if normal. 

Results:

This script writes the results of the check of each SBFMF file to 
{outputbasename = "sbfmf_check_" + sbfmfbasename + ".txt"}
where sbfmfbasename is the base name of the current SBFMF. 
This file looks something like:
{noformat}
isok: 1
field,isoutofbounds,prctless,prctmore
mean errror,0,41.316667,58.683333
max window error,0,8.433333,91.550000
compression rate,0,80.750000,19.250000
max error,0,4.466667,92.016667
mean window error,0,9.800000,90.200000
nframes,0,0.000000,80.000000
{noformat}

In this example, the first line indicates that the SBFMF was normal. The next lines indicate which bounds were satisfied, and the percent of the data less and more than the diagnostic for this file. 
"""

import os.path
import logging
import numpy as num
from read_diagnostics_summary import read_diagnostics_summary
import optparse
from sbmovielib.version import __version__
import string
import sbconvert
from sbmovielib import util

class DiagnosticCheck:
    def __init__(self,boundfile,datafile,summarybasename):

        self.summarybasename = summarybasename
        self.datafile = datafile
        self.boundfile = boundfile

        # read the bounds to check
        self.read_bounds()
        # read the "normal" data
        self.read_data()
        
    def read_bounds(self):
        
        # open the boundfile
        fid = open(self.boundfile,'r')
        
        # read in the headers
        # this will be field, min, max
        line = fid.readline()
        line = line.strip()
        fields = line.split(',')

        # find which index is the field, min max 
        # should be this:
        fieldi = 0
        mini = 1
        maxi = 2
        for i in range(len(fields)):
            if fields[i] == 'field':
                fieldi = i
            elif fields[i] == 'min':
                mini = i
            elif fields[i] == 'max':
                maxi = i

        # initialize dicts for min and max bounds
        self.minbounds = dict()
        self.maxbounds = dict()

        # read through each line (line for each field)
        for line in fid:
            # remove white space
            line = line.strip()
            # split at ,
            fields = line.split(',')
            name = fields[fieldi].strip()
            # read min and max
            self.minbounds[name] = float(fields[mini])
            self.maxbounds[name] = float(fields[maxi])
        
        fid.close()

    def read_data(self):

        # initialize
        self.data = dict()

        # open the data file
        fid = open(self.datafile,'r')

        # each line will be the field name followed by the data
        for line in fid:
            [field,data] = string.split(line,',',1)
            self.data[field] = num.fromstring(data,sep=',')

        # close the file
        fid.close()

        return
    
    # end read_data

    def isinbounds(self,sbfmfname):

        if not hasattr(self,'sbfmfname') or self.sbfmfname != sbfmfname or not hasattr(self,'diagnostics'):
            # read in the diagnostics
            self.diagnostics = read_diagnostics_summary(sbfmfname,self.summarybasename)
        # store in case we try to read bounds, frac less again
        self.sbfmfname = sbfmfname

        isoutofbounds = dict()
        isok = True

        # loop through all the bounds
        for key in self.minbounds.iterkeys():
            
            # initialize not out of bounds
            isoutofbounds[key] = 0

            # not in diagnostics, then okay
            if key not in self.diagnostics:
                logging.warning("field %s not read from diagnostics summary file"%key)
                continue

            # check against bounds
            if self.diagnostics[key] > self.maxbounds[key]:
                isoutofbounds[key] = 1
                isok = False
            elif self.diagnostics[key] < self.minbounds[key]:
                isoutofbounds[key] = -1
                isok = False

        return (isok,isoutofbounds)

    # end isinbounds

    def get_prct_less(self,sbfmfname):

        if not hasattr(self,'sbfmfname') or self.sbfmfname != sbfmfname or not hasattr(self,'diagnostics'):
            # read in the diagnostics
            self.diagnostics = read_diagnostics_summary(sbfmfname,self.summarybasename)            

        prctless = dict()
        prctmore = dict()
        for (key,val) in self.diagnostics.iteritems():
            nless = len(num.nonzero(self.data[key] < val)[0])
            prctless[key] = 100. * float(nless) / len(self.data[key])
            # not nec 100 - prctless, cuz some may be =
            nmore = len(num.nonzero(self.data[key] > val)[0])
            prctmore[key] = 100. * float(nmore) / len(self.data[key])
        return (prctless,prctmore)

def main():

    # use optparse module for command-line options:
    usage = "usage: %prog [options]"
    parser = optparse.OptionParser(usage=usage, version="%%prog %s" % __version__)
    parser.add_option("-p", "--pfile", dest="pfilename", default="sbparam-diagnose.txt", 
                      help="optional parameter file name (we read summary name from here)")
    parser.add_option("-b", "--boundfile", dest="boundfilename", default="/groups/branson/bransonlab/projects/olympiad/sbfmf_diagnostics/sbfmf_bounds.txt",
                      help="optional bound file name")
    parser.add_option("-d", "--datafile", dest="datafilename", default="/groups/branson/bransonlab/projects/olympiad/sbfmf_diagnostics/sbfmf_data.txt",
                      help="optional data file name")
    (options, args) = parser.parse_args()
    options.debug = True

    # read parameters
    params = sbconvert.readparams(options)
    summarybasename = params["summaryfile"]
    
    # start logging (screen and/or file)
    sbconvert.startlogging(options, params)

    # initialize the diagnostic checks
    diagnostic_check = DiagnosticCheck(options.boundfilename,options.datafilename,summarybasename)

    if not args:
        # if no filenames, go through current dir for candidates
        args = os.listdir('.')

    logging.debug('minbounds = ' + str(diagnostic_check.minbounds))
    logging.debug('maxbounds = ' + str(diagnostic_check.maxbounds))

    for sbfmfname in args:
        [base,ext] = os.path.splitext(sbfmfname)
        if ext != '.sbfmf':
            continue

        # check bounds
        (isok,isoutofbounds) = diagnostic_check.isinbounds(sbfmfname)
        # get fraction less
        (prctless,prctmore) = diagnostic_check.get_prct_less(sbfmfname)
        logging.info("fields checked: " + str(diagnostic_check.minbounds.keys()))
        logging.info('isok = ' + str(isok))
        logging.info('isoutofbounds = ' + str(isoutofbounds))
        logging.info('prct of data less = ' + str(prctless))
        logging.info('prct of data more = ' + str(prctmore))

        # output file name
        [path,base] = os.path.split(sbfmfname)
        outputbasename = "sbfmf_check_" + base + ".txt"
        outputfilename = os.path.join(path,outputbasename)

        # open output
        fid = open(outputfilename,'w')

        # write whether the check is ok
        fid.write('isok: %d\n'%isok)

        # write header for the rest of the info
        fid.write('field,isoutofbounds,prctless,prctmore\n')

        #print 'isoutofbounds = ' + str(isoutofbounds)
        #print 'prctless = ' + str(prctless)
        #print 'prctmore = ' + str(prctmore)
        
        # write the data for each field
        for key in prctless.keys():
            if key in isoutofbounds:
                fid.write('%s,%d,%f,%f\n'%(key,isoutofbounds[key],prctless[key],prctmore[key]))
            else:
                fid.write('%s,%d,%f,%f\n'%(key,0,prctless[key],prctmore[key]))

        # close the file
        fid.close()

        if isok:
            logging.info("Check for %s succeeded"%sbfmfname)
        else:
            logging.info("Check for %s failed"%sbfmfname)
    
    # end loop over sbfmfnames

    return not isok

# end main
# ------------------------- script start -------------------------
if __name__ == "__main__":
    main()

