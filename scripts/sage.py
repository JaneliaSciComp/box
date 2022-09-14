import numpy as np
import cStringIO, datetime, os.path, sys, urllib, warnings, xml.etree.cElementTree as etree

try:
    import MySQLdb
except:
    sys.stderr.write("Could not import the MySQLdb module.  Most functionality will be disabled.\n")
    MySQLdb = None


restBaseURL = 'http://sage.int.janelia.org/sage-ws/'


# Filter out warnings that are raised when querying for a CV term that is actually in a parent CV.  
warnings.filterwarnings('ignore', '.*No data - zero rows.*')
    

class Lab(object):
    
    _labs = {}
    
    def __new__(cls, name, *args, **keywordArgs):
        # Make sure only one instance of each lab is created.
        if any(args) or any(keywordArgs):
            lab = object.__new__(cls)
        else:
            if not any(Lab._labs):
                # Get the list of labs with lines from SAGE.
                fd = urllib.urlopen(restBaseURL + 'lines.janelia-sage')
                xmlStream = fd.read()
                fd.close()
                labSet = etree.fromstring(xmlStream)
                labElems = labSet.findall('lineLab')
                for labElem in labElems:
                    labName = labElem.findtext('name', None)
                    Lab._labs[labName] = Lab(labName, displayName = labElem.findtext('displayName', None))
            lab = Lab._labs.get(name, None)
        
        return lab
            
    
    def __init__(self, name, displayName = None):
        # Don't initialize if this is a cached instance.
        if not hasattr(self, 'name'):
            object.__init__(self)
            self.name = name
            self.displayName = displayName
            self._lines = {}
            self._linesFullyFetched = False
    
    
    def __eq__(self, other):
        return isinstance(other, Lab) and self.name == other.name
    
    
    def __ne__(self, other):
        return not isinstance(other, Lab) or self.name != other.name
    
    
    def __repr__(self):
        return self.displayName or 'Lab: ' + self.name
    
    
    def _fetchLines(self, query = None):
        # Get the list of lines from SAGE.
        restURL = restBaseURL + 'lines/' + self.name + '.janelia-sage'
        if query:
            restURL += '?' + urllib.urlencode({'q': 'name=' + query})
        fd = urllib.urlopen(restURL)
        xmlStream = fd.read()
        fd.close()
        lineElems = etree.fromstring(xmlStream).findall('line')
        for lineElem in lineElems:
            lineName = lineElem.findtext('name', None)
            yield Line(self, lineName)
    
        
    def lines(self, query = None):
        """
        Return all lines for the lab or only those that match the query term.
        
        Currently the query term can contain any number of asterisks to match zero or more characters.
        For "starts with" use 'foo*'.
        For "contains" use '*foo*'.
        For "ends with" use '*foo'.
        """
        
        if query:
            lines = list(self._fetchLines(query))
            for line in lines:
                self._lines[line.name] = line
            return lines
        else:
            if not self._linesFullyFetched:
                for line in self._fetchLines():
                    self._lines[line.name] = line
                self._linesFullyFetched = True
            return self._lines.values()
    
    
    def line(self, lineName):
        """Return the line that exactly matches the given name.  If no such line exists then None will be returned."""
        
        if lineName not in self._lines:
            lines = list(self._fetchLines(lineName))
            if len(lines) == 1:
                self._lines[lineName] = lines[0]
            else:
                self._lines[lineName] = None
        return self._lines[lineName]
    
    
    def lookupID(self):
        return CV('lab').term(self.name).lookupID()
    

def labs():
    Lab('') # make sure the list has been fetched
    return Lab._labs.values()


class Line(object):
    
    @classmethod
    def UnspecifiedLine(cls):
        """ Returns an object that supports creating sessions, etc. that are not tied to a specific genetic line. """
        return _UnspecifiedLine()
    
    
    def __init__(self, lab, name):
        object.__init__(self)
        self.lab = lab
        self.name = name
    
    
    def __eq__(self, other):
        return isinstance(other, Line) and self.name == other.name and self.lab.name == other.lab.name
    
    
    def __ne__(self, other):
        return not isinstance(other, Line) or self.name != other.name or self.lab.name != other.lab.name
    
    
    def __repr__(self):
        return 'Line: ' + self.name + ' (from the ' + self.lab.displayName + ')'
    
    
    def lookupID(self):
        return '(select id from line_vw where name = \'' + self.name + '\' and lab =  \'' + self.lab.name + '\')'


class _UnspecifiedLine(Line):
    """ A Line subclass that supports creating sessions, etc. that are not tied to a specific genetic line. """
    
    def __init__(self):
        object.__init__(self)
        self.lab = None
        self.name = "Unspecified line"
    
    
    def __repr__(self):
        return 'An unspecified line'
    
    
    def lookupID(self):
        return '0'


class Connection(object):
    
    def __init__(self, paramsPath = None, params = None, autocommit = True):
        """
        Create a connection to an instance of SAGE based on params or the file at paramsPath.
        
        Either params or paramsPath should be specified.
        
        If paramsPath is specified it should be the path to a configuration file that looks like:
            host: db-dev
            database: sage
            username: sageApp
            password: <password>
            line-synonym: pBDPGal4U=pBDPGAL4U
        
        If params is specified it should be a dictionary with 'host', 'username' and 'password' keys with string values.  
        Optionally it can contain a 'line-synonyms' key whose value should be a dictionary.  The dictionary...
        """
        if MySQLdb is None:
            raise ValueError, 'The MySQLdb module is not available.'
        if paramsPath:
            params = {'line-synonyms': {}}
            defaults = {'engine': 'mysql', 'port': 3306, 'database': 'sage'}
            from ConfigParser import ConfigParser
            sageConfig = ConfigParser(defaults)
            sageConfig.read(paramsPath)
            if sageConfig.has_section('Database'):
                params['engine'] = sageConfig.get('Database', 'engine', True)
                if sageConfig.has_option('Database', 'host'):
                    params['host'] = sageConfig.get('Database', 'host')
                else:
                    raise Exception, 'The SAGE config file is missing the host option in the [Database] section.'
                params['port'] = int(sageConfig.get('Database', 'port', True))
                params['database'] = sageConfig.get('Database', 'database', True)
                if sageConfig.has_option('Database', 'username'):
                    params['username'] = sageConfig.get('Database', 'username')
                else:
                    raise Exception, 'The SAGE config file is missing the username option in the [Database] section.'
                if sageConfig.has_option('Database', 'password'):
                    params['password'] = sageConfig.get('Database', 'password')
                else:
                    # TODO: have special value to trigger prompt for password?
                    raise Exception, 'The SAGE config file is missing the password option in the [Database] section.'
                # TODO: read in line synonyms
            else:
                raise Exception, 'The SAGE config file does not contain a [Database] section.'
        if not params or 'host' not in params or 'username' not in params or 'password' not in params:
            raise ValueError, 'The correct parameters were not specified to create a connection.'
        object.__init__(self)
        self._db = MySQLdb.connect(params['host'], params['username'], params['password'], db = params['database'])
        if autocommit == False:
            self.autocommitOff()
        self.lineSynonyms = params['line-synonyms']
    
    
    def cursor(self):
        return self._db.cursor()
    

    def createExperiment(self, name, expType, lab, experimenter = ''):
        if not isinstance(expType, CVTerm):
            raise TypeError, 'expType must be a sage.CVTerm instance'
        if isinstance(lab, str):
            lab = Lab(lab)
        if not isinstance(lab, Lab):
            raise TypeError, 'lab must be a sage.Lab instance'
    
        c = self._db.cursor()
        rowCount = c.execute('insert into experiment (name, type_id, lab_id, experimenter) values (%s, ' + expType.lookupID() + ', ' + lab.lookupID() + ', %s)', (name, experimenter))
        if rowCount == 1:
            return Experiment(self, c.lastrowid, name, expType, lab, experimenter)
        else:
            raise ValueError, 'Could not create experiment'
    
    
    def findExperiments(self, name = None, typeTerm = None, lab = None):
        if not isinstance(typeTerm, (type(None), CVTerm)):
            raise TypeError, 'If typeTerm is specified it must be a CVTerm instance'
        if lab:
            if isinstance(lab, str):
                lab = Lab(lab)
            if not isinstance(lab, (type(None), Lab)):
                raise TypeError, 'If lab is specified it must be a Lab instance'
        
        c = self._db.cursor()
        query = 'select e.id, e.name, cv.name, cv_term.name, lab.name, e.experimenter from experiment e, cv, cv_term, cv_term lab where e.type_id = cv_term.id and cv_term.cv_id = cv.id and lab.id = e.lab_id'
        
        args = []
        if name:
            query += ' and e.name = %s'
            args += [name]
        if typeTerm:
            query += ' and e.type_id = ' + typeTerm.lookupID()
        if lab:
            query += ' and e.lab_id = ' + lab.lookupID()
        rowCount = c.execute(query, args)
        experiments = []
        for i in range(rowCount):
            expID, expName, cvName, termName, labName, experimenter = c.fetchone()
            experiments += [Experiment(self, expID, expName, CV(cvName).term(termName), Lab(labName), experimenter)]
        return experiments
    
    
    def lookupLineStartsWith(self, name, labName = None):
        if name in self.lineSynonyms:
            name = self.lineSynonyms[name]
        c = self._db.cursor()
        sql = 'select lab, name from line_vw where name like %s'
        if labName is not None:
            sql += 'and lab_id = ' + labLookup(labName)
        rowCount = c.execute(sql, ('%' + name))
        if rowCount == 0:
            return None
        elif rowCount == 1:
            labName, lineName = c.fetchone()
            return Lab(labName).line(lineName)
        else:
            raise ValueError, 'Multiple lines named \'' + name + '\' found.'
    
    
    def lookupLineILike(self, name, labName = None):
        if name in self.lineSynonyms:
            name = self.lineSynonyms[name]
        c = self._db.cursor()
        sql = 'select lab, name from line_vw where lower(name) like lower(%s)'
        if labName is not None:
            sql += 'and lab_id = ' + labLookup(labName)
        rowCount = c.execute(sql, ('%' + name + '%'))
        if rowCount == 0:
            return None
        elif rowCount == 1:
            labName, lineName = c.fetchone()
            return Lab(labName).line(lineName)
        else:
            raise ValueError, 'Multiple lines named \'' + name + '\' found.'  
    
    
    def storeScoreArray(self, scoreType, array, dataType = None, experiment = None, session = None, phase = None, run = None):
        if not isinstance(array, np.ndarray):
            raise TypeError, 'array must be a numpy.ndarray'
        
        # Determine the type of the values in the array.
        if dataType is None:
            # TODO: check the dtype of the array
            if array.dtype.type == np.string_:
                dataType = 'str' + str(array.dtype.itemsize)
            elif array.dtype.name[0:3] == 'int' or array.dtype.name[0:4] == 'uint':
                # TODO: check if the byte count can be reduced based on the min/max values
                dataType = array.dtype.name
            elif array.dtype.name.startswith('float'):
                floatBits = int(array.dtype.name[5:])
                if floatBits == 64:
                    dataType = 'double'
                elif floatBits == 32:
                    dataType = 'single'
                elif floatBits == 16:
                    dataType = 'half'
            else:
                raise TypeError, 'Cannot handle numpy data of type ' + typeName
        
        # Pack the array into a single string
        if dataType == 'double':
            format = '%25.16g'
        elif dataType == 'single':
            format = '%16.8g'
        elif dataType == 'half':
            format = '%11.4g'
        elif dataType == 'uint8':
            format = '%3d'
        elif dataType == 'uint16':
            format = '%5d'
        elif dataType[0:3] == 'str':
            format = '%' + dataType[3:] + 's'
        else:
            raise TypeError, 'Can only handle double, single, half, uint8 and uint16 score arrays at this point'
        buffer = cStringIO.StringIO()
        np.savetxt(buffer, array, fmt = format + ' ', delimiter = '')
        
        if array.ndim > 1:
            rows, columns = array.shape
        else:
            rows = array.size
            columns = array.ndim
        
        # Remove the extra space at the end of each row.
        buffer = buffer.getvalue().replace(' \n', '\n')
        
        # Build the SQL insert statement.
        sql1 = 'insert into score_array ('
        sql2 = 'values ('
        values = []
        if experiment:
            sql1 += 'experiment_id, '
            sql2 += '%s, '
            values += [experiment.id] 
        if session:
            sql1 += 'session_id, '
            sql2 += '%s, '
            values += [session.id] 
        if phase:
            sql1 += 'phase_id, '
            sql2 += '%s, '
            values += [phase.id]
        if run:
            sql1 += 'run, '
            sql2 += '%s, '
            values += [run]
        sql1 += 'term_id, type_id, value, data_type, row_count, column_count) '
        sql2 += scoreType.cv.term('not_applicable').lookupID() + ', ' + scoreType.lookupID() + ', compress(%s), %s, %s, %s)'
        values += [buffer, dataType, rows, columns]
        
        # Attempt the insert.
        c = self.cursor()
        rowCount = c.execute(sql1 + sql2, values)
        if rowCount == 0:
            raise ValueError, 'Could not store score array'
        else:
            return c.lastrowid
        
    def storeScoreArray2(self, scoreType, scoreTerm, array, dataType = None, experiment = None, session = None, phase = None, run = None):
        if not isinstance(array, np.ndarray):
            raise TypeError, 'array must be a numpy.ndarray'
        
        # Determine the type of the values in the array.
        if dataType is None:
            # TODO: check the dtype of the array
            if array.dtype.type == np.string_:
                dataType = 'str' + str(array.dtype.itemsize)
            elif array.dtype.name[0:3] == 'int' or array.dtype.name[0:4] == 'uint':
                # TODO: check if the byte count can be reduced based on the min/max values
                dataType = array.dtype.name
            elif array.dtype.name.startswith('float'):
                floatBits = int(array.dtype.name[5:])
                if floatBits == 64:
                    dataType = 'double'
                elif floatBits == 32:
                    dataType = 'single'
                elif floatBits == 16:
                    dataType = 'half'
            else:
                raise TypeError, 'Cannot handle numpy data of type ' + typeName
        
        # Pack the array into a single string
        if dataType == 'double':
            format = '%25.16e'
        elif dataType == 'single':
            format = '%16.8e'
        elif dataType == 'half':
            format = '%11.4e'
        elif dataType == 'uint8':
            format = '%3d'
        elif dataType == 'uint16':
            format = '%5d'
        elif dataType[0:3] == 'str':
            format = '%' + dataType[3:] + 's'
        else:
            raise TypeError, 'Can only handle double, single, half, uint8 and uint16 score arrays at this point'
        buffer = cStringIO.StringIO()
        np.savetxt(buffer, array, fmt = format + ' ', delimiter = '')
        
        if array.ndim > 1:
            rows, columns = array.shape
        else:
            rows = array.size
            columns = array.ndim
        
        # Remove the extra space at the end of each row.
        buffer = buffer.getvalue().replace(' \n', '\n')
        
        # Build the SQL insert statement.
        sql1 = 'insert into score_array ('
        sql2 = 'values ('
        values = []
        if experiment:
            sql1 += 'experiment_id, '
            sql2 += '%s, '
            values += [experiment.id] 
        if session:
            sql1 += 'session_id, '
            sql2 += '%s, '
            values += [session.id] 
        if phase:
            sql1 += 'phase_id, '
            sql2 += '%s, '
            values += [phase.id]
        if run:
            sql1 += 'run, '
            sql2 += '%s, '
            values += [run]
        sql1 += 'term_id, type_id, value, data_type, row_count, column_count) '
        sql2 += scoreTerm.lookupID() + ', ' + scoreType.lookupID() + ', compress(%s), %s, %s, %s)'
        values += [buffer, dataType, rows, columns]
        
        # Attempt the insert.
        c = self.cursor()
        rowCount = c.execute(sql1 + sql2, values)
        if rowCount == 0:
            raise ValueError, 'Could not store score array'
        else:
            return c.lastrowid
    
    def storeScore(self, scoreType, scoreTerm, value, experiment = None, session = None, phase = None, run = None):
        if value is None:
            return
        sql1 = 'insert into score ('
        sql2 = 'values ('
        values = []
        if experiment:
            sql1 += 'experiment_id, '
            sql2 += '%s, '
            values += [experiment.id] 
        if session:
            sql1 += 'session_id, '
            sql2 += '%s, '
            values += [session.id] 
        if phase:
            sql1 += 'phase_id, '
            sql2 += '%s, '
            values += [phase.id]
        if run:
            sql1 += 'run, '
            sql2 += '%s, '
            values += [run]
        sql1 += 'term_id, type_id, value) '
        sql2 += scoreTerm.lookupID() + ', ' + scoreType.lookupID() + ', %s)'
        values += [value]
        # Attempt the insert.
        c = self.cursor()
        rowCount = c.execute(sql1 + sql2, values)
        if rowCount == 0:
            raise ValueError, 'Could not store score array'
        else:
            return c.lastrowid
    
    
    def commitChanges(self):
        self._db.commit()
        
    def rollback(self):
        self._db.rollback()
        
    def autocommitOff(self):
        c = self._db.cursor()
        rowCount = c.execute("SET AUTOCOMMIT=0")


class DBObject(object):
    
    @classmethod
    def tableName(cls):
        raise ValueError, 'DBObject sub-classes must override the tableName method.'
    
    
    def __init__(self, connection, objectID, name = None):
        if not isinstance(connection, Connection):
            raise TypeError, 'The connection object is not valid.'
        
        object.__init__(self)
        self._db = connection
        self.id = objectID
        self.name = name
    
    
    def __eq__(self, other):
        return isinstance(other, type(self)) and self._db == other._db and self.id == other.id


class PropertyObject(DBObject):
    
    
    def getProperty(self, propertyType = None):
        if not isinstance(propertyType, CVTerm):
            raise TypeError, 'propertyType must be a sage.CVTerm instance'
        
        c = self._db.cursor()
        tableName = self.__class__.tableName()
        rowCount = c.execute('select value from ' + tableName + '_property where ' + tableName + '_id = ' + str(self.id) + ' and type_id = ' + propertyType.lookupID())
        if rowCount == 0:
            return None
        else:
            return c.fetchone()[0]
    
    
    def setProperty(self, propertyType, value):
        if not isinstance(propertyType, CVTerm):
            raise TypeError, 'propertyType must be a sage.CVTerm instance'
        
        if isinstance(value, CVTerm):
            # For now the value of the CV term is stored but in a future SAGE the CV term ID could be stored instead.
            value = value.name
        
        c = self._db.cursor()
        tableName = self.__class__.tableName()
        if tableName == 'image':
            # The image table does not have a unique key on image_id+type_id so "replace into" creates duplicate records.
            if self.getProperty(propertyType) is None:
                rowCount = c.execute('insert into ' + tableName + '_property (' + tableName + '_id, type_id, value) ' + \
                                     'values (%s, ' + propertyType.lookupID() + ', %s)', (self.id, value))
                if (rowCount != 1):
                    raise ValueError, 'Could not set ' + tableName + ' property'
            else:
                rowCount = c.execute('update ' + tableName + '_property set value = %s where ' + tableName + '_id = %s and type_id = ' + propertyType.lookupID(), (value, self.id))
                # If the value doesn't change then rowCount is 0.
        else:
            rowCount = c.execute('replace into ' + tableName + '_property (' + tableName + '_id, type_id, value) ' + \
                                 'values (%s, ' + propertyType.lookupID() + ', %s)', (self.id, value))
            if (rowCount != 2 and rowCount != 1):
                # TODO: Why is 2 OK?
                raise ValueError, 'Could not set ' + tableName + ' property'
    
    
class Experiment(PropertyObject):
    
    @classmethod
    def tableName(cls):
        return 'experiment'
    
    
    def __init__(self, connection, objectID, name = None, typeTerm = None, lab = None, experimenter = None):
        if not isinstance(typeTerm, CVTerm):
            raise TypeError, 'typeTerm must be a sage.CVTerm instance'
        
        PropertyObject.__init__(self, connection, objectID, name)
        self.type = typeTerm
        self.lab = lab
        self.experimenter = experimenter
    
        
    def createSession(self, name, sessionType, line, lab):
        if not isinstance(sessionType, CVTerm):
            raise TypeError, 'sessionType must be a sage.CVTerm instance'
        if line is None:
            line = _UnspecifiedLine()
        if not isinstance(line, Line):
            raise TypeError, 'line must be a sage.Line instance or None'
        if isinstance(lab, str):
            lab = Lab(lab)
        if not isinstance(lab, Lab):
            raise TypeError, 'lab must be a sage.Lab instance'
        
        c = self._db.cursor()
        rowCount = c.execute('insert into session (experiment_id, name, type_id, line_id, lab_id) values (%s, %s, ' + sessionType.lookupID() + ', ' + line.lookupID() + ', ' + lab.lookupID() + ')', (self.id, name))
        if rowCount == 1:
            return Session(self._db, c.lastrowid, self, name, sessionType, line, lab)
        else:
            raise ValueError, 'Could not create session'
    
    
    def findSessions(self, name = None, typeTerm = None, line = None, lab = None):
        if not isinstance(line, (Line, type(None))):
            raise TypeError, 'line must be a sage.Line instance or None'
        if lab:
            if isinstance(lab, str):
                lab = Lab(lab)
            if not isinstance(lab, Lab):
                raise TypeError, 'lab must be a sage.Lab instance or None'
        
        c = self._db.cursor()
        query = 'select s.id, s.name, s.cv, s.type, l.lab, s.line, s.lab from (session_vw s left join line_vw l on s.line_id = l.id) where experiment_id = %s'
        args = [self.id]
        if name:
            query += ' and s.name = %s'
            args += [name]
        if typeTerm:
            if not isinstance(typeTerm, CVTerm):
                raise TypeError, 'typeTerm must be a CVTerm instance.'
            query += ' and s.type = %s'
            args += [typeTerm.name]
        if line:
            query += ' and s.line_id = ' + line.lookupID()
        if lab:
            query += ' and s.lab = %s'
            args += [lab.name]
        
        rowCount = c.execute(query, args)
        sessions = []
        for i in range(rowCount):
            sessionID, name, cvName, typeTerm, lineLab, lineName, labName = c.fetchone()
            lineLab = Lab(lineLab)
            if not lineLab:
                if isinstance(line, Line):
                    raise ValueError, 'The line "' + line.name + '" does not exist in this instance of SAGE.'
                else:
                    raise ValueError, 'Could not create session instance because its line does not exist.'
            line = lineLab.line(lineName)
            sessions += [Session(self._db, sessionID, self, name, CV(cvName).term(typeTerm), line, Lab(labName))]
        return sessions
    
        
    def createPhase(self, name, typeTerm):
        if not isinstance(typeTerm, CVTerm):
            raise TypeError, 'typeTerm must be a sage.CVTerm instance'
        
        c = self._db.cursor()
        rowCount = c.execute('insert into phase (experiment_id, name, type_id) values (%s, %s, ' + typeTerm.lookupID() + ')', (self.id, name))
        if rowCount == 1:
            return Phase(self._db, c.lastrowid, self, name, typeTerm)
        else:
            raise ValueError, 'Could not create phase'
        
    def updatePhase(self, phase, name, typeTerm):
        if not isinstance(phase, Phase):
            raise TypeError, 'phase must be a sage.Phase instance'
        if not isinstance(typeTerm, CVTerm):
            raise TypeError, 'typeTerm must be a sage.CVTerm instance'
        
        c = self._db.cursor()
        phase_id = phase.id
        rowCount = c.execute('update phase set experiment_id= %s, name = %s, type_id='+ typeTerm.lookupID() + 'where id = %s', (self.id, name, phase_id))

        return Phase(self._db, phase_id, self, name, typeTerm)
    
    
    def findPhases(self, name = None, typeTerm = None):
        c = self._db.cursor()
        query = 'select id, name, cv, type from phase_vw where experiment_id = %s'
        args = [self.id]
        if name:
            query += ' and name = %s'
            args += [name]
        if typeTerm:
            if not isinstance(typeTerm, CVTerm):
                raise TypeError, 'typeTerm must be a sage.CVTerm instance.'
            query += ' and type = %s'
            args += [typeTerm.name]
        rowCount = c.execute(query, args)
        phases = []
        for i in range(rowCount):
            phaseID, name, cvName, typeTerm = c.fetchone()
            phases += [Phase(self._db, phaseID, self, name, CV(cvName).term(typeTerm))]
        return phases
    
    
    def storeScoreArray(self, scoreType, array, dataType = None, run = None):
        self._db.storeScoreArray(scoreType, array, dataType = dataType, experiment = self, run = run)


class Session(PropertyObject):
    
    @classmethod
    def tableName(cls):
        return 'session'
    
    
    def __init__(self, connection, objectID, experiment, name = None, typeTerm = None, line = None, lab = None):
        if not isinstance(typeTerm, CVTerm):
            raise TypeError, 'typeTerm must be a sage.CVTerm instance'
        if not isinstance(line, Line):
            raise TypeError, 'line must be a sage.Line instance'
        if not isinstance(lab, Lab):
            raise TypeError, 'lab must be a sage.Lab instance'
        
        PropertyObject.__init__(self, connection, objectID, name)
        self.experiment = experiment
        self.type = typeTerm
        self.line = line
        self.lab = lab
    
    
    def createRelationship(self, otherSession, relationshipType):
        if not isinstance(otherSession, Session):
            raise TypeError, 'otherSession must be a sage.Session instance'
        if not isinstance(relationshipType, CVTerm):
            raise TypeError, 'relationshipType must be a sage.CVTerm instance'
        
        c = self._db.cursor()
        try:
            rowCount = c.execute('insert into session_relationship (subject_id, object_id, type_id) values (%s, %s, ' + relationshipType.lookupID() + ')', (otherSession.id, self.id))
        except MySQLdb.IntegrityError as e:
            if e.args[0] == 1062:
                rowCount = 1    # The relationship already existed.
            else:
                raise(e)
            
        # TODO: check for "Duplicate entry" error and ignore?
        if rowCount != 1:
            raise ValueError, 'Could not create the relationship'
    
    
    def storeScoreArray(self, scoreType, array, dataType = None, run = None):
        self._db.storeScoreArray(scoreType, array, dataType = dataType, session = self, run = run)
        
    def storeScoreArray2(self, scoreType, scoreTerm, array, dataType = None, run = None):
        self._db.storeScoreArray2(scoreType, scoreTerm, array, dataType = dataType, session = self, run = run)
    
    def storeScore(self, scoreType, scoreTerm, value, run = None):
        self._db.storeScore(scoreType = scoreType, scoreTerm = scoreTerm, value = value, experiment = None, session = self, phase = None, run = run)
    
    
    # TODO: createScore, lookupScore methods
    
    
class Phase(PropertyObject):
    
    @classmethod
    def tableName(cls):
        return 'phase'
    
    
    def __init__(self, connection, objectID, experiment, name = None, typeTerm = None):
        if not isinstance(typeTerm, CVTerm):
            raise TypeError, 'typeTerm must be a sage.CVTerm instance'
        
        PropertyObject.__init__(self, connection, objectID, name)
        self.experiment = experiment
        self.type = typeTerm
    
    
    def storeScoreArray(self, scoreType, array, dataType = None, run = None):
        self._db.storeScoreArray(scoreType, array, dataType = dataType, phase = self, run = run)
    
    
    # TODO: createScore, lookupScore methods


class ImageFamily(object):
      
    def __init__(self, connection, name = None, urlBase = None, pathBase = None, lab = None):
        if not isinstance(connection, Connection):
            raise TypeError, 'connection must be a sage.Connection instance'
        if name is None or urlBase is None or pathBase is None or lab is None:
            raise ValueError, 'All parameters must be specified for an image family.'
        if not isinstance(lab, Lab):
            raise TypeError, 'lab must be a sageLab instance'
        
        object.__init__(self)
        self._db = connection
        self.name = name
        self.urlBase = urlBase
        self.pathBase = pathBase
        self.lab = lab
    

    def addImage(self, subPath, name = None, line = None, experiment = None, isRepresentative = False, display = True, createDate = None, creator = None, imageType = None):
        if not isinstance(line, (Line, type(None))):
            raise TypeError, 'line must be a sage.Line instance or None'
        if not isinstance(experiment, (Experiment, type(None))):
            raise TypeError, 'experiment must be a sage.Experiment instance or None'
        if not isinstance(imageType, (str, type(None))):
            raise TypeError, 'imageType must be a string or None'
        
        if name is None:
            name = subPath
        
        fullPath = os.path.join(self.pathBase, subPath)
        if os.path.exists(fullPath):
            if createDate is None:
                createDate = datetime.datetime.fromtimestamp(os.path.getctime(fullPath))
            fileSize = os.path.getsize(fullPath)
            if subPath.endswith('.png'):
                # Get the pixel dimensions of the PNG by brute force reading the bytes.
                # This would be more robust using PIL but that's a painful dependency.
                # Don suggested calling out to ImageMagick which would also work.
                png = open(fullPath, 'rb')
                png.seek(16)
                widthBytes = png.read(4)
                heightBytes = png.read(4)
                png.close()
                width = 0
                height = 0
                for i in range(0, 4):
                    width = width * 256 + ord(widthBytes[i])
                    height = height * 256 + ord(heightBytes[i])
            else:
                width = height = None
        else:
            raise ValueError, 'Could not find a file at ' + fullPath
                    
        sql1 = 'insert into image (name, url, path, source_id, family_id, line_id, representative, display'
        if line is None:
            line_num = 0
        else:
            line_num = line.lookupID()
        sql2 = ') values (%s, %s, %s, ' + str(self.lab.lookupID()) + ', getCvTermId(\'family\', %s, NULL), ' + str(line_num) + ', %s, %s'
        if isRepresentative:
            r_value = 1
        else:
            r_value = 0
        if display:
            d_value = 1
        else:
            d_value = 0
        args = [name, self.urlBase + subPath, fullPath, self.name, r_value, d_value]
        if experiment is not None:
            sql1 += ', experiment_id'
            sql2 += ', %s'
            args += [experiment.id]
        if createDate is not None:
            sql1 += ', capture_date'
            sql2 += ', %s'
            args += [createDate]
        if creator is not None:
            sql1 += ', created_by'
            sql2 += ', %s'
            args += [creator]
        c = self._db.cursor()
        try:
            rowCount = c.execute(sql1 + sql2 + ')', args)
        except:
            print('Could not create image "%s".', name)
            raise
        if rowCount == 1:
            image = Image(self._db, c.lastrowid, name, self, line, experiment, isRepresentative, display, createDate, creator, imageType)
            
            image.setProperty(CV('light_imagery').term('file_size'), fileSize)
            if width:
                image.setProperty(CV('light_imagery').term('dimension_x'), width)
            if height:
                image.setProperty(CV('light_imagery').term('dimension_y'), height)
            
            if imageType:
                image.setProperty(CV('light_imagery').term('product'), imageType)
            
            return image
        else:
            raise ValueError, 'Could not create image'
    
    def updateImage(self, old_image, subPath, name = None, line = None, experiment = None, isRepresentative = False, display = True, createDate = None, creator = None, imageType = None):
        if not isinstance(old_image, (Image)):
            raise TypeError, 'old_image must be a sage.Image instance'
        if not isinstance(line, (Line, type(None))):
            raise TypeError, 'line must be a sage.Line instance or None'
        if not isinstance(experiment, (Experiment, type(None))):
            raise TypeError, 'experiment must be a sage.Experiment instance or None'
        if not isinstance(imageType, (str, type(None))):
            raise TypeError, 'imageType must be a string or None'
        
        if name is None:
            name = subPath
        
        fullPath = self.pathBase + subPath
        if os.path.exists(fullPath):
            if createDate is None:
                createDate = datetime.datetime.fromtimestamp(os.path.getctime(fullPath))
            fileSize = os.path.getsize(fullPath)
            if subPath.endswith('.png'):
                # Get the pixel dimensions of the PNG by brute force reading the bytes.
                # This would be more robust using PIL but that's a painful dependency.
                # Don suggested calling out to ImageMagick which would also work.
                png = open(fullPath, 'rb')
                png.seek(16)
                widthBytes = png.read(4)
                heightBytes = png.read(4)
                png.close()
                width = 0
                height = 0
                for i in range(0, 4):
                    width = width * 256 + ord(widthBytes[i])
                    height = height * 256 + ord(heightBytes[i])
            else:
                width = height = None
        else:
            raise ValueError, 'Could not find a file at ' + fullPath
        
        id = old_image.id
        if line is None:
            line_num = 0
        else:
            line_num = line.lookupID()
        sql1 = 'update image set name = %s , url = %s, path= %s, source_id =  ' + self.lab.lookupID() + ', family_id = getCvTermId(\'family\', %s, NULL), line_id = ' + str(line_num) + ', representative = %s, display = %s'
        if isRepresentative:
            r_value = 1
        else:
            r_value = 0
        if display:
            d_value = 1
        else:
            d_value = 0
        args = [name, self.urlBase + subPath, fullPath, self.name, r_value, d_value]
        if experiment is not None:
            sql1 += ', experiment_id = %s'
            args += [experiment.id]
        if createDate is not None:
            sql1 += ', capture_date = %s'
            args += [createDate]
        if creator is not None:
            sql1 += ', created_by = %s'
            args += [creator]
        sql1 += ' where id = %s'
        args += [id]

        c = self._db.cursor()
        rowCount = c.execute(sql1, args)
        image = Image(self._db, id, name, self, line, experiment, isRepresentative, display, createDate, creator, imageType)
        
        image.setProperty(CV('light_imagery').term('file_size'), fileSize)
        if width:
            image.setProperty(CV('light_imagery').term('dimension_x'), width)
        if height:
            image.setProperty(CV('light_imagery').term('dimension_y'), height)
        
        if imageType:
            image.setProperty(CV('light_imagery').term('product'), imageType)
        
        return image

    def findImages(self, experiment):
        if not isinstance(experiment, Experiment):
            raise TypeError, 'experiment must be an Experiment instance'
        
        c = self._db.cursor()
        query = 'select img.id, img.name, line_vw.lab, line_vw.name, img.representative, img.display, img.create_date, img.created_by from ((image img left outer join line_vw on img.line_id = line_vw.id) left join image_property_vw ipw on (img.id = ipw.image_id and ipw.type = \'product\')) where img.family_id = getCvTermId(\'family\', %s, NULL) and img.experiment_id = %s'
        args = [self.name, experiment.id]
        rowCount = c.execute(query, args)
        images = []
        for i in range(rowCount):
            imgID, imgName, labName, lineName, isRepresentative, display, createDate, creator = c.fetchone()
            images += [Image(self._db, imgID, imgName, self, experiment.lab.line(lineName), experiment, isRepresentative != 0, display != 0, createDate, creator)]
        return images


class Image(PropertyObject):
    
    @classmethod
    def tableName(cls):
        return 'image'
    
    
    def __init__(self, connection, objectID, name = None, family = None, line = None, experiment = None, isRepresentative = False, display = True, createDate = None, creator = None, imageType = None):
        PropertyObject.__init__(self, connection, objectID, name)
        self.family = family
        self.line = line
        self.experiment = experiment
        self.isRepresentative = isRepresentative
        self.display = display
        self.createDate = createDate
        self.creator = creator
        self.type = imageType


class CVTerm(object):
    
    def __init__(self, cv, name, displayName = None, definition = None, dataType = None):
        object.__init__(self)
        self.cv = cv
        self.name = name
        self.displayName = displayName
        self.definition = definition
        self.dataType = dataType
    
    
    def __repr__(self):
        return 'CV Term: ' + self.name + ' (from the ' + self.cv.name + ' CV)'
    
    
    def lookupID(self):
        return 'getCvTermId(\'' + self.cv.name + '\', \'' + self.name + '\', NULL)'


class CV(object):
    
    _cvs = {}
    
    def __new__(cls, name, *args, **keywordArgs):
        # Make sure only one instance of each CV is created.
        if any(args) or any(keywordArgs):
            cv = object.__new__(cls)
        else:
            if not any(CV._cvs):
                # Get the list of CV's from SAGE.
                fd = urllib.urlopen(restBaseURL + 'cvs.janelia-sage')
                xmlStream = fd.read()
                fd.close()
                cvSet = etree.fromstring(xmlStream)
                cvElems = cvSet.findall('cv')
                for cvElem in cvElems:
                    cvName = cvElem.findtext('name', None)
                    CV._cvs[cvName] = CV(cvName, displayName = cvElem.findtext('displayName', None), definition = cvElem.findtext('definition', None))
            cv = CV._cvs.get(name, None)
        
        return cv
            
    
    def __init__(self, name, displayName = None, definition = None):
        # Don't initialize if this is a cached instance.
        if not hasattr(self, 'name'):
            object.__init__(self)
            self.name = name
            self.displayName = displayName
            self.definition = definition
            self._terms = {}
    
    
    def __repr__(self):
        return 'CV: ' + self.name
    
    
    def _fetchTerms(self):
        # Get the list of terms from SAGE.
        fd = urllib.urlopen(restBaseURL + 'cvs/' + self.name + '/with-object-related-cvs.janelia-sage?relationshipType=is_sub_cv_of')
        xmlStream = fd.read()
        fd.close()
        cvSet = etree.fromstring(xmlStream)
        termElems = cvSet.findall('cv/termSet/term')
        for termElem in termElems:
            termName = termElem.findtext('name', None)
            self._terms[termName] = CVTerm(self, termName, displayName = termElem.findtext('displayName', None), definition = termElem.findtext('definition', None), dataType = termElem.findtext('dataType', None))
    
        
    def terms(self):
        """Return the full list of terms in the controlled vocabulary."""
        
        if not any(self._terms):
            self._fetchTerms()
        return self._terms.values()
            
    
    def term(self, name):
        """Return the term with the given name from the controlled vocabulary."""
        
        if not any(self._terms):
            self._fetchTerms()
        return self._terms.get(name, None)
    

def cvs():
    """Return a list of all controlled vocabularies in SAGE."""
    
    CV('') # make sure the list has been fetched
    return CV._cvs.values()

