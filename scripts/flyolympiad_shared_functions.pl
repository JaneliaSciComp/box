use URI::Escape;

sub connect_to_sage {
    my ($config_file) = @_;
    
    open(CONF,"$config_file") || die "Error cant open $config_file, do you have permissions to view this file?\n";
    my $contents;
    while (my $line = <CONF>) {
	$contents .= $line;
    }
    close(CONF);

    my @groups = split(/\n\n/,$contents);

    @database = split(/\n/,$groups[0]);

    unless ($database[0] =~ /Database/) {
	print "Error parsing SAGE DB config $database[0]\n";
	exit(1);
    }

    my $host = $database[1];
    $host =~ s/host = //;
    #print "host:$host\n";
    my $db = $database[2];
    $db =~ s/database = //;
    #print "db:$db\n";
    my $username = $database[3];
    $username =~ s/username = //;
    my $password = $database[4];
    $password =~ s/password = //;
    
    my $dsn = "dbi:mysql:dbname=$db;host=$host;port=3306";

    my $dbh = DBI->connect( $dsn, $username, $password )
    or die("unable to open db handle");

    return($dbh);
}

sub load_experiment_property {
    my ($dbh,$exp_id, $cv, $cv_term, $value) = @_;
    my $sql = "";
    my $cvtermid = get_cv_term_id($dbh,$cv,$cv_term);

    my $exp_p_id = check_experiment_property($dbh,$exp_id,$cvtermid);

    if ($exp_p_id) {
        if ($DEBUG) { print "update $exp_id with $value\n"; }
        update_experiment_property($dbh, $exp_id,  $cvtermid, $value);
    } else {
        if ($DEBUG) { print "insert $exp_id $value\n"; }
        insert_experiment_property($dbh, $exp_id,  $cvtermid, $value);
    }

}

sub insert_score_array {
    my ($dbh, $session_id, $phase_id, $experiment_id, $term_id, $cv_id, $type_id, $value, $run, $data_type, $row_count, $column_count) = @_;
    my $sql = qq~insert into score_array (session_id, phase_id, experiment_id, term_id, cv_id, type_id, value, run, data_type, row_count, column_count)
	value($session_id, $phase_id, $experiment_id, $term_id, $cv_id, $type_id, compress('$value'), $run, '$data_type', $row_count, $column_count)~;
    #print "$sql\n";
    unless($DEBUG) {
        run_mod($dbh,$sql);
    } else {
        print "Insert score_array: $sql\n";
    }
}

sub check_score_array {
    my ($dbh, $session_id, $phase_id, $experiment_id, $cv_id, $type_id) = @_;

    my $sql = "select id from score_array where ";
    if ($session_id eq "NULL") {
        $sql .= "session_id is NULL ";
    } elsif ($session_id eq "") {
        $sql .= "session_id is NULL ";
    } else {
        $sql .= "session_id = $session_id ";
    }

    if ($phase_id eq "NULL") {
        $sql .= "and phase_id is NULL ";
    } elsif ($phase_id eq "") {
        $sql .= "and phase_id is NULL ";
    } else {
        $sql .= "and phase_id = $phase_id ";
    }

    if ($experiment_id eq "NULL") {
        $sql .= "experiment_id is NULL ";
    } elsif ($experiment_id eq "") {
        $sql .= "and experiment_id is NULL ";
    } else {
        $sql .= "and experiment_id = $experiment_id ";
    }

    $sql .= "and type_id = $type_id ";
    $sql .= "and cv_id = $cv_id";

    print "$sql\n" if ($DEBUG);
    my @row = do_sql($dbh,$sql);
    my $score_array_id = $row[0];
    return($score_array_id);
}

sub update_score_array {
    my ($dbh, $score_array_id, $value, $data_type, $row_count, $column_count) = @_;
    my $sql = qq~update score_array set data_type = '$data_type', row_count = $row_count, column_count = $column_count, value = compress('$value'), create_date = now() where id = $score_array_id~;
    #print "$sql\n";
    unless($DEBUG) {
        run_mod($dbh,$sql);
    } else {
        print "Update score_array: $sql\n";
    }
}

sub isNumber {
    my $ss = shift;
    return 1 if $ss =~ /^[+\-]?\d*.?\d+$/;
    return 1 if $ss =~ /^[+\-]?\d*.?\d+e[+\-]?\d+$/i;
    return 0;
}

sub get_cv_id {
    my ($dbh, $cv_name) = @_;
    my $sql = "select id from cv where name = '$cv_name'";
    my @row = do_sql($dbh,$sql);
    my $cv_id = $row[0];
    return($cv_id);
}

sub get_session_id {
    my ($dbh, $exp_id) = @_;
    my $sql = "select id from session where experiment_id = $exp_id";
    my @row = do_sql($dbh,$sql);
    my $session_id = $row[0];
    return($session_id);
}

sub insert_exp_automated_pf {
    my ($dbh,$exp_id, $pf) = @_;
    my $pf_sql = "";
    my $automated_pf_cvtermid = get_cv_term_id($dbh,"fly_olympiad_qc","automated_pf");
    my $exp_p_id = check_experiment_property($dbh,$exp_id,$automated_pf_cvtermid);
    if ($exp_p_id) {
        $pf_sql = "update experiment_property set value = \"$pf\" where id = $exp_p_id";
    } else {
        $pf_sql = "insert into experiment_property (experiment_id, type_id, value) values ($exp_id, $automated_pf_cvtermid, \"$pf\")";
    }

    if ($DEBUG) {
	print "$pf_sql\n";
    } else {
	if ($exp_id) {
	    run_mod($dbh,$pf_sql);
	} else {
	    #print "Experiment ID not found\n";
	}
    }
}

sub insert_exp_manual_pf {
    my ($dbh,$exp_id, $pf) = @_;
    my $pf_sql = "";
    my $manual_pf_cvtermid = get_cv_term_id($dbh,"fly_olympiad_qc","manual_pf");
    my $exp_p_id = check_experiment_property($dbh,$exp_id,$manual_pf_cvtermid);
    if ($exp_p_id) {
	$pf_sql = "update experiment_property set value = \"$pf\" where id = $exp_p_id";
    } else {
	$pf_sql = "insert into experiment_property (experiment_id, type_id, value) values ($exp_id, $manual_pf_cvtermid, \"$pf\")";
    }
    if ($DEBUG) {
        print "$pf_sql\n";
    } else {
        if ($exp_id) {
	    if ($exp_p_id) {
		# pf exists update
		if ($pf ne "U") { 
		    run_mod($dbh,$pf_sql);
		}
	    } else {
		# pf does not exists insert
		run_mod($dbh,$pf_sql);
	    }
	} else {
	    print "Can not load manual pf experiment ID not found\n";
	}
    }
}


sub find_m_file {
    my ($tempdir) = @_;
    my $m_path = "";    
    opendir(TEMPDIR,"$tempdir");
    while (my $out = readdir(TEMPDIR)) {
	chomp($out);
	if ($out =~ /\.m$/) {

	    $m_path = $tempdir . "/" . $out;
	}
    }
    closedir(TEMPDIR);
    return($m_path);
}

sub parse_box_from_exp_name {
    my ($line) = @_;
    my $box_name = "";
    if ($line =~ /(Athena)/) {
        $box_name = $1;
    }
    if ($line =~ /(Apollo)/) {
        $box_name = $1;
    }
    if ($line =~ /(Ares)/) {
        $box_name = $1;
    }
    if ($line =~ /(Orion)/) {
        $box_name = $1;
    }
    if ($line =~ /(Zeus)/) {
        $box_name = $1;
    }
    return($box_name);
}

sub  submit_jira_ticket {
    my ($jira_ticket_params) = @_;

    $browser = $$jira_ticket_params{'lwp_handle'};

    my %stages;
    $stages{"Transfer app"} = 10050;
    $stages{"Metadata loader"} = 10051;
    $stages{"Tube splitter"} = 10052;
    $stages{"SBFMF conversion"} = 10053;
    $stages{"Fly tracking"} = 10054;
    $stages{"Tracking loader"} = 10055;
    $stages{"AVI compression"} = 10533;
    $stages{"Archiving"} = 10720;

    my %box_names;
    $box_names{"Apollo"} = 10001;
    $box_names{"Ares"} =   10004;
    $box_names{"Athena"} = 10000;
    $box_names{"Orion"} =  10003;
    $box_names{"Zeus"} =   10002;

    #my $jira_url = "http://issuetracker/jira/secure/CreateIssueDetails.jspa?";
    #my $jira_url = "http://issuetracker/issuetracker/secure/CreateIssueDetails.jspa?";
    my $jira_url = "http://issuetracker/secure/CreateIssueDetails.jspa?";

    if ($$jira_ticket_params{'jira_project_pid'}) {
        $jira_url .= "pid=$$jira_ticket_params{'jira_project_pid'}";
    } else {
        print "No PID given, will not submit Jira ticket\n";
        return(0);
    }

    if ($$jira_ticket_params{'issue_type_id'}) {
        $jira_url .= "&issuetype=$$jira_ticket_params{'issue_type_id'}";
    }

    if ($$jira_ticket_params{'summary'}) {
        my $summary = $$jira_ticket_params{'summary'};
        $summary =~ s/\n/\%0A/g;
        $summary =~ s/\s/\+/g;
        $summary =~ s/\;/\%3B/g;
        $jira_url .= "&summary=$summary";
    }

    if ($$jira_ticket_params{'description'}) {
        my $description = uri_escape($$jira_ticket_params{'description'});
#        $description =~ s/\n/\%0A/g;
#        $description =~ s/\s/\+/g;
#        $description =~ s/\;/\%3B/g;
        $jira_url .= "&description=$description";
    }

    if ($$jira_ticket_params{'labels'}) {
        my $labels = $$jira_ticket_params{'labels'};
        $labels =~ s/\n/\%0A/g;
        $labels =~ s/\s/\+/g;
        $labels =~ s/\;/\%3B/g;
	$labels =~ s/\_/\%5F/g;
        $jira_url .= "&labels=$labels";
    }

    if ($$jira_ticket_params{'box_name'}) {
	my $box_name = $$jira_ticket_params{'box_name'};
	my $box_id = $box_names{$box_name};
        #$jira_url .= "&customfield_10000=$$jira_ticket_params{'box_name'}";
	$jira_url .= "&customfield_10000=$box_id";
    }

    if ($$jira_ticket_params{'line_name'}) {
        my $line_name = $$jira_ticket_params{'line_name'};
        $line_name =~ s/\s/\+/g;
        $line_name =~ s/\;/\%3B/g;
        $line_name =~ s/\//\%2F/g;
        $jira_url .= "&customfield_10001=$line_name";
    }

    if ($$jira_ticket_params{'file_path'}) {
        my $file_path = $$jira_ticket_params{'file_path'};
        $file_path =~ s/\//\%2F/g;
        $file_path =~ s/\s/\+/g;
        $jira_url .= "&customfield_10002=$file_path";
    }

    if ($$jira_ticket_params{'error_type'} ) {
        $jira_url .= "&customfield_10003=$$jira_ticket_params{'error_type'}";
    }

    if ($$jira_ticket_params{'stage'} ) {
        my $stage = $$jira_ticket_params{'stage'};
        my $stage_id = $stages{$stage};
        $jira_url .= "&components=$stage_id";
    }

    print "Jira URL: $jira_url\n" if ($DEBUG);
    unless($DEBUG) {
	print "$jira_url\n";
	my $response = $browser->get($jira_url);
	unless ($response->is_success) {
	    print "Can't get $jira_url -- \n";
	}
    }
}

sub do_sql {
    my($dbh,$query,$delimeter) = @_;
    my($statementHandle,@x,@results);
    my(@row);

    if($delimeter eq "") {
        $delimeter = "\t"; # define a delimiter between each element in a row.
    }

    $statementHandle = $dbh->prepare($query); # prepare query
    if ( !defined $statementHandle) {
        print "Cannot prepare statement: $DBI::errstr\n"; # error in db connection
    }

    $statementHandle->execute() || print "failed query: $query\n"; #execute query

    while ( @row = $statementHandle->fetchrow() ) { # while query runs, @row is assigned
        push(@results,join($delimeter,@row)); # join contents of row with delimiter
    }

    #release the statement handle resources
    $statementHandle->finish;
    return(@results); #query results
}

sub check_sage_line_name {
    my ($dbh,$line_name) = @_;
    if ($line_name) {
        my $uppername = uc($line_name);
        my $sql = "select id from line_vw where UPPER(name) = '$uppername'";
        #print "$sql\n";
        my @result = do_sql($dbh,$sql);
        #print "R: $result[0]\n";
        return($result[0]);
    } else {
        return(0);
    }

}

sub getboxnamefromseqdetails {
    my ($filepath) = @_;
    my $m_box_name = "";
    open(IN,"$filepath");  #|| print "cant open $filepath\n";
    while (my $line = <IN>) {
        chomp($line);
        if ($line =~ /BoxName \=/) {
            $line =~ /\'(.+)\'/;
            $m_box_name = $1;
        }
    }
    return($m_box_name);

}

sub getlinefromseqdetails {
    my ($dbh,$filepath) = @_;
    my $line_not_in_sage = 0;
    my $effector_missing = 0;
    open(IN,"$filepath");  #|| print "cant open $filepath\n";
    my $line_name;
    my $junk;
    while (my $line = <IN>) {
        chomp($line);

	if ($line =~ /\.Line/) {
	    $line =~ /\'(.+)\'/;
	    #print "line: $1\n";
	    $line_name = $1;
	    if ($line_name) {
		my $id = 0;
                $id = check_sage_line_name($dbh,$line_name);
                unless($id) {
                    $line_not_in_sage++;
		}
	    }
	}

	if ($line =~ /\.Effector/) {
	    $line =~ /\'(.+)\'/;
	    $effector = $1;
            #print "effector: $1\n";
	    unless($effector) {
                $effector_missing++;
	    }
	} 

    }
    close(IN);
 
    print "check: $line_not_in_sage,$effector_missing,$line_name\n" if ($DEBUG);
    return($line_not_in_sage,$effector_missing,$line_name);
}

sub run_mod {
    my($dbproc,$query) = @_;
    my($statementHandle,$result);
    
    $statementHandle = $dbproc->prepare($query); # prepare query
    if ( !defined $statementHandle) {
        print "Cannot prepare statement: $DBI::errstr\n";
    }
    $statementHandle->execute(); # execute query
    #$dbproc->commit; # commit query
    $statementHandle->finish;

    return($result);
}

sub get_cv_term_id {
    my ($dbh, $cv, $cvterm) = @_;
    my $sql = "select id from cv_term where id = getCvTermId('$cv', '$cvterm', NULL) ";
    my @row = do_sql($dbh,$sql);
    my $term_id = $row[0];
    return($term_id);
}

sub check_session_property {
    my ($dbh, $session_id, $type_id) = @_;
    my $sql = "select id from session_property where session_id = $session_id and type_id = $type_id";
    my @row = do_sql($dbh,$sql);
    my $session_id = $row[0];
    return($session_id);
}

sub insert_session_property {
    my ($dbh, $session_id, $type_id, $value) = @_;
    my $sql = "insert into session_property (session_id,type_id,value) values($session_id, $type_id, '$value')";
    unless($DEBUG) {
        run_mod($dbh,$sql);
    } else {
        print "Update: $sql\n";
    }
}

sub update_session_property {
    my ($dbh, $session_prop_id, $type_id, $value) = @_;
    my $sql = "update session_property set value = '$value' where id = $session_prop_id and type_id = $type_id";
    unless($DEBUG) {
        run_mod($dbh,$sql);
    } else {
        print "Update: $sql\n";
    }
}

sub check_score {
    my ($dbh, $session_id, $phase_id, $exp_id, $type_id) = @_;
    my $sql = "select id from score where ";

    if ($session_id eq "NULL") {
        $sql .= "session_id is NULL ";
    } elsif ($session_id eq "") {
        $sql .= "session_id is NULL ";
    } else {
        $sql .= "session_id = $session_id ";
    }

    if ($phase_id eq "NULL") {
        $sql .= "and phase_id is NULL ";
    } elsif ($phase_id eq "") {
        $sql .= "and phase_id is NULL ";
    } else {
        $sql .= "and phase_id = $phase_id ";
    }

    if ($exp_id eq "NULL") {
        $sql .= "experiment_id is NULL ";
    } elsif ($exp_id eq "") {
        $sql .= "and experiment_id is NULL ";
    } else {
        $sql .= "and experiment_id = $exp_id ";
    }

    $sql .= "and type_id = $type_id";

    #print "Check: $sql\n";
    my @row = do_sql($dbh,$sql);
    my $score_id = $row[0];
    return($score_id);
}

sub insert_score {
    my ($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $value, $run) = @_;
    my $sql = "insert into score (session_id,phase_id,experiment_id,term_id,type_id,value,run) values ($session_id,$phase_id,$exp_id,$term_id,$type_id,'$value',$run)";

    unless($DEBUG) {
	run_mod($dbh,$sql);
    } else {
	print "Insert: $sql\n";
    }
}

sub update_score {
    my ($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $value, $run, $score_id) = @_;
    my $sql;

    if ($score_id) {
	$sql = "update score set value = '$value', create_date = now() where id = $score_id";
    } else {
	$sql = "update score set value = '$value', create_date = now() where session_id = $session_id and phase_id = $phase_id and experiment_id = $exp_id and type_id = $type_id";
    }
    unless($DEBUG) {
	run_mod($dbh,$sql);
    } else {
        print "Update: $sql\n";
    }
}


sub check_experiment_property {
    my ($dbh, $exp_id, $type_id) = @_;
    my $sql = "select id from experiment_property where experiment_id = $exp_id and type_id = $type_id";
    #print "Check: $sql\n";
    my @row = do_sql($dbh,$sql);
    my $score_id = $row[0];
    return($score_id);
}

sub insert_experiment_property {
    my ($dbh, $exp_id,  $type_id, $value) = @_;
    my $sql = "insert into experiment_property (experiment_id,type_id,value) values ($exp_id,$type_id,'$value')";
    #print "Insert: $sql\n";
    unless($DEBUG) {
	run_mod($dbh,$sql);
    }
}

sub get_experiment_property_val {
    my ($dbh, $exp_id, $cv, $cv_term) = @_;
    my $cvtermid = get_cv_term_id($dbh,$cv,$cv_term);
    my $sql = "select id, value from experiment_property where experiment_id = $exp_id and type_id = $cvtermid";
    my @row = do_sql($dbh,$sql);
    my ($id,$val) = split(/\t/,$row[0]);
    return($id, $val);
}

sub get_experiment_property {
    my ($dbh, $exp_id, $type_id) = @_;
    my $sql = "select id, value from experiment_property where experiment_id = $exp_id and type_id = $type_id";
    my @row = do_sql($dbh,$sql);
    my ($id,$val) = split(/\t/,$row[0]);
    return($id, $val);
}

sub update_experiment_property {
    my ($dbh, $exp_id, $type_id, $value) = @_;
    my $sql = "update experiment_property set value = '$value', create_date = now() where experiment_id = $exp_id and type_id = $type_id";
    #print "Update: $sql\n";
    unless($DEBUG) {
	run_mod($dbh,$sql);
    }
}

sub get_experiment_id {
    my ($dbh,$exp_name) = @_;
    my $sql = "select id from experiment where name like '%$exp_name%'";
    my @row = do_sql($dbh,$sql);
    my $exp_id = $row[0];
    return($exp_id);    

}

sub get_experiment_name {
    my ($dbh,$exp_id) = @_;
    my $sql = "select name from experiment where id = $exp_id";
    my @row = do_sql($dbh,$sql);
    my $exp_name = $row[0];
    return($exp_name);
}

sub get_protocols {
    my %protocols = ();
    $protocols{"3.0"}->{'sequences'} = 5;
    $protocols{"3.0"}->{'temp_dir_number'} = 2;
    $protocols{"3.0"}->{'tube_dir_number'} = 30;
    $protocols{"3.0"}->{'tube_avi_number'} = 30;
    $protocols{"3.0"}->{'track_files'} = 60;
    $protocols{"3.0"}->{'failure'} = 0;
    $protocols{"3.0"}->{'errorcode'} = 1;
    $protocols{"3.0"}->{'cool_max_var'} = 2;
    $protocols{"3.0"}->{'hot_max_var'} = 2;
    $protocols{"3.0"}->{'transition_duration'} = 10;
    $protocols{"3.0"}->{'questionable_data'} = 0;
    $protocols{"3.0"}->{'total_duration_seconds'} = 3605;
    $protocols{"3.0"}->{'force_seq_start'} = 0;
    $protocols{"3.0"}->{'halt_early'} = 0;
    $protocols{"3.0"}->{'analysisinfo_files'} = 10;
    $protocols{"3.0"}->{'tube_sbfmf_number'} = 5;
    $protocols{"3.0"}->{'sbfmf_stat_num'} = 360;
    $protocols{"3.0"}->{'sbfmf_dir_num'} = 12;

    $protocols{"3.1"}->{'sequences'} = 5;
    $protocols{"3.1"}->{'temp_dir_number'} = 2;
    $protocols{"3.1"}->{'tube_dir_number'} = 30;
    $protocols{"3.1"}->{'tube_avi_number'} = 30;
    $protocols{"3.1"}->{'track_files'} = 60;
    $protocols{"3.1"}->{'failure'} = 0;
    $protocols{"3.1"}->{'errorcode'} = 1;
    $protocols{"3.1"}->{'cool_max_var'} = 2;
    $protocols{"3.1"}->{'hot_max_var'} = 2;
    $protocols{"3.1"}->{'transition_duration'} = 10;
    $protocols{"3.1"}->{'questionable_data'} = 0;
    $protocols{"3.1"}->{'total_duration_seconds'} = 3605;
    $protocols{"3.1"}->{'force_seq_start'} = 0;
    $protocols{"3.1"}->{'halt_early'} = 0;
    $protocols{"3.1"}->{'analysisinfo_files'} = 10;
    $protocols{"3.1"}->{'tube_sbfmf_number'} = 5;
    $protocols{"3.1"}->{'sbfmf_stat_num'} = 360;
    $protocols{"3.1"}->{'sbfmf_dir_num'} = 12;

    $protocols{"3.2"}->{'sequences'} = 5;
    $protocols{"3.2"}->{'temp_dir_number'} = 2;
    $protocols{"3.2"}->{'tube_dir_number'} = 30;
    $protocols{"3.2"}->{'tube_avi_number'} = 30;
    $protocols{"3.2"}->{'track_files'} = 60;
    $protocols{"3.2"}->{'failure'} = 0;
    $protocols{"3.2"}->{'errorcode'} = 1;
    $protocols{"3.2"}->{'cool_max_var'} = 2;
    $protocols{"3.2"}->{'hot_max_var'} = 2;
    $protocols{"3.2"}->{'transition_duration'} = 10;
    $protocols{"3.2"}->{'questionable_data'} = 0;
    $protocols{"3.2"}->{'total_duration_seconds'} = 3605;
    $protocols{"3.2"}->{'force_seq_start'} = 0;
    $protocols{"3.2"}->{'halt_early'} = 0;
    $protocols{"3.2"}->{'analysisinfo_files'} = 10;
    $protocols{"3.2"}->{'tube_sbfmf_number'} = 5;
    $protocols{"3.2"}->{'sbfmf_stat_num'} = 360;
    $protocols{"3.2"}->{'sbfmf_dir_num'} = 12;

    $protocols{"3.3"}->{'sequences'} = 5;
    $protocols{"3.3"}->{'temp_dir_number'} = 2;
    $protocols{"3.3"}->{'tube_dir_number'} = 30;
    $protocols{"3.3"}->{'tube_avi_number'} = 30;
    $protocols{"3.3"}->{'track_files'} = 60;
    $protocols{"3.3"}->{'failure'} = 0;
    $protocols{"3.3"}->{'errorcode'} = 1;
    $protocols{"3.3"}->{'cool_max_var'} = 2;
    $protocols{"3.3"}->{'hot_max_var'} = 2;
    $protocols{"3.3"}->{'transition_duration'} = 10;
    $protocols{"3.3"}->{'questionable_data'} = 0;
    $protocols{"3.3"}->{'total_duration_seconds'} = 4000;
    $protocols{"3.3"}->{'force_seq_start'} = 0;
    $protocols{"3.3"}->{'halt_early'} = 0;
    $protocols{"3.3"}->{'analysisinfo_files'} = 10;
    $protocols{"3.3"}->{'tube_sbfmf_number'} = 5;
    $protocols{"3.3"}->{'sbfmf_stat_num'} = 360;
    $protocols{"3.3"}->{'sbfmf_dir_num'} = 12;

    $protocols{"4.0"}->{'sequences'} = 5;
    $protocols{"4.0"}->{'temp_dir_number'} = 1;
    $protocols{"4.0"}->{'tube_dir_number'} = 30;
    $protocols{"4.0"}->{'tube_avi_number'} = 30;
    $protocols{"4.0"}->{'track_files'} = 30;
    $protocols{"4.0"}->{'failure'} = 0;
    $protocols{"4.0"}->{'errorcode'} = 1;
    $protocols{"4.0"}->{'cool_max_var'} = 2;
    $protocols{"4.0"}->{'hot_max_var'} = 2;
    $protocols{"4.0"}->{'transition_duration'} = 0;
    $protocols{"4.0"}->{'questionable_data'} = 0;
    $protocols{"4.0"}->{'total_duration_seconds'} = 1805;
    $protocols{"4.0"}->{'force_seq_start'} = 0;
    $protocols{"4.0"}->{'halt_early'} = 0;
    $protocols{"4.0"}->{'analysisinfo_files'} = 5;
    $protocols{"4.0"}->{'tube_sbfmf_number'} = 5;
    $protocols{"4.0"}->{'sbfmf_stat_num'} = 180;
    $protocols{"4.0"}->{'sbfmf_dir_num'} = 6;

    $protocols{"4.1"}->{'sequences'} = 5;
    $protocols{"4.1"}->{'temp_dir_number'} = 1;
    $protocols{"4.1"}->{'tube_dir_number'} = 30;
    $protocols{"4.1"}->{'tube_avi_number'} = 30;
    $protocols{"4.1"}->{'track_files'} = 30;
    $protocols{"4.1"}->{'failure'} = 0;
    $protocols{"4.1"}->{'errorcode'} = 1;
    $protocols{"4.1"}->{'cool_max_var'} = 2;
    $protocols{"4.1"}->{'hot_max_var'} = 2;
    $protocols{"4.1"}->{'transition_duration'} = 0;
    $protocols{"4.1"}->{'questionable_data'} = 0;
    $protocols{"4.1"}->{'total_duration_seconds'} = 1805;
    $protocols{"4.1"}->{'force_seq_start'} = 0;
    $protocols{"4.1"}->{'halt_early'} = 0;
    $protocols{"4.1"}->{'analysisinfo_files'} = 5;
    $protocols{"4.1"}->{'tube_sbfmf_number'} = 5;
    $protocols{"4.1"}->{'sbfmf_stat_num'} = 180;
    $protocols{"4.1"}->{'sbfmf_dir_num'} = 6;

    $protocols{"4.2"}->{'sequences'} = 5;
    $protocols{"4.2"}->{'temp_dir_number'} = 1;
    $protocols{"4.2"}->{'tube_dir_number'} = 30;
    $protocols{"4.2"}->{'tube_avi_number'} = 30;
    $protocols{"4.2"}->{'track_files'} = 30;
    $protocols{"4.2"}->{'failure'} = 0;
    $protocols{"4.2"}->{'errorcode'} = 1;
    $protocols{"4.2"}->{'cool_max_var'} = 2;
    $protocols{"4.2"}->{'hot_max_var'} = 2;
    $protocols{"4.2"}->{'transition_duration'} = 0;
    $protocols{"4.2"}->{'questionable_data'} = 0;
    $protocols{"4.2"}->{'total_duration_seconds'} = 1805;
    $protocols{"4.2"}->{'force_seq_start'} = 0;
    $protocols{"4.2"}->{'halt_early'} = 0;
    $protocols{"4.2"}->{'analysisinfo_files'} = 5;
    $protocols{"4.2"}->{'tube_sbfmf_number'} = 5;
    $protocols{"4.2"}->{'sbfmf_stat_num'} = 180;
    $protocols{"4.2"}->{'sbfmf_dir_num'} = 6;

    $protocols{"5.0"}->{'sequences'} = 5;
    $protocols{"5.0"}->{'temp_dir_number'} = 1;
    $protocols{"5.0"}->{'tube_dir_number'} = 30;
    $protocols{"5.0"}->{'tube_avi_number'} = 30;
    $protocols{"5.0"}->{'track_files'} = 60;
    $protocols{"5.0"}->{'failure'} = 0;
    $protocols{"5.0"}->{'errorcode'} = 1;
    $protocols{"5.0"}->{'cool_max_var'} = 2;
    $protocols{"5.0"}->{'hot_max_var'} = 2;
    $protocols{"5.0"}->{'transition_duration'} = 10;
    $protocols{"5.0"}->{'questionable_data'} = 0;
    $protocols{"5.0"}->{'total_duration_seconds'} = 1805;
    $protocols{"5.0"}->{'force_seq_start'} = 0;
    $protocols{"5.0"}->{'halt_early'} = 0;
    $protocols{"5.0"}->{'analysisinfo_files'} = 10;
    $protocols{"5.0"}->{'tube_sbfmf_number'} = 5;
    $protocols{"5.0"}->{'sbfmf_stat_num'} = 360;
    $protocols{"5.0"}->{'sbfmf_dir_num'} = 12;

#    $protocols{"5.21"}->{'sequences'} = 6;
#    $protocols{"5.21"}->{'temp_dir_number'} = 1;
#    $protocols{"5.21"}->{'tube_dir_number'} = 36;
#    $protocols{"5.21"}->{'tube_avi_number'} = 36;
#    $protocols{"5.21"}->{'track_files'} = 72;
#    $protocols{"5.21"}->{'failure'} = 0;
#    $protocols{"5.21"}->{'errorcode'} = 1;
#    $protocols{"5.21"}->{'cool_max_var'} = 2;
#    $protocols{"5.21"}->{'hot_max_var'} = 2;
#    $protocols{"5.21"}->{'transition_duration'} = 10;
#    $protocols{"5.21"}->{'questionable_data'} = 0;
#    $protocols{"5.21"}->{'total_duration_seconds'} = 1805;
#    $protocols{"5.21"}->{'force_seq_start'} = 0;
#    $protocols{"5.21"}->{'halt_early'} = 0;
#    $protocols{"5.21"}->{'analysisinfo_files'} = 6;
#    $protocols{"5.21"}->{'tube_sbfmf_number'} = 6;
#    $protocols{"5.21"}->{'sbfmf_stat_num'} = 216;
#    $protocols{"5.21"}->{'sbfmf_dir_num'} = 6;

    $protocols{"9.0"}->{'sequences'} = 5;
    $protocols{"9.0"}->{'temp_dir_number'} = 1;
    $protocols{"9.0"}->{'tube_dir_number'} = 30;
    $protocols{"9.0"}->{'tube_avi_number'} = 30;
    $protocols{"9.0"}->{'track_files'} = 30;
    $protocols{"9.0"}->{'failure'} = 0;
    $protocols{"9.0"}->{'errorcode'} = 1;
    $protocols{"9.0"}->{'cool_max_var'} = 2;
    $protocols{"9.0"}->{'hot_max_var'} = 2;
    $protocols{"9.0"}->{'transition_duration'} = 0;
    $protocols{"9.0"}->{'questionable_data'} = 0;
    $protocols{"9.0"}->{'total_duration_seconds'} = 1805;
    $protocols{"9.0"}->{'force_seq_start'} = 0;
    $protocols{"9.0"}->{'halt_early'} = 0;
    $protocols{"9.0"}->{'analysisinfo_files'} = 5;
    $protocols{"9.0"}->{'tube_sbfmf_number'} = 5;
    $protocols{"9.0"}->{'sbfmf_stat_num'} = 180;
    $protocols{"9.0"}->{'sbfmf_dir_num'} = 6;

    $protocols{"9.1"}->{'sequences'} = 5;
    $protocols{"9.1"}->{'temp_dir_number'} = 1;
    $protocols{"9.1"}->{'tube_dir_number'} = 30;
    $protocols{"9.1"}->{'tube_avi_number'} = 30;
    $protocols{"9.1"}->{'track_files'} = 30;
    $protocols{"9.1"}->{'failure'} = 0;
    $protocols{"9.1"}->{'errorcode'} = 1;
    $protocols{"9.1"}->{'cool_max_var'} = 2;
    $protocols{"9.1"}->{'hot_max_var'} = 2;
    $protocols{"9.1"}->{'transition_duration'} = 0;
    $protocols{"9.1"}->{'questionable_data'} = 0;
    $protocols{"9.1"}->{'total_duration_seconds'} = 1805;
    $protocols{"9.1"}->{'force_seq_start'} = 0;
    $protocols{"9.1"}->{'halt_early'} = 0;
    $protocols{"9.1"}->{'analysisinfo_files'} = 5;
    $protocols{"9.1"}->{'tube_sbfmf_number'} = 5;
    $protocols{"9.1"}->{'sbfmf_stat_num'} = 180;
    $protocols{"9.1"}->{'sbfmf_dir_num'} = 6;

    $protocols{"9.5"}->{'sequences'} = 5;
    $protocols{"9.5"}->{'temp_dir_number'} = 1;
    $protocols{"9.5"}->{'tube_dir_number'} = 30;
    $protocols{"9.5"}->{'tube_avi_number'} = 30;
    $protocols{"9.5"}->{'track_files'} = 30;
    $protocols{"9.5"}->{'failure'} = 0;
    $protocols{"9.5"}->{'errorcode'} = 1;
    $protocols{"9.5"}->{'cool_max_var'} = 2;
    $protocols{"9.5"}->{'hot_max_var'} = 2;
    $protocols{"9.5"}->{'transition_duration'} = 0;
    $protocols{"9.5"}->{'questionable_data'} = 0;
    $protocols{"9.5"}->{'total_duration_seconds'} = 1805;
    $protocols{"9.5"}->{'force_seq_start'} = 0;
    $protocols{"9.5"}->{'halt_early'} = 0;
    $protocols{"9.5"}->{'analysisinfo_files'} = 5;
    $protocols{"9.5"}->{'tube_sbfmf_number'} = 5;
    $protocols{"9.5"}->{'sbfmf_stat_num'} = 180;
    $protocols{"9.5"}->{'sbfmf_dir_num'} = 6;

    $protocols{"9.6"}->{'sequences'} = 5;
    $protocols{"9.6"}->{'temp_dir_number'} = 1;
    $protocols{"9.6"}->{'tube_dir_number'} = 30;
    $protocols{"9.6"}->{'tube_avi_number'} = 30;
    $protocols{"9.6"}->{'track_files'} = 30;
    $protocols{"9.6"}->{'failure'} = 0;
    $protocols{"9.6"}->{'errorcode'} = 1;
    $protocols{"9.6"}->{'cool_max_var'} = 2;
    $protocols{"9.6"}->{'hot_max_var'} = 2;
    $protocols{"9.6"}->{'transition_duration'} = 0;
    $protocols{"9.6"}->{'questionable_data'} = 0;
    $protocols{"9.6"}->{'total_duration_seconds'} = 1805;
    $protocols{"9.6"}->{'force_seq_start'} = 0;
    $protocols{"9.6"}->{'halt_early'} = 0;
    $protocols{"9.6"}->{'analysisinfo_files'} = 5;
    $protocols{"9.6"}->{'tube_sbfmf_number'} = 5;
    $protocols{"9.6"}->{'sbfmf_stat_num'} = 180;
    $protocols{"9.6"}->{'sbfmf_dir_num'} = 6;

    $protocols{"10.2"}->{'sequences'} = 5;
    $protocols{"10.2"}->{'temp_dir_number'} = 1;
    $protocols{"10.2"}->{'tube_dir_number'} = 30;
    $protocols{"10.2"}->{'tube_avi_number'} = 30;
    $protocols{"10.2"}->{'track_files'} = 30;
    $protocols{"10.2"}->{'failure'} = 0;
    $protocols{"10.2"}->{'errorcode'} = 1;
    $protocols{"10.2"}->{'cool_max_var'} = 2;
    $protocols{"10.2"}->{'hot_max_var'} = 3;
    $protocols{"10.2"}->{'transition_duration'} = 0;
    $protocols{"10.2"}->{'questionable_data'} = 0;
    $protocols{"10.2"}->{'total_duration_seconds'} = 2305;
    $protocols{"10.2"}->{'force_seq_start'} = 0;
    $protocols{"10.2"}->{'halt_early'} = 0;
    $protocols{"10.2"}->{'analysisinfo_files'} = 5;
    $protocols{"10.2"}->{'tube_sbfmf_number'} = 5;
    $protocols{"10.2"}->{'sbfmf_stat_num'} = 180;
    $protocols{"10.2"}->{'sbfmf_dir_num'} = 6;

    return(\%protocols);
}

# ****************************************************************************
# * send_email
# ****************************************************************************

=head2 send_email

  Title:       send_email
  Usage:       send_email($to_email, $from_email, $subject, $message);

Description: Function that will prepare and send email notification.
$to_email = email address you want to send the message to.
$from_email = notify the recepient who sent the email.
$subject = what is to be displayed in the subject line of the email.
$message = the email message to be sent.
=cut

sub send_email {
    my ($to_email, $from_email, $subject, $message, $cc, $bcc) = @_;
    #required;
    
    my %mail = (smtp => 'smtp.janelia.priv',
		to => $to_email,
		from => $from_email,
		subject => $subject,
		message => $message
		);
    # optional
    if ($cc) {
        $mail{'cc'} = $cc;
    }
    
    if ($bcc) {
        $mail{'bcc'} = $bcc;
    }
    
    if (sendmail(%mail)) {
        print "email notification sent to $to_email.\n";
    } else {
        print "Error sending mail: $Mail::Sendmail::error\n";
        print "Log $Mail::Sendmail::log\n";
    }
}
1;
