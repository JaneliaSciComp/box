#!/usr/bin/env perl

# Libraries
use lib '/usr/local/perl5/lib/perl5/site_perl/5.8.5';
use lib '/usr/local/perl5/lib64/perl5/site_perl/5.8.5/x86_64-linux-thread-multi';

# Perl built-ins
use strict;
use warnings;
use DBI;
use File::Basename;
use Getopt::Long;
use Image::ExifTool;
use Image::Size;
use IO::File;
use IO::Select;
use Parse::RecDescent;
use Pod::Text;
use Pod::Usage;
use Switch;
use Time::HiRes qw(gettimeofday);
use URI::Escape;
use XML::Simple;

# JFRC
use JFRC::LDAP;
use JFRC::Utils::Plate;
use Zeiss::LSM;

# ****************************************************************************
# * Environment-dependent                                                    *
# ****************************************************************************
# Change this on foreign installation
use constant DATA_PATH => '/opt/informatics/data/';
# Image properties to save when reloading - these are properties that are
# set using the transmogrifier
my %SAVE_PROPERTY = (rubin => [qw(uas_reporter class created_by renamed_by
                                  ihc_batch qi qm)],
                     baker => [qw(chron_interval genotype heat_shock_hour
                                  heat_shock_interval)]);

# ****************************************************************************
# * Global variables                                                         *
# ****************************************************************************
# Command-line parameters
my $LAB = '';
my $ANNOTATION = 'dbi:mysql:dbname=annotation;host=';
my $CHACRM = 'dbi:Pg:dbname=chacrm;host=chacrm-db.int.janelia.org';
my $NIGHTHAWK = 'dbi:mysql:dbname=nighthawk;host=';
my $WIP = 'dbi:mysql:dbname=wip;host=';
my ($DEBUG,$DEV,$RELOAD,$TEST,$VERBOSE) = (0)x5;
# User name
my $username;
# XML
my %MAPPING;
# Database and file handles
my ($dbh,$dbha,$dbhc,$dbhw,$handle);
# Parser
my %grammar;
my ($grammar_file,$parser) = ('')x2;
# Counters
my (%counter,%profile);
# SQL statements
my %sth = (
CDATE => 'UPDATE image SET capture_date=? WHERE id=?',
DELETE => 'DELETE FROM image WHERE id=?',
PRESENT => 'SELECT id FROM image WHERE name=? AND family=?',
PROPPRESENT => 'SELECT DISTINCT(type) FROM image_property WHERE image_id=?',
GETPROP => 'SELECT value FROM image_property WHERE image_id=? AND type=?',
SECPRESENT => 'SELECT id FROM secondary_image WHERE name=? AND image_id=?',
IMAGE => 'INSERT INTO image (name,family,capture_date,representative) '
         . 'VALUES (?,?,?,?)',
SECIMAGE => 'INSERT INTO secondary_image (name,product,image_id,location,url) VALUES (?,?,?,?,?)',
PROPERTY => 'INSERT INTO image_property (image_id,type,value) VALUES (?,?,?)',
LASER => 'INSERT INTO laser (image_id,name,power) VALUES (?,?,?)',
);
my %stha = (
LINE => 'SELECT id FROM line WHERE name=? AND lab=?',
ILINE => 'INSERT INTO line (name,lab,gene) VALUES (?,?,?)',
);
my %sthc = (
CG => 'SELECT annotation_symbol FROM feature_annotation_symbol fas,'
      . "featurepropt fp WHERE type='rearray_location' AND value=? AND "
      . 'fas.feature_id=fp.feature_id',
DISSECTOR => 'SELECT userid,timelastmodified FROM transformant_status_history '
             . "WHERE status='dissected' AND name=? AND timelastmodified<? "
             . 'ORDER BY timelastmodified DESC LIMIT 1',
GENE => 'SELECT name FROM gene_synonym WHERE key=?',
REPRESENTATIVE => 'SELECT COUNT(1) FROM featurepropt WHERE value=? AND '
                  . "type like 'representative_%'",
);
my %sthw = (
MOUNTER => 'SELECT operator,e.create_date FROM line l JOIN event e ON '
           . "(l.id=e.line_id) WHERE name=? AND e.process='Mounting' AND "
           . "action='out' AND e.create_date>? ORDER BY e.create_date LIMIT 1",
);


# ****************************************************************************
# * Subroutine:  terminateProgram                                            *
# * Description: This routine will gracefully terminate the program. If a    *
# *              message is passed in, we exit with a code of -1. Otherwise, *
# *              we exit with a code of 0.                                   *
# *                                                                          *
# * Parameters:  message: the error message to print                         *
# * Returns:     NONE                                                        *
# ****************************************************************************
sub terminateProgram
{
  my $message = shift;
  print { $handle || \*STDERR } "$message\n" if ($message);
  $handle->close if ($handle);
  ref($sth{$_}) && $sth{$_}->finish foreach (keys %sth);
  ref($stha{$_}) && $stha{$_}->finish foreach (keys %stha);
  ref($sthc{$_}) && $sthc{$_}->finish foreach (keys %sthc);
  ref($sthw{$_}) && $sthw{$_}->finish foreach (keys %sthw);
  $dbh->disconnect if ($dbh);
  $dbha->disconnect if ($dbha);
  $dbhc->disconnect if ($dbhc);
  $dbhw->disconnect if ($dbhw);
  exit(($message) ? -1 : 0);
}


# ****************************************************************************
# * Subroutine:  configure_xml                                               *
# * Description: This routine will initialize global variables using the XML *
# *              configuration file.                                         *
# *                                                                          *
# * Parameters:  NONE                                                        *
# * Returns:     NONE                                                        *
# ****************************************************************************
sub configureXML
{
my $p;
  eval {
    $p = XMLin(DATA_PATH . 'terms.xml',KeyAttr => 'value');
  };
  ($@) && &terminateProgram($@);
  foreach my $k (keys %$p) {
    %{$MAPPING{$k}} = map { $_ => $p->{$k}{$_}{displayName} }
                          keys %{$p->{$k}};
  }
}


# ****************************************************************************
# * Subroutine:  initializeProgram                                           *
# * Description: This routine will initialize the program. The following     *
# *              steps are taken:                                            *
# *              1) Ensure that the user has privileges to modify the        *
# *                 image database.                                          *
# *              2) Configure XML                                            *
# *              3) Connect to all databases and prepare statements for      *
# *                 execution. Statements in the %sth, %stha, %sthc, and     *
# *                 %sthw  global hashes will be replaced with statement     *
# *                 handles.                                                 *
# *              4) Initialize a recursive descent parser                    *
# *                                                                          *
# * Parameters:  NONE                                                        *
# * Returns:     NONE                                                        *
# ****************************************************************************
sub initializeProgram
{
  my $service = JFRC::LDAP->new()
    || &terminateProgram("Could not initialize connection to LDAP");
  my $login = getlogin || getpwuid($<)
    || &terminateProgram('Could not determine username');
  my $user = $service->getUser($login)
    || &terminateProgram("User $login does not exist");
# PLUG
#  my $role = $service->getRole('prioritize','ChaCRM');
#  &terminateProgram("User $login does not have authorization to change CRM "
#                    . 'priorities') unless ($role->doesUserPlayRole($user));
  $username = join(' ',$user->givenName(),$user->sn());
  # XML
  &configureXML();
  # Database handles
  $NIGHTHAWK .= ($DEV) ? 'db-dev' : 'mysql2';
  $ANNOTATION .= ($DEV) ? 'db-dev' : 'mysql2';
  $WIP .= ($DEV) ? 'db-dev' : 'mysql2';
  $dbh = DBI->connect($NIGHTHAWK,('nighthawkApp')x2)
    || &terminateProgram("Could not connect to $NIGHTHAWK");
  $dbh->{'AutoCommit'} = 0;
  $dbha = DBI->connect($ANNOTATION,('annotationApp')x2)
    || &terminateProgram("Could not connect to $ANNOTATION");
  $dbhc = DBI->connect($CHACRM,('apollo')x2)
    || &terminateProgram("Could not connect to $CHACRM");
  $dbhw = DBI->connect($WIP,'wipApp','w1pApp')
    || &terminateProgram("Could not connect to $WIP");
  # Statement handles
  $sth{$_} = $dbh->prepare($sth{$_}) || &terminateProgram($dbh->errstr)
    foreach (keys %sth);
  $stha{$_} = $dbha->prepare($stha{$_}) || &terminateProgram($dbha->errstr)
    foreach (keys %stha);
  $sthc{$_} = $dbhc->prepare($sthc{$_}) || &terminateProgram($dbhc->errstr)
    foreach (keys %sthc);
  $sthw{$_} = $dbhw->prepare($sthw{$_}) || &terminateProgram($dbhw->errstr)
    foreach (keys %sthw);
  # Initialize a recursive descent parser
  &initializeParser();
}


# ****************************************************************************
# * Subroutine:  initializeParser                                            *
# * Description: This routine will initialize a recursive descent parser     *
# *              based on a supplied grammar.                                *
# *                                                                          *
# * Parameters:  NONE                                                        *
# * Returns:     NONE                                                        *
# ****************************************************************************
sub initializeParser
{
  $grammar_file ||= "/usr/local/pipeline/grammar/$LAB.gra";
  my $stream= new IO::File $grammar_file,'<'
    or &terminateProgram("Could not open grammar $grammar_file ($!)");
  sysread $stream,my $grammar,-s $stream;
  $stream->close;
  if ($DEBUG) {
    $::RD_HINT = 1;
  }
  else {
    undef $::RD_WARN;
    undef $::RD_ERRORS;
  }
  $Parse::RecDescent::skip = undef;
  $parser = new Parse::RecDescent($grammar) || &terminateProgram('Bad grammar');
}



# ****************************************************************************
# * Subroutine:  computeElapsedTime                                          *
# * Description: Convert an elapsed time in Epoch seconds to English         *
# *              notation. Epoch seconds is the number of seconds past the   *
# *              "Epoch", which any self-respecting Unix geek knows as 00:00 *
# *              UTC on January 1, 1970.                                     *
# *                                                                          *
# * Parameters:  diff: number of seconds between events                      *
# * Returns:     elapsed time as [D days] HH:MM:SS                           *
# ****************************************************************************
sub computeElapsedTime
{
my $result = '';

  my $diff = shift;
  $diff = ($diff - (my $ss = $diff % 60)) / 60;
  $diff = ($diff - (my $mm = $diff % 60)) / 60;
  $diff = ($diff - (my $hh = $diff % 24)) / 24;
  $result = sprintf "%d day%s, ",$diff,(1 == $diff) ? '' : "s"
      if ($diff >= 1);
  $result .= sprintf "%02d:%02d:%02d",$hh,$mm,$ss;
  return($result);
}


# ****************************************************************************
# * Subroutine:  processStream                                               *
# * Description: This routine will process the input stream by updating the  *
# *              priority for every feature found.                           *
# *                                                                          *
# * Parameters:  stream: input stream                                        *
# * Returns:     NONE                                                        *
# ****************************************************************************
sub processStream
{
my %save_prop;
my ($stack,$statement);

  my $stream = shift;
  my $t0 = time;
  $counter{$_} = 0 foreach qw(delete error file gene lsm primary property
                              secondary skipped);
  # Process stream
  while (defined($stack = $stream->getline)) {
    chomp($stack);
    $counter{file}++;
    print $handle "  $stack\n" if ($VERBOSE);
    my $image_name = $stack;
    # Fix stack to remove the image family
    $image_name =~ s/.+?\/// if ('simpson' eq $LAB || 'baker' eq $LAB);
    # Parse the image name
    my $t0 = gettimeofday();
    %grammar = ();
    my $ret = $parser->start($stack);
    unless ($ret) {
      print $handle "  Could not parse $stack\n";
      $counter{error}++;
      next;
    }
    %grammar = %$ret;
    my $interval = gettimeofday() - $t0;
    $profile{parse_cnt}++;
    $profile{parse} += $interval;
    printf $handle "  Parse complete in %f sec\n",$interval if ($DEBUG);
    # Is this already in the image table?
    $sth{PRESENT}->execute($image_name,$grammar{designator});
    my($pid) = $sth{PRESENT}->fetchrow_array;
    # For the Rubin and Baker labs, we let the transmogrifier do the insert
    if (('rubin' eq $LAB || 'baker' eq $LAB) && !$pid) {
      print $handle "  Skipping $stack\n";
      $counter{skipped}++;
      next;
    }

    # Can we get to the LSM directory?
    &terminateProgram("Can't get to $grammar{source_dir}")
      unless (-r $grammar{source_dir});
    # Do we have a good LSM file?
    my $primary_path = join('/',@grammar{('source_dir','source_file')});
    unless (-s $primary_path) {
      print $handle "  $stack is a zero-length file\n";
      next;
    }
    if ($pid && $RELOAD) {
      %save_prop = ();
      foreach my $type (@{$SAVE_PROPERTY{$LAB}}) {
        $sth{GETPROP}->execute($pid,$type);
        my($v) = $sth{GETPROP}->fetchrow_array;
        next unless (defined $v);
        $save_prop{$type} = $v;
      }
      $pid = $sth{DELETE}->execute($pid);
      unless ($pid) {
        print $handle "  Could not delete $stack\n";
        next;
      }
      $counter{delete} += $pid;
      $pid = 0;
      print $handle "  Deleted $stack\n" if ($VERBOSE);
    }
    my (%lsm,@attenuator,@detector,@laser);
    # Get properties
    $t0 = gettimeofday();
    my($ok,$date,$rep,%gene) = &parseProperties($stack);
    unless ($ok) {
      print $handle "  Could not get properties for $stack\n";
      $dbh->rollback;
      next;
    }
    $interval = gettimeofday() - $t0;
    $profile{property_cnt}++;
    $profile{property} += $interval;

    # Do we need to parse the LSM file? If it's a new entry, the answer is yes.
    # If it's an existing entry, check to see if we already have bit data.
    my $must_parse_lsm = 1;
    my $dbprops;
    if ($pid) {
      $sth{PROPPRESENT}->execute($pid);
      $dbprops = $sth{PROPPRESENT}->fetchall_hashref('type');
      $must_parse_lsm = 0 if (exists $dbprops->{dimension_x});
    }
    if (($grammar{source_file} =~ /\.lsm$/) && $must_parse_lsm) {
      $t0 = gettimeofday();
      unless (&parseLSM(\%lsm,\@attenuator,\@detector,\@laser)) {
        $counter{error}++;
        next;
      }
      # Stupid MS Access formatted date...
      if ($lsm{sample_0time}) {
        my($hh,$mi,$ss,$dd,$mm,$yy) =
          localtime((int($lsm{sample_0time})-25568)*86400);
        my $f = ($lsm{sample_0time}- int($lsm{sample_0time})) * 86400;
        $f = ($f - ($ss = $f % 60)) / 60;
        $f = ($f - ($mi = $f % 60)) / 60;
        $f = ($f - ($hh = $f % 24)) / 24;
        my $datel = sprintf "%04d-%02d-%02d %02d:%02d:%02d",$yy+1900,$mm+1,$dd,$hh,$mi,$ss;
        $date = $datel if ($datel);
      }
      $interval = gettimeofday() - $t0;
      $profile{lsm_cnt}++;
      $profile{lsm} += $interval;
    }

    # Is the image name in the image table?
    if ($pid) {
      # Update primary image capture_date
      $sth{CDATE}->execute($date,$pid) if ($must_parse_lsm);
    }
    else {
      # Insert primary image
      $pid = $sth{IMAGE}->execute($image_name,$grammar{designator},$date,$rep);
      $pid = $dbh->last_insert_id(('')x4)
        || &terminateProgram('ERROR: could not get last inserted image ID for '
                             . $image_name);
      $counter{primary}++;
      print $handle "  Inserted $stack ($grammar{designator})\n" if ($VERBOSE);
    }
    unless ($grammar{source_file} =~ /\.lsm$/) {
      my($width,$height) = imgsize($primary_path);
      &insertProperty($pid,'width',$width,$dbprops) if ($width);
      &insertProperty($pid,'height',$height,$dbprops) if ($height);
    }
    # Insert common primary image properties
    $t0 = gettimeofday();
    my $url = join('/','http://img.int.janelia.org',$grammar{img_application},
                   $grammar{designator} . '-confocal-data',uri_escape($image_name));
    &insertProperty($pid,'created_by',$lsm{created_by}||$username,$dbprops)
      unless (exists $save_prop{created_by});
    delete $lsm{created_by};
    &insertProperty($pid,'url',$url,$dbprops);
    &insertProperty($pid,'path',$primary_path,$dbprops);
    my $srcfile = join('/',@grammar{('source_dir','source_file')});
    &insertProperty($pid,'file_size',(-s $srcfile),$dbprops);
    # Insert lab-specific primary image properties
    {
      no strict 'refs';
      my $function = 'insert' . ucfirst($LAB) . 'Props';
      &$function($pid,$dbprops,\%gene,$date);
    }
    # Insert saved image properties
    if ($RELOAD) {
      &insertProperty($pid,$_,$save_prop{$_},$dbprops)
        foreach (keys %save_prop);
    }

    # Insert LSM properties
    &insertLSMProps($pid,\%lsm,\@attenuator,\@detector,\@laser)
      if (scalar keys %lsm);

    # Insert common secondary data
    
    &insertSecondaryData($_,$_,$grammar{$_.'_file'},$pid)
      foreach (qw(translation));
    # Insert lab-specific secondary data
    if ('rubin' eq $LAB || 'simpson' eq $LAB || 'baker' eq $LAB) {
      my $ch = 0;
      foreach (qw(all pattern)) {
        &insertSecondaryData("projection_$_",'projection',
                             $grammar{"projection_$_".'_file'},$pid);
        &insertSubstackData("substack_$_",'projection',$ch,$pid);
        $ch += 2;
      }
      &insertSecondaryData(('rotation')x2,$grammar{'rotation_file'},$pid);
      if ('rubin' eq $LAB) {
        &insertSecondaryData('projection_local_registered','projection',
                              $grammar{'projection_local_registered'},$pid);
        &insertSecondaryData('projection_ref_sum','reference',$grammar{'projection_reference_sum'},$pid);
      }
      if ('rubin' eq $LAB) {
        foreach (qw(local_tiff loop2_tiff quality subject target)) {
          &insertSecondaryData('registration_'.$_,'registration',$grammar{'registration_'.$_.'_file'},$pid);
        }
      }
      elsif ('simpson' eq $LAB) {
        &insertSecondaryData(('medial')x2,$grammar{'medial_file'},$pid);
        &insertSecondaryData('registered_global_tiff','registration',$grammar{'registered_global_tiff'},$pid);
        &insertSecondaryData('projection_global_registered','registration',$grammar{'projection_global_registered'},$pid);
        &insertSecondaryData('registered_local_tiff','registration',$grammar{'registered_local_tiff'},$pid);
        &insertSecondaryData('projection_local_registered','registration',$grammar{'projection_local_registered'},$pid);
      }
    }
    elsif ('leet' eq $LAB) {
      my $ch = 0;
      foreach (qw(all pattern1 pattern2)) {
        &insertSecondaryData("projection_$_",'projection',
                             $grammar{"projection_$_".'_file'},$pid);
        &insertSubstackData("substack_$_",'projection',$ch,$pid);
        $ch += 1;
      }
      &insertSecondaryData(('rotation')x2,$grammar{'rotation_file'},$pid);
      &insertSecondaryData(('tiff')x2,$grammar{'tiff_file'},$pid);
    }
    elsif ('truman' eq $LAB) {
      foreach (qw(red green blue)) {
        &insertSecondaryData("projection_$_",'projection',
                             $grammar{"projection_$_".'_file'},$pid);
        &insertSecondaryData("rock_$_",'rock',
                             $grammar{"rock_$_".'_file'},$pid);
        &insertSecondaryData(('tiff')x2,$grammar{tiff_file},$pid);
      }
    }
    $interval = gettimeofday() - $t0;
    $profile{insert_cnt}++;
    $profile{insert} += $interval;

    # Add a dissection session
    &addDissectionSession($image_name) if ('rubin' eq $LAB);

    # Done with inserts
    ($TEST) ? $dbh->rollback : $dbh->commit;
  }
  printf $handle ("%-27s%s\n").(("%-27s%d\n")x9),
                 'Lab/grammar:',$LAB." ($grammar_file)",
                 'Files checked:',$counter{file},
                 'Files skipped:',$counter{skipped},
                 'Record deletions:',$counter{delete},
                 'LSM files parsed:',$counter{lsm},
                 'Primary images inserted:',$counter{primary},
                 'Secondary images inserted:',$counter{secondary},
                 'Properties inserted:',$counter{property},
                 'Unparsable entries:',$counter{error},
                 'Unknown genes:',$counter{gene};
  print $handle "Execution profile:\n";
  printf $handle ("%-21s%s\n").(("%-21s%f\n")x4),
                 'Elapsed time:',&computeElapsedTime(time-$t0),
                 'Avg. parse:',$profile{parse}/$profile{parse_cnt},
                 'Avg. property fetch:',$profile{property}/$profile{property_cnt},
                 'Avg. LSM read:',(($profile{lsm_cnt}) ? $profile{lsm}/$profile{lsm_cnt} : 0),
                 'Avg. insertion:',$profile{insert}/$profile{insert_cnt};
}


sub parseProperties
{
my %gene;
my $date;

  my $stack = shift;
  my @remap_list = ();
  my $rep = 0;
  if ('rubin' eq $LAB) {
    $date = $grammar{date}; # We get it from the LSM file now...
    &getGene($stack,$grammar{plate},$grammar{well},\%gene);
    $sthc{REPRESENTATIVE}->execute($stack);
    $rep = $sthc{REPRESENTATIVE}->fetchrow_array;
    @remap_list = qw(age area gender landing_site vector);
  }
  elsif ('simpson' eq $LAB) {
    $date = $grammar{capturedate};
    @remap_list = qw(organ);
  }
  elsif ('truman' eq $LAB) {
    $date = $grammar{capturedate};
    &getGene($stack,$grammar{plate},$grammar{well},\%gene);
    ($grammar{Ptransformant} = $grammar{transformantid}) =~ s/^0//;
    @remap_list = qw(landing_site vector);
  }
  elsif ('leet' eq $LAB) {
    &getGene($stack,$grammar{plate},$grammar{well},\%gene)
      if ($grammar{line} =~ /^GMR/);
    @remap_list = ('leet-discovery' eq $grammar{designator})
        ? () : qw(age area gender heat_shock_age);
    push @remap_list,qw(landing_site vector)
      if ($grammar{line} =~ /^GMR/);
  }
  elsif ('baker' eq $LAB) {
    @remap_list = qw(chron_stage gender heat_shock_landmark tissue);
  }

  # Remap
  foreach (@remap_list) {
    if ($grammar{$_}) {
      unless (exists $MAPPING{$_}{$grammar{$_}}) {
        print $handle "  Found no value for $_ [$grammar{$_}]\n";
        return();
      }
      $grammar{$_} = $MAPPING{$_}{$grammar{$_}};
    }
  }

  return(1,$date,$rep,%gene);
}


sub parseLSM
{
  my($lsm_ref,$attn_ref,$det_ref,$laser_ref) = @_;
  my $file = join('/',@grammar{('source_dir','source_file')});
  # Instantiate a Zeiss::LSM object
  my $lsm;
  eval {
    $lsm = new Zeiss::LSM({stack => $file});
  };
  if ($@) {
    print $handle "  $@ $file\n";
    return(0);
  }
  # Simple "per-image" data
  my $ver = unpack('H8',$lsm->cz_private->MagicNumber);
  print $handle "  Version $ver\n" if ($DEBUG);
  $lsm_ref->{dimension_x} = $lsm->cz_private->DimensionX;
  $lsm_ref->{dimension_y} = $lsm->cz_private->DimensionY;
  $lsm_ref->{dimension_z} = $lsm->cz_private->DimensionZ;
  $lsm_ref->{zoom_x} = $lsm->recording->RECORDING_ENTRY_ZOOM_X;
  $lsm_ref->{zoom_y} = $lsm->recording->RECORDING_ENTRY_ZOOM_Y;
  $lsm_ref->{zoom_z} = $lsm->recording->RECORDING_ENTRY_ZOOM_Z;
  $lsm_ref->{channels} = $lsm->cz_private->DimensionChannels;
  $lsm_ref->{number_tracks} = $lsm->numTracks;
  $lsm_ref->{objective} = $lsm->recording->RECORDING_ENTRY_OBJECTIVE;
  $lsm_ref->{voxel_size_x} = sprintf '%.2f',$lsm->cz_private->VoxelSizeX*1e6;
  $lsm_ref->{voxel_size_y} = sprintf '%.2f',$lsm->cz_private->VoxelSizeY*1e6;
  $lsm_ref->{voxel_size_z} = sprintf '%.2f',$lsm->cz_private->VoxelSizeZ*1e6;
  $lsm_ref->{scan_type} = $MAPPING{scantype}{$lsm->cz_private->ScanType};
  $lsm_ref->{created_by} = $lsm->recording->RECORDING_ENTRY_USER;
  $lsm_ref->{sample_0time} = $lsm->recording->RECORDING_ENTRY_SAMPLE_0TIME;
  $lsm_ref->{sample_0z} = $lsm->recording->RECORDING_ENTRY_SAMPLE_0Z;
  $lsm_ref->{bc_correction1} = $lsm->recording->RECORDING_ENTRY_POSITIONBCCORRECTION1;
  $lsm_ref->{bc_correction2} = $lsm->recording->RECORDING_ENTRY_POSITIONBCCORRECTION2;
  (my $desc = $lsm->recording->RECORDING_ENTRY_DESCRIPTION) =~ s/^\s+$//;
  $lsm_ref->{description} = $lsm->recording->RECORDING_ENTRY_DESCRIPTION
    if (length $desc);
  (my $notes = $lsm->recording->RECORDING_ENTRY_NOTES) =~ s/^\s+$//;
  $lsm_ref->{notes} = $lsm->recording->RECORDING_ENTRY_NOTES if (length $notes);
  my %hash;
  # Lasers
  foreach ($lsm->getLasers) {
    %hash = ();
    $hash{name} = $_->OLEDB_LASER_ENTRY_NAME;
    $hash{power} = sprintf '%0.3f mW',$_->OLEDB_LASER_ENTRY_POWER;
    push @$laser_ref,{%hash};
  }
  # Track data
  foreach my $track ($lsm->getTracks) {
    # Attenuators
    my $num = 1;
    foreach my $ic ($track->getIlluminationchannels) {
      %hash = ();
      $hash{num} = $num++;
      $hash{track} = $ic->ILLUMCHANNEL_ENTRY_NAME;
      $hash{wavelength} = sprintf '%.1f nm',$ic->ILLUMCHANNEL_ENTRY_WAVELENGTH;
      $hash{transmission} = sprintf '%.2f%%',$ic->ILLUMCHANNEL_ENTRY_POWER;
      $hash{acquire} = $ic->ILLUMCHANNEL_ENTRY_ACQUIRE;
      $hash{detchannel_name} = $ic->ILLUMCHANNEL_ENTRY_DETCHANNEL_NAME;
      $hash{power_bc1} = $ic->ILLUMCHANNEL_ENTRY_POWER_BC1;
      $hash{power_bc2} = $ic->ILLUMCHANNEL_ENTRY_POWER_BC2;
      if ((defined $hash{power_bc1}) && (defined $hash{power_bc2})
          && ($hash{power_bc1} != $hash{power_bc2})) {
        # P(n) = (P2-P1)*(Z0-(n-1)*dZ-Z1)/Z2-Z1)+P1
            my $dZ = $lsm_ref->{voxel_size_z};
            my $P1 = $hash{power_bc1};
            my $P2 = $hash{power_bc2};
            my $Z0 = $lsm_ref->{sample_0z};
            my $Z1 = $lsm_ref->{bc_correction1};
            my $Z2 = $lsm_ref->{bc_correction2};
            my $top_power = ($P2-$P1)*($Z0-(1-1)*$dZ-$Z1)/($Z2-$Z1)+$P1;
            ($top_power < 0) && ($top_power = 0);
            my $bot_power = ($P2-$P1)*($Z0-($lsm_ref->{dimension_z}-1)*$dZ-$Z1)/($Z2-$Z1)+$P1;
            $hash{ramp_low_power} = sprintf '%.2f',$top_power;
            $hash{ramp_high_power} = sprintf '%.2f',$bot_power;
      }
      push @$attn_ref,{%hash};
    }
    # Detectors
    $num = 1;
    foreach my $dc ($track->getDetectionchannels) {
      %hash = ();
      $hash{num} = $num++;
      $hash{track} = $track->TRACK_ENTRY_NAME;
      $hash{image_channel_name} = $dc->DETCHANNEL_DETECTION_CHANNEL_NAME;
      $hash{detector_voltage} = sprintf '%.3f V',
          $dc->DETCHANNEL_ENTRY_DETECTOR_GAIN;
      $hash{detector_voltage_first} = sprintf '%.3f V',
          $dc->DETCHANNEL_ENTRY_DETECTOR_GAIN_BC1;
      $hash{detector_voltage_last} = sprintf '%.3f V',
          $dc->DETCHANNEL_ENTRY_DETECTOR_GAIN_BC2;
      $hash{amplifier_gain} = sprintf '%.3f',
          $dc->DETCHANNEL_ENTRY_AMPLIFIER_GAIN;
      $hash{amplifier_gain_first} = sprintf '%.3f',
          $dc->DETCHANNEL_ENTRY_AMPLIFIER_GAIN_BC1;
      $hash{amplifier_gain_last} = sprintf '%.3f',
          $dc->DETCHANNEL_ENTRY_AMPLIFIER_GAIN_BC2;
      $hash{amplifier_offset} = sprintf '%.3f',
          $dc->DETCHANNEL_ENTRY_AMPLIFIER_OFFS;
      $hash{amplifier_offset_first} = sprintf '%.3f',
          $dc->DETCHANNEL_ENTRY_AMPLIFIER_OFFS_BC1;
      $hash{amplifier_offset_last} = sprintf '%.3f',
          $dc->DETCHANNEL_ENTRY_AMPLIFIER_OFFS_BC2;
      $hash{pinhole_diameter} = sprintf '%.2f &micro;m',
          $dc->DETCHANNEL_ENTRY_PINHOLE_DIAMETER;
      $hash{filter} = $dc->DETCHANNEL_FILTER_NAME;
      $hash{digital_gain} = ($dc->DETCHANNEL_DIGITAL_GAIN)
        ? (sprintf '%.5f',$dc->DETCHANNEL_DIGITAL_GAIN) : '0.00000';
      $hash{point_detector_name} = $dc->DETCHANNEL_POINT_DETECTOR_NAME;
      $hash{pinhole_name} = $dc->DETCHANNEL_PINHOLE_NAME;
      foreach my $dac ($track->getDatachannels) {
        $lsm_ref->{bits_per_sample} = $dac->DATACHANNEL_ENTRY_BITSPERSAMPLE
          unless ($lsm_ref->{bits_per_sample});
        next unless ($dac->DATACHANNEL_ENTRY_NAME
                     eq $dc->DETCHANNEL_DETECTION_CHANNEL_NAME);
        $hash{color} = '#'.unpack('H6',pack('L',$dac->DATACHANNEL_ENTRY_COLOR));
      }
      push @$det_ref,{%hash};
    }
  }
  $counter{lsm}++;
  return(1);
}


sub getGene
{
  my($stack,$plate,$well,$generef) = @_;
  # Get associated genes
  my($cg) = &getCG($plate,$well);
  unless ($cg) {
    print $handle '  Could not find CG for ',join('.',$plate,$well),"\n";
    $counter{gene}++;
    return();
  }
  $sthc{GENE}->execute($cg);
  my $gene = $sthc{GENE}->fetchall_arrayref([0]);
  # HARDCODE for fruitless ***********************************
  push @$gene,['fru'] if ($cg eq 'CG14307');
  # HARDCODE for fruitless ***********************************
  unless (scalar @$gene) {
    $generef->{$cg}++;
  }
  else {
    %$generef = map { $_->[0] => 1 } @$gene;
    delete $generef->{$cg} if (scalar(keys %$generef) > 1);
  }
  return(1);
}


sub getCG
{
  my($plate,$well) = @_;
  $plate =~ s/^0//;
  $plate = 'GR.' . $plate;
  $well = &JFRC::Utils::Plate::label2Well($well);
  $sthc{CG}->execute(join('.',$plate,$well));
  my($cg) = $sthc{CG}->fetchrow_array;
  return($cg||'');
}


sub insertBakerProps
{
my $rv;

  my($pid,$dbprops,$gene_ref,$date) = @_;
  my @column = qw(line chron_hour chron_stage gender heat_shock_landmark
                  short_genotype specimen tissue);
  foreach (@column) {
    next unless ($grammar{$_});
    &insertProperty($pid,$_,$grammar{$_},$dbprops);
  }
}


sub insertLeetProps
{
  my($pid,$dbprops,$gene_ref,$date) = @_;
  my @column = qw(well vector landing_site line gender age heat_shock_age);
  foreach (@column) {
    next unless ($grammar{$_});
    &insertProperty($pid,$_,$grammar{$_},$dbprops);
  }
  &insertProperty($pid,'plate','GR.'.$grammar{plate},$dbprops)
    if ($grammar{plate});
  &insertProperty($pid,'organ',$grammar{area},$dbprops) if ($grammar{area});
  &insertProperty($pid,'heat_shock_minutes',$grammar{hs_min},$dbprops)
    if ($grammar{hs_min});
  &insertProperty($pid,'gene',$_,$dbprops) foreach (sort keys %$gene_ref);
}


sub insertRubinProps
{
  my($pid,$dbprops,$gene_ref,$date) = @_;
  my @column = qw(well vector landing_site gender age);
  foreach (@column) {
    next unless ($grammar{$_});
    &insertProperty($pid,$_,$grammar{$_},$dbprops);
  }
  &insertProperty($pid,'line',$grammar{transformantid},$dbprops);
  &insertProperty($pid,'plate','GR.'.$grammar{plate},$dbprops);
  &insertProperty($pid,'organ',$grammar{area},$dbprops);
  &insertProperty($pid,'specimen',$grammar{sequencenumber},$dbprops);
  &insertProperty($pid,'gene',$_,$dbprops) foreach (sort keys %$gene_ref);
  # Set dissector and mounter only if an IHC batch exists
  $sth{GETPROP}->execute($pid,'ihc_batch');
  my($ib) = $sth{GETPROP}->fetchrow_array;
  if ($ib) {
    print $handle "  Batch $ib: inserting dissector and mounter\n";
    # Dissection
    (my $tn = $grammar{line}) =~ s/^GMR_//;
    $sthc{DISSECTOR}->execute($tn,$date);
    my($dissector,$ddate) = $sthc{DISSECTOR}->fetchrow_array;
    if ($dissector) {
      &insertProperty($pid,'dissector',$dissector,$dbprops);
      &insertProperty($pid,'dissection_date',$ddate,$dbprops);
    }
    # Mounting
    $sthw{MOUNTER}->execute($grammar{line},$ddate);
    my($mounter,$mdate) = $sthw{MOUNTER}->fetchrow_array;
    if ($mounter) {
      &insertProperty($pid,'mounter',$mounter,$dbprops);
      &insertProperty($pid,'mount_date',$mdate,$dbprops);
    }
  }
  return(); #PLUG
  # Registration
  my $csv = join('/',$grammar{registration_dir},$grammar{registered_quality});
  if (-e $csv) {
    print $handle "    Reading Qi and Qm\n";
    open CSV,$csv or &terminateProgram("Could not open $csv ($!)");
    <CSV>;
    chomp(my $line = <CSV>);
    $line =~ s/ //g;
    my($qi,$qm) = split(/,/,$line);
    &insertProperty($pid,'qi',$qi,$dbprops);
    &insertProperty($pid,'qm',$qm,$dbprops);
    close(CSV);
  }
}


sub insertTrumanProps
{
  my($pid,$dbprops,$gene_ref,$date) = @_;
  my @column = qw(well vector landing_site);
  foreach (@column) {
    next unless ($grammar{$_});
    &insertProperty($pid,$_,$grammar{$_},$dbprops);
  }
  &insertProperty($pid,'line',$grammar{Ptransformant},$dbprops);
  &insertProperty($pid,'plate','GR.'.$grammar{plate},$dbprops);
  &insertProperty($pid,'gene',$_,$dbprops) foreach (sort keys %$gene_ref);
}


sub insertSimpsonProps
{
my $rv;

  my($pid,$dbprops,$gene_ref,$date) = @_;
  my @column = ('line');
  if ('GAL4' eq $grammar{designator}) {
    push @column,('insertion') if ($grammar{insertion});
    push @column,qw(organ specimen);
  }
  foreach (@column) {
    &terminateProgram("Null $_") unless ($grammar{$_});
    &insertProperty($pid,$_,$grammar{$_},$dbprops);
  }
}


sub insertProperty
{
  my($pid,$key,$value,$dbprops) = @_;
  if (exists $dbprops->{$key}) {
    print $handle "    Property $key already present\n" if ($DEBUG);
  }
  else {
    my $rv = $sth{PROPERTY}->execute($pid,$key,$value);
    $counter{property}++;
    print $handle "    Inserted property $key ($value)\n" if ($DEBUG);
  }
}


sub insertLSMProps
{
  my($pid,$lsm_ref,$attn_ref,$det_ref,$laser_ref) = @_;
  my $rv;
  print $handle "    Inserting LSM data\n" if ($DEBUG);
  # Per-image properties
  $rv = $sth{PROPERTY}->execute($pid,$_,$lsm_ref->{$_})
    foreach (sort keys %$lsm_ref);
  $counter{property} += scalar(keys %$lsm_ref);
  # Laser data
  foreach my $hash (@$laser_ref) {
    $rv = $sth{LASER}->execute($pid,$hash->{name},$hash->{power}||'');
  }
  # Attenuator data
  foreach my $hash (@$attn_ref) {
    my @value;
    my $sql = 'INSERT INTO attenuator (image_id,';
    foreach (sort keys %$hash) {
      $sql .= "$_,";
      push @value,$hash->{$_};
    }
    next unless (scalar @value);
    unshift @value,$pid;
    $sql =~ s/,$/)/;
    $sql .= ' VALUES (' . join(',',map { $dbh->quote($_) } @value) . ')';
    $rv = $dbh->do($sql);
  }
  # Detector data
  foreach my $hash (@$det_ref) {
    my @value;
    my $sql = 'INSERT INTO detector (image_id,';
    foreach (sort keys %$hash) {
      $sql .= "$_,";
      push @value,$hash->{$_};
    }
    next unless (scalar @value);
    unshift @value,$pid;
    $sql =~ s/,$/)/;
    $sql .= ' VALUES (' . join(',',map { $dbh->quote($_) } @value) . ')';
    $rv = $dbh->do($sql);
  }
  $counter{property} += scalar(@$laser_ref) + scalar(@$attn_ref)
                        + scalar(@$det_ref);
}


sub insertSubstackData
{
  my($type,$dir,$channel,$pid) = @_;
  my @list = glob(join('/',$grammar{$dir.'_dir'},$grammar{stack}).'*.jpg');
  foreach (@list) {
    next if (/_(?:00|total).jpg/);
    next if (/\.reg\.local\.jpg/);
    if (/_p\d+_\d+.jpg/) {
      my($p) = $_ =~ /_p(\d+)_\d+\.jpg/;
      $p ||= 0;
      next unless ($p == $channel);
      &insertSecondaryData($type,$dir,basename($_),$pid);
    }
    else {
      my($ch) = $_ =~ /_ch(\d+)_/;
      $ch ||= 0;
      next unless ($ch == $channel);
      my $qtype = $type . ((2 == $ch) ? '_pattern' : '_all');
      &insertSecondaryData($type,$dir,basename($_),$pid);
    }
  }
}


sub insertSecondaryData
{
  my($type,$dir,$file,$pid) = @_;
  my $image_name = join('/',$grammar{$dir.'_loc'},$file);
  my $file_path = join('/',$grammar{$dir.'_dir'},$file);
  $sth{SECPRESENT}->execute($image_name,$pid);
  my($present) = $sth{SECPRESENT}->fetchrow_array;
  if (-e $file_path && !$present) {
    print "Insert $image_name\n" if ($DEBUG);
    # The file exists - insert a secondary image
    print $handle "    Inserting image $image_name as $type\n" if ($DEBUG);
    my $url = join('/','http://img.int.janelia.org',$grammar{img_application},
                   $grammar{designator} . '-secondary-data',
                   $grammar{$dir.'_loc'},uri_escape($file));
    my $sid = $sth{SECIMAGE}->execute($image_name,$type,$pid,$file_path,$url);
    $sid = $dbh->last_insert_id(('')x4)
      || &terminateProgram('ERROR: could not get last inserted image ID for '
                           . $image_name);
    $counter{secondary}++;
  }
  elsif (!-e $file_path) {
    print $handle "    $file_path does not exist\n" if ($DEBUG);
  }
  else {
    print $handle "    $image_name already present\n" if ($DEBUG);
  }
}


sub addDissectionSession
{
  my($image_name) = shift;
  # Check line
  $stha{LINE}->execute($grammar{line},$LAB);
  my($lid) = $stha{LINE}->fetchrow_array();
  if ($lid) {
    print $handle "    Line $grammar{line} is present in annotation db\n"
      if ($VERBOSE);
  }
  else {
    my($cg) = &getCG($grammar{plate},$grammar{well});
    &terminateProgram("Could not find gene for $image_name") unless ($cg);
    unless ($TEST) {
      $stha{ILINE}->execute($grammar{line},$LAB,$cg);
      $lid = $dbha->last_insert_id(('')x4)
        || &terminateProgram('ERROR: could not get last inserted line ID for '
                             . $grammar{line});
    }
    print $handle "    Inserted line $grammar{line} into annotation db\n"
      if ($VERBOSE);
  }
}


# ****************************************************************************
# * Subroutine:  processInput                                                *
# * Description: This routine will open the input stream (one or more files  *
# *              represented by a glob term, or STDIN).                      *
# *                                                                          *
# * Parameters:  glob_term: the glob term indicating the file(s) (optional)  *
# * Returns:     NONE                                                        *
# ****************************************************************************
sub processInput
{
  my $glob_term = shift;
  if ($glob_term) {
    my @file_list = glob $glob_term;
    &terminateProgram("ERROR: no files matching $glob_term")
      if (! scalar @file_list);
    foreach my $file (@file_list) {
      my $stream = new IO::File $file,'<'
          or &terminateProgram("ERROR: Could not open $file ($!)");
      print $handle "Processing $file for $LAB lab\n" if ($VERBOSE);
      &processStream($stream);
      $stream->close;
    }
  }
  else {
    my $select = IO::Select->new(\*STDIN);
    &terminateProgram('ERROR: you must specify a file or provide input on '
                      . 'STDIN') unless ($select->can_read(0));
    my $stream = new_from_fd IO::File \*STDIN,'<'
        or &terminateProgram("ERROR: could not open STDIN ($!)");
    print $handle "Processing STDIN for $LAB lab\n" if ($VERBOSE);
    &processStream($stream);
    $stream->close;
  }
}


# ****************************************************************************
# * Parse::RecDescent subroutines                                            *
# ****************************************************************************

# ****************************************************************************
# * Subroutine:  Parse::RecDescent::assign                                   *
# * Description: This routine will accept a Parse::RecDescent %item hash     *
# *              and return a key/value pair for every scalar value, and a   *
# *              flattened hash for every value that is a hash. Any key      *
# *              starting with "__" (as in "__RULE__") is ignored.           *
# *                                                                          *
# * Parameters:  item_ref: reference to the Parse::RecDescent %item hash     *
# * Returns:     Flattened Parse::RecDescent %item hash                      *
# ****************************************************************************
sub Parse::RecDescent::assign
{
  my $item_ref = shift;
  my %data = ();
  foreach my $key (grep(!/^__/,keys %$item_ref)) {
    if ('HASH' eq ref($item_ref->{$key})) {
      $data{$_} = $item_ref->{$key}{$_} foreach (keys %{$item_ref->{$key}});
    }
    else {
      $data{$key} = $item_ref->{$key};
    }
  }
  return(%data);
}


# ****************************************************************************
# * Main                                                                     *
# ****************************************************************************
GetOptions('lab=s'     => \$LAB,
           'file=s'    => \my $input_file,
           'grammar=s' => \$grammar_file,
           'output=s'  => \my $output_file,
           reload      => \$RELOAD,
           development => \$DEV,
           test        => \$TEST,
           verbose     => \$VERBOSE,
           debug       => \$DEBUG,
           help        => \my $HELP)
  or pod2usage(-1);

# Display help and exit if the -help parm is specified
pod2text($0),&terminateProgram() if ($HELP);
$VERBOSE = 1 if ($DEBUG);
&terminateProgram('ERROR: you must specify a lab') unless ($LAB);

# Open the output stream
$handle = ($output_file) ? (new IO::File $output_file,'>'
              or &terminateProgram("ERROR: could not open $output_file ($!)"))
                         : (new_from_fd IO::File \*STDOUT,'>'
              or &terminateProgram("ERROR: could not open STDOUT ($!)"));
autoflush $handle 1;

# Initialize program
&initializeProgram();
# Process input
&processInput($input_file);
# We're done
&terminateProgram();

# ****************************************************************************
# * POD documentation                                                        *
# ****************************************************************************
__END__
