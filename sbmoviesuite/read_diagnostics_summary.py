import os.path
import logging
import string
import re

def read_diagnostics_summary(sbfmfname,summarybasename):
    """
    for the sbfmf file input, read in the last entry of the summary file that
    corresponds to this file.
    return a dictionary with all the diagnostics
    """

    # initialize diagnostics dictionary as empty
    diagnostics = dict()

    # summary file will be in the same directory, but with name summarybasename
    [path,basename] = os.path.split(sbfmfname)
    summaryfile = os.path.join(path,summarybasename)

    if not os.path.isfile(summaryfile):
        logging.warning("no summary file %s for %s"%(summaryfile,sbfmfname))
        return

    fid = open(summaryfile,'r')

    line = fid.readline()
    # split line at tabs to get headers
    headers = re.split("\t+",line)
    # remove whitespace
    for i in range(len(headers)):
        headers[i] = string.strip(headers[i])

    # find file, date, time entry in headers
    datei = 0
    timei = 1
    filei = 2
    for i in range(len(headers)):
        if headers[i] == 'file':
            filei = i
        elif headers[i] == 'date':
            datei = i
        elif headers[i] == 'time':
            timei = i

    # read in lines
    didread = False
    for line in fid:

        fields0 = string.split(line,"\t")
        fields = []
        for field in fields0:
            field = string.strip(field)
            # date and time are together
            m = re.search("^(.*) ([0-9]+:[0-9]+)$",field)
            if m is None:
                fields.append(field)
            else:
                date = m.group(1)
                time = m.group(2)
                fields.append(date)
                fields.append(time)

        # is this the right file
        if basename != fields[filei]:
            continue

        # record that we found at least once
        didread = True

        # add each field to the diagnostics dictionary
        for i in range(len(headers)):

            # don't add the file, date, or time
            if i == filei or i == timei or i == datei:
                continue

            # set dictionary value, overwrite if exists
            diagnostics[headers[i]] = float(fields[i])

    fid.close()

    logging.debug("from %s read diagnostics = "%summaryfile)
    logging.debug(str(diagnostics))

    if not didread:
        logging.warning("did not read %s for %s"%(summaryfile,sbfmfname))

    return diagnostics
