classdef DataSet < handle
    % The DataSet class represents a logical collection of scores along with all relevant metadata.
    %
    % >> dataSet = SAGE.Lab('olympiad').assay('box').dataSet('analysis_info');
    % >> dataSet.description
    % 
    % ans = 
    % 
    % flatten view of box analysis info 
    % 
    % To disable the progress dialog set the progressCallback to []:
    %
    % >> dataSet.progressCallback = [];
    % 
    % You can also supply a custom callback:
    %
    % function myProgressCallback(fractionComplete, message)
    %     if nargin == 1
    %         message = '';
    %     end
    %     fprintf('[%5.1f] %s\n', fractionComplete * 100, message);
    % end
    % 
    % >> dataSet.progressCallback = @myProgressCallback;
    % 
    % To return to the default progress behavior:
    % 
    % >> dataSet.progressCallback = @dataSet.findDataProgressed;
    
    properties
        family              % The "family" of the data set.
        name                % The unique identifier of the data set.
        displayName = ''    % The human-readable name of the data set.
        description = ''    % A human-readable description of the data set useful in, for example, tooltips.
        progressCallback
    end
    
    properties (Access = private)
        dataFields = SAGE.DataSetField.empty(0, 0);
        dataFieldsStruct = struct;
        
        waitBarHandle
        progressStartTime
        lastProgressUpdate
        findDataWasCancelled
    end
    
    methods
        
        function obj = DataSet(family, name, displayName, description)
            % Create a DataSet object.
            obj.family = family;
            obj.name = name;
            if nargin > 2
                obj.displayName = displayName;
            end
            if nargin > 3
                obj.description = description;
            end
            
            obj.progressCallback = @obj.findDataProgressed;
        end
        
        
        function setFields(obj, fields)
            obj.dataFields = fields;
            
            for field = fields
                obj.dataFieldsStruct.(field.name) = field;
            end
        end
        
        
        function list = fields(obj)
            % Return the list of field (column) names for the data set.
            %
            % >> analysis_info = SAGE.Lab('Olympiad').assay('box').dataSet('analysis_info');
            % >> fields = analysis_info.fields();
            % >> fields(2).name
            % 
            % ans = 
            % 
            % experiment_name
            
            list = obj.dataFields;
        end
        
        
        function f = field(obj, name)
            if isfield(obj.dataFieldsStruct, name)
                f = obj.dataFieldsStruct.(name);
            else
                f = [];
            end
        end
        
        
        function findDataProgressed(obj, fractionComplete, progressMessage)
            if fractionComplete < 1.0
                if isempty(obj.waitBarHandle)
                    % Create the progress dialog.
                    obj.waitBarHandle = waitbar(fractionComplete, progressMessage, 'Name', 'Retrieving data from SAGE', 'CreateCancelBtn', @(hObject, eventdata)cancelFindData(obj, hObject, eventdata));
                    obj.progressStartTime = now;
                    obj.lastProgressUpdate = now;
                else
                    % Update the existing progress dialog.
                    elapsedSecs = (now - obj.progressStartTime) * 60 * 60 * 24;
                    remainingSecs = (1 - fractionComplete) * elapsedSecs / fractionComplete;
                    waitbar(fractionComplete, obj.waitBarHandle, [progressMessage ' (' timeMessage(remainingSecs) ' remaining)'])
                    
                    obj.lastProgressUpdate = now;
                end
            else
                if ~isempty(obj.waitBarHandle)
                    % Close the progress dialog.
                    delete(obj.waitBarHandle);
                    obj.waitBarHandle = [];
                end
            end
        end
        
        
        function cancelFindData(obj, ~, ~)
            obj.findDataWasCancelled = true;
        end
        
        
        function count = findDataCount(obj, varargin)
            stack = dbstack;
            calledFromFindData = numel(stack) > 1 && strcmp(stack(2).name, 'DataSet.findData');
            
            if nargin == 2 && isa(varargin{1}, 'SAGE.Query.Clause')
                %% Handle a single query object argument.
                
                % Validate the field names.
                fieldNames = varargin{1}.queriedFieldNames();
                for i = 1:numel(fieldNames)
                    field = obj.field(fieldNames{i});
                    if isempty(field)
                        error('SAGE:DataSet:Error', '''%s'' is not a field in the ''%s'' data set.\n\nUse:\n\n>> dataSet.fields().name\n\nto see the list of valid names.', fieldNames{i}, obj.name);
                    elseif field.deprecated && ~calledFromFindData
                        warning('SAGE:deprecatedField', 'The field ''%s'' is deprecated and will soon be removed from the ''%s'' data set.', fieldNames{i}, obj.name);
                    end
                end
                
                queryArgs = varargin{1}.toString();
            elseif nargin == 2 && ischar(varargin{1}),
                %% Handle a single argument which is a complete query string.
                % TODO: validate there are no illegal characters in query string
                % TODO: extract and validate field names?  not if called from findData.
                queryArgs = varargin{1};
            else
                %% Handle field/value pairs.
                if nargin < 3
                    error('SAGE:DataSet:Error', 'You must specify at least a single field/value pair')
                elseif mod(nargin, 2) ~= 1
                    error('SAGE:DataSet:Error', 'Wrong number of arguments to findDataCount')
                end
            
                queryArgs = '';
                for i = 1:((nargin - 1)/2)
                    fieldName = varargin{i * 2 - 1};
                    field = obj.field(fieldName);
                    if isempty(field)
                        error('SAGE:DataSet:Error', '''%s'' is not a field in the ''%s'' data set.\n\nUse:\n\n>> dataSet.fields().name\n\nto see the list of valid names.', fieldName, obj.name);
                    elseif field.deprecated && ~calledFromFindData
                        warning('SAGE:deprecatedField', 'The field ''%s'' is deprecated and will soon be removed from the ''%s'' data set.', fieldName, obj.name);
                    end
                    value = varargin{i * 2};
                    if i > 1
                        queryArgs = [queryArgs '&' fieldName '=' value]; %#ok
                    else
                        queryArgs = [queryArgs fieldName '=' value];  %#ok
                    end
                end
            end
            
            countURL = [SAGE.urlbase 'datasets/' obj.family.lab.name '/' obj.family.name '/' obj.name '/count?q1=' char(java.net.URLEncoder.encode(queryArgs))];
            handler = sun.net.www.protocol.http.Handler;                    % For why this is used see <http://www.mathkb.com/Uwe/Forum.aspx/matlab/37142/matlab-java-classpath-conflicts>
            urlConnection = java.net.URL([], countURL, handler).openConnection();
            urlConnection.setAllowUserInteraction(true);
            urlConnection.connect();
            try
                rc = urlConnection.getResponseCode();
                if rc == java.net.HttpURLConnection.HTTP_NOT_FOUND
                    count = 0;
                elseif rc ~= java.net.HttpURLConnection.HTTP_OK
                    errorStream = urlConnection.getErrorStream();
                    message = '';
                    while errorStream.available() > 0
                        message = [message char(errorStream.read())]; %#ok<AGROW>
                    end
                    if isempty(message)
                        message = char(urlConnection.getResponseMessage());
                    end
                    error('SAGE:DataSet:Error', 'Could not retrieve the data (%s)', message);
                else
                    inputStream = urlConnection.getInputStream();
                    try
                        channel = java.nio.channels.Channels.newChannel(inputStream);
                        buffer = java.nio.ByteBuffer.allocate(4 * 1024);
                        
                        try
                            runningBuf = '';
                            while true
                                channel.read(buffer);
                                bytesRead = buffer.position();
                                if bytesRead == 0
                                    break;
                                end
                                rawBuffer = buffer.array();
                                runningBuf = [runningBuf rawBuffer(1:bytesRead)']; %#ok<AGROW>
                                buffer.rewind();
                            end

                            tempFile = tempname;
                            fid = fopen(tempFile, 'w');
                            fwrite(fid,runningBuf);
                            fclose(fid);

                            xmlDoc = xmlread(tempFile);
                            factory = javax.xml.xpath.XPathFactory.newInstance();
                            xpath = factory.newXPath();
                            count = str2double(xpath.evaluate('/dataSet/numberOfMatchingRows', xmlDoc));
                            
                            clear buffer
                            channel.close();
                            inputStream.close();
                            clear inputStream
                        catch ME
                            clear buffer
                            channel.close();
                            rethrow(ME);
                        end
                    catch ME
                        inputStream.close();
                        clear inputStream
                        rethrow(ME);
                    end
                end
                urlConnection.disconnect();
            catch ME
                urlConnection.disconnect();
                rethrow(ME);
            end
        end
        
        
        function dataSet = findData(obj, varargin)
            % Return a subset of the data in the set.
            %
            % data = dataSet.findData(Q) searches SAGE for data matching the query Q.  
            %        The query should be constructed using the SAGE.Query.Compare, 
            %        SAGE.Query.All and/or SAGE.Query.Any functions.
            %
            % data = dataSet.findData(S) searches SAGE for data matching the query 
            %        string S.  The query string should be composed of field names 
            %        compared to values, combinations using & (AND) and | (OR) and 
            %        parentheses for nesting.
            %
            % data = dataSet.findData(F, V, ...) searches SAGE for data matching all
            %        of the given field name (F) and value (V) pairs.
            %
            % Examples
            %
            % >> analysis_info = SAGE.Lab('Olympiad').assay('box').dataSet('analysis_info');
            % >> query = SAGE.Query.All(SAGE.Query.compare('line_name', '=', 'GMR_10C*'), ...
            %                           SAGE.Query.compare('data_type', '=', 'median_vel'));
            % >> med_vel = analysis_info.findData(query);
            % >> apolloTube1 = analysis_info.findData('tube=1&box_name=Apollo');
            % >> Q3_vel = analysis_info.findData('line_name', 'GMR_68A01_AE_01', 'data_type', 'Q3_vel')
            
            
            if nargin == 2 && isa(varargin{1}, 'SAGE.Query.Clause')
                %% Handle a single query object argument.
                
                % Validate the field names.
                fieldNames = varargin{1}.queriedFieldNames();
                for i = 1:numel(fieldNames)
                    field = obj.field(fieldNames{i});
                    if isempty(field)
                        error('SAGE:DataSet:Error', '''%s'' is not a field in the ''%s'' data set.\n\nUse:\n\n>> dataSet.fields().name\n\nto see the list of valid names.', fieldNames{i}, obj.name);
                    elseif field.deprecated
                        warning('SAGE:deprecatedField', 'The field ''%s'' is deprecated and will soon be removed from the ''%s'' data set.', fieldNames{i}, obj.name);
                    end
                end
                
                queryArgs = varargin{1}.toString();
            elseif nargin == 2 && ischar(varargin{1}),
                %% Handle a single argument which is a complete query string.
                % TODO: validate there are no illegal characters in query string
                % TODO: try to extract and validate field names?
                queryArgs = varargin{1};
            else
                %% Handle field/value pairs.
                if nargin < 3
                    error('SAGE:DataSet:Error', 'You must specify at least a single field/value pair')
                elseif mod(nargin, 2) ~= 1
                    error('SAGE:DataSet:Error', 'Wrong number of arguments to findData')
                end
            
                queryArgs = '';
                for i = 1:((nargin - 1)/2)
                    fieldName = varargin{i * 2 - 1};
                    field = obj.field(fieldName);
                    if isempty(field)
                        error('SAGE:DataSet:Error', '''%s'' is not a field in the ''%s'' data set.\n\nUse:\n\n>> dataSet.fields().name\n\nto see the list of valid names.', fieldName, obj.name);
                    elseif field.deprecated
                        warning('SAGE:deprecatedField', 'The field ''%s'' is deprecated and will soon be removed from the ''%s'' data set.', fieldName, obj.name);
                    end
                    value = varargin{i * 2};
                    if isnumeric(value)
                        value = num2str(value);
                    end
                    if i > 1
                        queryArgs = [queryArgs '&' fieldName '=' value]; %#ok
                    else
                        queryArgs = [queryArgs fieldName '=' value];  %#ok
                    end
                end
            end
            
            queryURL = [SAGE.urlbase 'datasets/' obj.family.lab.name '/' obj.family.name '/' obj.name '.tsv?q1=' char(java.net.URLEncoder.encode(queryArgs))];
            
            if ~isempty(obj.progressCallback)
                obj.progressCallback(0, 'Getting count of records...');
            end
            obj.findDataWasCancelled = false;
            
            serialFifthSecond = 1 / 24 / 60 / 60 / 5;
            
            try
                % Get a count of how many records there are going to be.
                rowCount = obj.findDataCount(queryArgs);
                if rowCount == 0
                    dataSet = [];
                    if ~isempty(obj.progressCallback)
                        obj.progressCallback(1.0)   % Make sure the progress dialog is closed.
                    end
                    return
                end

                startTime = now;

                % Stream the tab-separated version of the data set.
                handler = sun.net.www.protocol.http.Handler;                    % For why this is used see <http://www.mathkb.com/Uwe/Forum.aspx/matlab/37142/matlab-java-classpath-conflicts>
                urlConnection = java.net.URL([], queryURL, handler).openConnection();
                urlConnection.setAllowUserInteraction(true);
                urlConnection.connect();
                rc = urlConnection.getResponseCode();
                if rc == java.net.HttpURLConnection.HTTP_NOT_FOUND
                    dataSet = [];
                    if ~isempty(obj.progressCallback)
                        obj.progressCallback(1.0);   % Make sure the progress dialog is closed.
                    end
                    urlConnection.disconnect();
                    return
                elseif rc ~= java.net.HttpURLConnection.HTTP_OK
                    error('SAGE:DataSet:Error', 'Could not retrieve the data (%s)', char(urlConnection.getResponseMessage()));
                end
                stream = urlConnection.getInputStream();
                channel = java.nio.channels.Channels.newChannel(stream);
                buffer = java.nio.ByteBuffer.allocate(1024 * 64);  % ~64K seems to be the max per read no matter the buffer size.
                fields = SAGE.DataSetField.empty(0, numel(obj.dataFields));
                prevBuffer = '';
                rowNum = 0;
                dataSet(1,rowCount).data = [];
                
                while true
                    % Read the next block of bytes from the web service.
                    buffer.rewind();
                    channel.read(buffer);

                    % Get the buffer out of the Java layer as quickly as possible since heap memory is limited
                    bytesRead = buffer.position();
                    if bytesRead > 0
                        buffer.rewind();
                        rawBuffer = buffer.array();
                        rawBuffer = rawBuffer(1:bytesRead)';
                        charBuf = [prevBuffer rawBuffer];
                        if any(rawBuffer == char(10))
                            % Only do the (expensive) split if there are any new lines in the newly read buffer.
                            records = regexp(charBuf, '\n', 'split');
                        else
                            records = {charBuf};
                        end
                        % TODO: not clearing is faster but does it cause memory bloat?
                        %clear charBuf rawbuffer
                    else
                        records = regexp(prevBuffer, '\n', 'split');
                    end

                    % Split the buffer by newline to find the records
                    for r = 1:numel(records)-1
                        if isempty(fields)
                            % The first record of the first read of the stream contains the field names.
                            fieldNames = regexp(records{r}, '\t', 'split');
                            for c = 1:numel(fieldNames)
                                fieldName = fieldNames{c};
                                fields(c) = obj.field(fieldName);
                                % Cache field characteristics for faster performance.
                                fieldIsData(c) = strcmp(fields(c).name, 'data'); %#ok<AGROW>
                                fieldIsDataFormat(c) = strcmp(fields(c).name, 'data_format'); %#ok<AGROW>
                                fieldIsDataRows(c) = strcmp(fields(c).name, 'data_rows'); %#ok<AGROW>
                                fieldIsDataColumns(c) = strcmp(fields(c).name, 'data_columns'); %#ok<AGROW>
                                fieldIsChar(c) = (length(fields(c).dataType) > 3 && strncmp(fields(c).dataType, 'char', 3)) || ...
                                                 (length(fields(c).dataType) > 3 && strncmp(fields(c).dataType, 'text', 3)) || ...
                                                 (length(fields(c).dataType) > 7 && strncmp(fields(c).dataType, 'varchar', 3)); %#ok<AGROW>
                                fieldIsUnsigned(c) = length(fields(c).dataType) > 8 && strcmp(fields(c).dataType(end-7:end), 'unsigned'); %#ok<AGROW>
                                fieldIsTinyInt(c) = strncmp(fields(c).dataType, 'tinyint', 7); %#ok<AGROW>
                                fieldIsSmallInt(c) = strncmp(fields(c).dataType, 'smallint', 8); %#ok<AGROW>
                                fieldIsMediumInt(c) = strncmp(fields(c).dataType, 'mediumint', 9); %#ok<AGROW>
                                fieldIsInt(c) = strncmp(fields(c).dataType, 'int', 3); %#ok<AGROW>
                                fieldIsBigInt(c) = strncmp(fields(c).dataType, 'bigint', 6); %#ok<AGROW>
                                fieldIsDecimal(c) = strncmp(fields(c).dataType, 'decimal', 7); %#ok<AGROW>
                            end
                        else
                            % Otherwise this is real data.
                            rowNum = rowNum + 1;
                            values = regexp(records{r}, '\t', 'split');

                            % Split the record by tab to get the values.
                            data = '';
                            dataFormat = 'int8';
                            dataRows = 0;
                            dataColumns = 0;
                            for c = 1:numel(values)
                                field = fields(c);
                                value = values{c};
                                if fieldIsData(c)
                                    data = value;
                                elseif fieldIsDataFormat(c)
                                    if ~isnan(str2double(value)), 
                                        dataFormat = ['str' value];
                                    elseif strcmp(value,'unint16'), 
                                        dataFormat = 'uint16'; 
                                    else
                                        dataFormat = value;
                                    end
                                elseif fieldIsDataRows(c)
                                    dataRows = uint32(str2double(value));
                                elseif fieldIsDataColumns(c)
                                    dataColumns = uint32(str2double(value));
                                else
                                    % Convert any numeric data.
                                    if fieldIsChar(c)
                                        dataSet(rowNum).(field.name) = value;
                                    elseif fieldIsDecimal(c)
                                        dataSet(rowNum).(field.name) = str2double(value);
                                    elseif fieldIsBigInt(c)
                                        if fieldIsUnsigned(c)
                                            dataSet(rowNum).(field.name) = uint64(str2double(value));
                                        else
                                            dataSet(rowNum).(field.name) = int64(str2double(value));
                                        end
                                    elseif fieldIsInt(c)
                                        if fieldIsUnsigned(c)
                                            dataSet(rowNum).(field.name) = uint32(str2double(value));
                                        else
                                            dataSet(rowNum).(field.name) = int32(str2double(value));
                                        end
                                    elseif fieldIsMediumInt(c)
                                        % MATLAB doesn't have uint24/int24 (who does?) so use the next biggest.
                                        if fieldIsUnsigned(c)
                                            dataSet(rowNum).(field.name) = uint32(str2double(value));
                                        else
                                            dataSet(rowNum).(field.name) = int32(str2double(value));
                                        end
                                    elseif fieldIsSmallInt(c)
                                        if fieldIsUnsigned(c)
                                            dataSet(rowNum).(field.name) = uint16(str2double(value));
                                        else
                                            dataSet(rowNum).(field.name) = int16(str2double(value));
                                        end
                                    elseif fieldIsTinyInt(c)
                                        if fieldIsUnsigned(c)
                                            dataSet(rowNum).(field.name) = uint8(str2double(value));
                                        else
                                            dataSet(rowNum).(field.name) = int8(str2double(value));
                                        end
                                    else
                                        dataSet(rowNum).(field.name) = value;
                                    end
                                end
                            end
                            if (dataRows ~= 0 && dataColumns ~= 0 && isempty(data)) || isempty(dataFormat)
                                error('SAGE:DataSet:Error', 'The data in row %d is missing information.', rowNum + 1)
                            end
                            dataSet(rowNum).data = SAGE.DataSet.decodeData(data, dataFormat, dataRows, dataColumns); 

                            if obj.findDataWasCancelled
                                break
                            elseif ~isempty(obj.progressCallback) && now > obj.lastProgressUpdate + serialFifthSecond
                                % Don't update the waitbar more than five times a second or it will start to slow things down.
                                elapsedSecs = (now - startTime) * 60 * 60 * 24;
                                rate = elapsedSecs / rowNum;
                                obj.progressCallback(rowNum / rowCount, [num2str(rowNum) ' of ' num2str(rowCount) ' records at ' num2str(1/rate, '%.1f') ' RPS']);
                            end
                        end
                    end

                    if bytesRead == 0
                        % We reached the end of stream.
                        break
                    elseif obj.findDataWasCancelled
                        % The user cancelled, preserve what was downloaded so far.
                        dataSet = dataSet(1:rowNum);
                        break
                    else
                        % Save the last record which didn't have a terminating newline character.
                        % It will get prepended to the next chunk read from the stream.
                        prevBuffer = records{end};
                    end
                end
                
                % clean up
                clear buffer
                channel.close();
                stream.close();
                clear stream
                urlConnection.disconnect();
            catch ME
                if ~isempty(obj.progressCallback)
                    obj.progressCallback(1.0);  % close the wait bar if there was an exception
                end
                rethrow(ME);
            end
            
            if ~isempty(obj.progressCallback)
                obj.progressCallback(1.0);    % close the wait bar if everything went well
            end
        end
        
    end
    
    
    methods (Static)

        function [encoded, data_type] = encodeData(data, data_type)
            %ENCODE_DATA Convert a 2-D matrix or cell array of strings to a string.
            %   ENCODE_DATA(M), where M is a matrix or cell array of strings, returns a 
            %   string representation of M that is as compact as possible without losing 
            %   any precision or characters.  The elements of the matrix are formatted 
            %   at a fixed width to allow indexing into the string.  The format and 
            %   precision of the elements are determined by the contents of the matrix.
            %
            %   ENCODE_DATA(M, T), where T is a string, behaves the same as
            %   ENCODE_DATA(M) except that the format and precision are specified by
            %   the type T.  Valid values for T are 'double', 'single', 'half', 'int8',
            %   'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64' and 
            %   'str#' where the '#' is any number representing a string length, e.g. 
            %   'str13'.

            % Half-precision float
            % - sign character
            % - 5 decimal digits to capture full precision (11 bits)
            % - exponent needs up to 4, e.g. "e-12"
            % - one character delimiter
            % = 12 characters per float (compared to 2 bytes native)
            % 
            % Single-precision float
            % - sign character
            % - 9 decimal digits to capture full precision (24 bits)
            % - exponent needs up to 5, e.g. "e-123"
            % - one character delimiter
            % = 17 characters per float (compared to 4 bytes native)
            % 
            % Double-precision float
            % - sign character
            % - 17 decimal digits to capture full precision (53 bits)
            % - exponent needs up to 6, e.g. "e-1234"
            % - one character delimiter
            % = 26 characters per float (compared to 8 bytes native)
            %
            % Byte
            % - sign character
            % - 3 decimal digits to capture full range (8 bits)
            % - one character delimiter
            % = 5 characters per int (compared to 1 bytes native)
            %
            % Integer
            % - sign character
            % - 5 decimal digits to capture full range (16 bits)
            % - one character delimiter
            % = 7 characters per int (compared to 2 bytes native)
            %
            % Long
            % - sign character
            % - 10 decimal digits to capture full range (32 bits)
            % - one character delimiter
            % = 12 characters per long (compared to 4 bytes native)
            %
            % Long long
            % - sign character
            % - 20 decimal digits to capture full range (64 bits)
            % - one character delimiter
            % = 22 characters per long long (compared to 8 bytes native)
            
            if isnumeric(data)
                if nargin < 2 || isempty(data_type)
                    % Determine the type of data to encode.
                    if isa(data, 'double')
                        data_type = 'double';
                    elseif isa(data, 'single')
                        data_type = 'single';
                    else
                        % Find the most compact representation of the integer data.
                        data_min = min(data);
                        data_mag = max(abs([data_min max(data)]));
                        if data_min < 0
                            for bits = [8 16 32 64]
                                if data_mag < 2^(bits - 1)
                                    data_type = sprintf('int%d', bits);
                                    break
                                end
                            end
                        else
                            for bits = [8 16 32 64]
                                if data_mag < 2^bits
                                    data_type = sprintf('uint%d', bits);
                                    break
                                end
                            end
                        end
                    end
                end

                if strcmp(data_type, 'double')
                    str_format = '%25.16g ';
                    format_width = 26;
                elseif strcmp(data_type, 'single')
                    str_format = '%16.8g ';
                    format_width = 17;
                elseif strcmp(data_type, 'half')
                    str_format = '%11.4g ';
                    format_width = 12;
                else
                    % It's an integer format.
                    if strcmp(data_type, 'int8')
                        str_format = '%4d ';
                        format_width = 5;
                    elseif strcmp(data_type, 'uint8')
                        str_format = '%3d ';
                        format_width = 4;
                    elseif strcmp(data_type, 'int16')
                        str_format = '%6d ';
                        format_width = 7;
                    elseif strcmp(data_type, 'uint16')
                        str_format = '%5d ';
                        format_width = 6;
                    elseif strcmp(data_type, 'int32')
                        str_format = '%11d ';
                        format_width = 12;
                    elseif strcmp(data_type, 'uint32')
                        str_format = '%10d ';
                        format_width = 11;
                    elseif strcmp(data_type, 'int64')
                        str_format = '%21d ';
                        format_width = 22;
                    elseif strcmp(data_type, 'uint64')
                        str_format = '%20d ';
                        format_width = 21;
                    else
                        error('SAGE:DataSet:Error', ['Cannot encode matrices with type ''' data_type '''']);
                    end
                    % Make sure the data is integer or sprintf will still show fractional digits.
                    % TBD: Raise an error if the data will be truncated?  For
                    %      example, 300 @ uint8 = 255.  Will only happen when user
                    %      specifies the type.
                    if ~isinteger(data)
                        data_type_fh = str2func(data_type);
                        data = data_type_fh(data);
                    end
                end
                
                if isempty(data)
                    encoded = '';
                else
                    % Pre-allocate the array.
                    [rows, cols] = size(data);
                    row_width = format_width * cols;
                    buffer(1, rows * row_width) = ' ';

                    % Build each row.
                    % TBD: Would it be faster to do a single sprintf call for the
                    %      entire matrix and then insert CR's at the right places?
                    for r = 1:rows
                        start_pos = (r - 1) * row_width + 1;
                        end_pos = start_pos + row_width - 1;
                        buffer(1, start_pos:end_pos) = sprintf(str_format, data(r, :));
                        buffer(1, end_pos) = char(10);
                    end
                    encoded = buffer;
                end
            elseif iscellstr(data)
                % Convert the cell array of strings to a char array and reshape it.
                if isempty(data)
                    encoded = '';
                    data_type = 'str0';
                else
                    encoded = char(reshape(data', numel(data), 1));
                    data_type = ['str' num2str(size(encoded, 2))];
                    separatorSet = vertcat(repmat(' ', size(data, 2) - 1, 1), char(10));
                    separators = repmat(separatorSet, size(data, 1), 1);
                    encoded = horzcat(encoded, separators);
                    encoded = reshape(encoded', 1, numel(encoded));
                end
            else
                error('SAGE:DataSet:Error', 'Only numeric data and cell arrays of strings are supported');
            end
        end
        

        function decoded = decodeMatrix(data, data_type, rows, cols)
            %SAGE.DataSet.decodeMatrix DEPRECATED: use decodeData instead.
            decoded = SAGE.DataSet.decodeData(data, data_type, rows, cols);
        end
        

        function decoded = decodeData(data, data_type, rows, cols)
            %SAGE.DataSet.decodeData Convert a string back into a 2-D matrix or cell array of strings.
            %   SAGE.DataSet.decodeData(S, T), where S and T are strings, returns the matrix that
            %   was encoded in the string S.
            %   SAGE.DataSet.decodeData(S, T, R, C), where S and T are strings, returns the matrix 
            %   with R rows and C columns that was encoded in the string S.
            %   In both cases T specifies the type of data in the matrix and must be one 
            %   of 'double', 'single', 'half', 'int8', 'uint8', 'int16', 'uint16', 
            %   'int32', 'uint32', 'int64', 'uint64' or 's#'.  In the 's#' case the '#' 
            %   should be a number indicating the length of the character strings in the 
            %   matrix, such as 's12'.
            
            if ~ischar(data)
                error('SAGE:DataSet:Error', 'The data passed to decodeData must be a string generated by encodeData.');
            elseif nargin < 3 && ~isempty(data) && ~strcmp(data(end), char(10))
                error('SAGE:DataSet:Error', 'The data passed to decodeData must be terminated by a newline if the number of rows and columns are not specified.');
            else
                integerNaNs = false;
                if any(strcmp(data_type, {'double', 'single'}))
                    str_format = '%e';
                elseif strcmp(data_type, 'half')
                    % MATLAB doesn't have a half precision type so use single instead.
                    str_format = '%e';
                    data_type = 'single';
                elseif any(strcmp(data_type, {'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64'}))
                    if isempty(strfind(data, 'NaN'))
                        str_format = '%d';
                    else
                        % The integer types can't handle NaN so we have to use double.
                        % This can occur when the data set view is merging score arrays together that have different sizes.
                        str_format = '%e';
                        integerNaNs = true;
                    end
                elseif length(data_type) > 3 && strcmp(data_type(1:3), 'str') && ~isnan(str2double(data_type(4:end)))
                    str_length = str2double(data_type(4:end));
                    data_type = 'string';
                else
                    error('SAGE:DataSet:Error', ['Cannot decode matrices with type ''' data_type '''']);
                end
                
                data_type_fh = str2func(data_type);
                if nargin == 2
                    if isempty(data)
                        % Return an empty array of the correct type.
                        if strcmp(data_type, 'string')
                            decoded = {};
                        else
                            decoded = data_type_fh([]);
                        end
                    else
                        % Determine the number of rows and columns based on the newlines in the string.
                        rows = length(strfind(data, char(10)));
                        if strcmp(data_type, 'string')
                            cols = numel(data) / rows / (str_length + 1);
                            decoded = reshape(data, str_length + 1, rows * cols)';
                            decoded = cellstr(decoded(:, 1:end-1));  % strip off the separator char
                        else
                            decoded = sscanf(data, str_format);
                            cols = length(decoded) / rows;
                        end
                        if fix(cols) ~= cols
                            error('SAGE:DataSet:Error', 'The data does not represent a full matrix.');
                        end
                        decoded = reshape(decoded, cols, rows)';
                        
                        if ~strcmp(data_type, 'string') && ~strcmp(data_type, 'double') && ~integerNaNs
                            % Convert to the desired data type.
                            decoded = data_type_fh(decoded);
                        end
                    end
                elseif fix(rows) ~= rows || fix(cols) ~= cols
                    error('SAGE:DataSet:Error', 'The number of rows and columns must be specified as integers.');
                else
                    % We have a valid row and column count.
                    if rows == 0 || cols == 0
                        % Return an empty array of the correct type.
                        if strcmp(data_type, 'string')
                            decoded = {};
                        else
                            decoded = data_type_fh([]);
                        end
                    elseif strcmp(data_type, 'string')
                        % For strings reshape the data.
                        if numel(data) ~= rows * cols * (str_length + 1)
                            error('SAGE:DataSet:Error', 'The size of the data does not match the string format and row/column counts.');
                        end
                        decoded = reshape(data, str_length + 1, rows * cols)';
                        decoded = cellstr(decoded(:, 1:end-1));  % strip off the separator char
                        decoded = reshape(decoded, cols, rows)';
                    else
                        % For numerics use sscanf.
                        [decoded, count] = sscanf(data, str_format, [cols, rows]);
                        
                        if count ~= cols * rows
                            error('SAGE:DataSet:Error', 'The data does not match the format and row/column counts.');
                        end
                        
                        decoded = decoded';

                        if ~strcmp(data_type, 'double') && ~integerNaNs
                            % Convert to the desired data type.
                            decoded = data_type_fh(decoded);
                        end
                    end
                end
            end
        end    
    end
    
end
