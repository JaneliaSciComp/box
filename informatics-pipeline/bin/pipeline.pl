#!/usr/bin/perl
# ****************************************************************************
# Resource name:  pipeline.pl
# Written by:     Rob Svirskas
# Revision level: 1.5
# Date released:  2017-07-18
# Description:    See the bottom of this file for the POD documentation.
#                 Search for the string '=head'.
# Required resources:
#   Programs:        NONE
#   USEd modules:    strict
#                    warnings
#                    Cwd
#                    Getopt::Long
#                    IO::File
#                    IO::Select
#                    Parse::RecDescent
#                    Pod::Text
#                    Pod::Usage
#                    XML::Simple
#   Config files:    (flow configuration as specified by -config)
#                    (optional grammar as specified -grammar)
#   Input files:     (as specified by -file parm)
#   Output files:    (as specified by -output parm)
#                    (as specified by -system parm)
#
#                               REVISION LOG
# ----------------------------------------------------------------------------
# | revision | name            | date    | description                       |
# ----------------------------------------------------------------------------
#     1.0     Rob Svirskas      07-12-13  Initial version
#     1.1     Rob Svirskas      08-11-17  Added ability to execute Perl and
#                                         Python programs as part of the flow.
#     1.2     Rob Svirskas      13-03-28  Added autopass and autofail parms.
#     1.3     Rob Svirskas      13-05-10  Added system parm.
#     1.4     Rob Svirskas      13-09-04  Added "grammar_path" to grammar.
#     1.5     Rob Svirskas      17-07-18  Added lsf action.
# ****************************************************************************

# Perl built-ins
use strict;
use warnings;
use Cwd qw(abs_path);
use Getopt::Long;
use IO::File;
use IO::Select;
use Parse::RecDescent;
use Pod::Text;
use Pod::Usage;
use XML::Simple;

# ****************************************************************************
# * Constants                                                                *
# ****************************************************************************
use vars qw($AUTOLOAD);
my $DATE_FORMAT = '^\d{4}-(?:1[012]|0[1-9])-(?:0[1-9]|[12]\d|3[01])$';

# ****************************************************************************
# * Global variables                                                         *
# ****************************************************************************
# Command-line parameters
my ($DEBUG,$TEST,$VERBOSE) = (0)x3;
my ($ACCOUNT,$AUTOFAIL,$AUTOPASS) = ('')x3;
# Process flow
my (%ACCUMULATOR,%COMMAND,%PROCESS);
my (%mail,%recipient);
my @message_stack;
my $Filenum = 1;
my $INITIAL;
# Parser
my ($grammar_file,$parser) = ('')x2;
my %grammar;
our $Grammar_path;
# Filehandles
my ($handle,$system_handle);


# ****************************************************************************
# * Main                                                                     *
# ****************************************************************************

# Get the command-line parameters
GetOptions('grammar=s'  => \$grammar_file,
           'config=s'   => \my $xml_file,
           'file=s'     => \my $glob_term,
           'account=s'  => \$ACCOUNT,
           'autopass=s' => \$AUTOPASS,
           'autofail=s' => \$AUTOFAIL,
           'output=s'   => \my $output_file,
           'system=s'   => \my $system_file,
           test         => \$TEST,
           verbose      => \$VERBOSE,
           debug        => \$DEBUG,
           help         => \my $HELP)
  or pod2usage(-1);

# Display help and exit if the -help parm is specified
pod2text($0),&terminateProgram() if ($HELP);

# Initialize the program
&initializeProgram($xml_file);

# Process input streams
my $START_TIME = localtime(time);
&processInput($glob_term);

# We're done!
if (keys %ACCUMULATOR) {
  print $handle "Counters\n--------\n";
  print $handle "  $_: $ACCUMULATOR{$_}\n" foreach (sort keys %ACCUMULATOR);
}
&terminateProgram();


# ****************************************************************************
# * Subroutines                                                              *
# ****************************************************************************

# ****************************************************************************
# * Subroutine:  initializeProgram                                           *
# * Description: This routine will initialize the program. It will:          *
# *              1) Open the output and error streams                        *
# *              2) Get operational parms from XML config file               *
# *              3) Initialize a recursive descent parser                    *
# *                                                                          *
# * Parameters:  xml_file: XML configuration file                            *
# * Returns:     NONE                                                        *
# ****************************************************************************
sub initializeProgram
{
  my $xml_file = shift;
  $VERBOSE = 1 if ($DEBUG);
  # Check for dependencies
  &terminateProgram('A configuration file must be specified')
    unless ($xml_file);

  # Open the output streams
  $handle = ($output_file) ? (new IO::File $output_file,'>'
                or &terminateProgram("ERROR: could not open $output_file ($!)"))
                           : (new_from_fd IO::File \*STDOUT,'>'
                or &terminateProgram("ERROR: could not open STDOUT ($!)"));
  autoflush $handle 1;
  if ($system_file) {
    $system_handle = new IO::File $system_file,'>'
      or &terminateProgram("ERROR: could not open $system_file ($!)");
    autoflush $system_handle 1;
  }
  print $handle "Initializing program\n" if ($VERBOSE);
  # Initialize XML
  &initializeXML($xml_file);
  # Initialize a recursive descent parser
  &initializeParser();
  # Startup debug information
  if ($DEBUG) {
    print $handle "Command templates in use:\n";
    foreach my $key (keys %COMMAND) {
      my $file = &evaluate($COMMAND{$key}{in_name});
      print $handle "  $key: $file\n";
    }
  }
}


# ****************************************************************************
# * Subroutine:  initializeXML                                               *
# * Description: This routine will set data structures based on XML input.   *
# *                                                                          *
# * Parameters:  file: XML input file                                        *
# * Returns:     NONE                                                        *
# ****************************************************************************
sub initializeXML
{
  my $file = shift;
  print $handle "  Initializing XML\n" if ($DEBUG);
  &terminateProgram("Can't open XML file $file ($!)") unless (-e $file);
  my $p;
  eval {
    $p = XMLin($file,
               ForceArray => ['command_file','step'],
               KeyAttr =>    {command_file => 'type'});
  };
  die("Could not configure from XML file: $@") if ($@);
  unless ($grammar_file) {
    $grammar_file = $p->{grammar}
      || &terminateProgram('No grammar was specified');
  }
  %COMMAND = (exists $p->{command_file}) ? %{$p->{command_file}} : ();
  &setProcessFlow($p->{step});
}


# ****************************************************************************
# * Subroutine:  setProcessFlow                                              *
# * Description: This routine will set up the process flow. The %process     *
# *              hash is used as a starting point, and any missing values    *
# *              are filled in. There are the following restrictions:        *
# *              1) There must be at least one process step                  *
# *              2) All specified elements must be non-null                  *
# *              3) Every step must have at minimum a name and an action     *
# *              4) The flow must have a "pass" exit condition               *
# *              5) The flow must have a fail (or PLP) exit condition        *
# *              6) If a process step other than the last sequential step    *
# *                 does not have a pass, fail or PLP next step, the next    *
# *                 sequential step is used.                                 *
# *              7) If the last sequential step in the flow does not have a  *
# *                 pass, fail or PLP next step, the flow will terminate.    *
# *                                                                          *
# * Parameters:  file: XML input file                                        *
# * Returns:     NONE                                                        *
# ****************************************************************************
sub setProcessFlow
{
  my $process = shift;
  print $handle "Process flow:\n" if ($VERBOSE);
  $INITIAL = $process->[0]->{name};
  foreach my $idx (0..$#$process) {
   # Make sure that any elements specified are non-null
   (ref($process->[$idx]->{$_})) &&
     &terminateProgram("$_ for step $process->[$idx]->{name} is empty")
     foreach (keys %{$process->[$idx]});
    # Check for required elements
    foreach (qw(name action)) {
      &terminateProgram('ERROR: step ' . ($idx+1) . " has no <$_> specified")
        unless (exists $process->[$idx]->{$_});
    }
    # Set default "next" steps
    foreach (qw(fail pass post_loopback)) {
      $process->[$idx]->{$_} = $process->[$idx+1]->{name}
        if (!$process->[$idx]->{$_} && ($idx != $#$process));
      $process->[$idx]->{$_} = '' unless (exists $process->[$idx]->{$_});
    }
    # Set loopback and description
    $process->[$idx]->{visits} ||= 1;
    &terminateProgram('ERROR: step ' . ($idx+1)
                      . ' has an invalid number of visits specified')
      unless ($process->[$idx]->{visits} =~ /^\d+$/);
    $process->[$idx]->{description} =  $process->[$idx]->{name}
      unless (exists $process->[$idx]->{description});
    # Save this step in the global hash
    $PROCESS{my $step = $process->[$idx]->{name}} = $process->[$idx];
    if ($VERBOSE) {
      print $handle "  $step\n";
      print $handle join("\n",
                    "    Description: $PROCESS{$step}->{description}",
                    "    Action:      $PROCESS{$step}->{action}",
                    "    Pass:        $PROCESS{$step}->{pass}",
                    "    Fail:        $PROCESS{$step}->{fail}",
                    "    Visits:      $PROCESS{$step}->{visits}",
                    "    PLP:         $PROCESS{$step}->{post_loopback}"),"\n"
        if ($DEBUG);
    }
  }
  my($p,$f) = (0)x2;
  foreach my $k (keys %PROCESS) {
    foreach (qw(pass fail post_loopback)) {
      next unless ($PROCESS{$k}->{$_});
      &terminateProgram("ERROR: process step $k references non-existent $_ "
                        . 'step ' . $PROCESS{$k}->{$_})
      unless (exists $PROCESS{$PROCESS{$k}->{$_}});
    }
    $p++ unless ($PROCESS{$k}->{pass});
    $f++ unless ($PROCESS{$k}->{fail} && $PROCESS{$k}->{post_loopback});
  }
  &terminateProgram('ERROR: process flow appears to have no exit conditions')
    unless ($p && $f);
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
  print $handle "  Initializing recursive descent parser\n" if ($DEBUG);
  my $stream= new IO::File $grammar_file,'<'
    or &terminateProgram("Could not open grammar $grammar_file ($!)");
  sysread $stream,my $grammar,-s $stream;
  $stream->close;
  $::RD_HINT = 1;
  # $::RD_TRACE = 1;
  $Parse::RecDescent::skip = undef;
  $parser = new Parse::RecDescent($grammar) || die 'Bad grammar';
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
      print $handle "Processing $file\n" if ($VERBOSE);
      &processStream($stream,$file);
    }
  }
  else {
    my $select = IO::Select->new(\*STDIN);
    &terminateProgram('ERROR: you must specify a file or provide input on '
                      . 'STDIN') unless ($select->can_read(0));
    my $stream = new_from_fd IO::File \*STDIN,'<'
        or &terminateProgram("ERROR: could not open STDIN ($!)");
    print $handle "Processing STDIN stream\n" if ($VERBOSE);
    &processStream($stream,'STDIN');
  }
}


# ****************************************************************************
# * Subroutine:  processStream                                               *
# * Description: This routine will process a single input stream. Every line *
# *              in the input stream is consideres a parsable item, and will *
# *              be processed with the parser then acted upon using the      *
# *              process flow from the XML configuration file.               *
# *                                                                          *
# * Parameters:  stream: input stream to process                             *
# *              file:   filename                                            *
# * Returns:     NONE                                                        *
# ****************************************************************************
sub processStream
{
  my($stream,$file) = @_;
  while (defined(my $item = $stream->getline)) {
    chomp($item);
    print $handle "$item\n" if ($DEBUG);
    %grammar = ();
    $Grammar_path = abs_path($grammar_file);
    my $ret = $parser->start($item);
    &terminateProgram("Could not parse line $. of $file:\n$item") unless ($ret);
    %grammar = %$ret;
    &produceCommandFiles();
    &executeProcess($item);
  }
  $stream->close;
  print $handle "Processing of $file complete\n" if ($VERBOSE);
}


# ****************************************************************************
# * Subroutine:  processCommandFiles                                         *
# * Description: This routine will read in command file templates and        *
# *              replace grammar variables with their actual values. The     *
# *              template is processed line-by-line, and an actual command   *
# *              file is produced.                                           *
# *                                                                          *
# * Parameters:  NONE                                                        *
# * Returns:     NONE                                                        *
# ****************************************************************************
sub produceCommandFiles
{
  print $handle "  Producing command files\n" if ($DEBUG);
  foreach my $key (keys %COMMAND) {
    &terminateProgram("Illegal command file type: $key")
      unless ($key =~ /^[A-Za-z _]+$/);
    &terminateProgram("Command template file was not specified for $key")
      unless (exists $COMMAND{$key}{in_name});
    my $file = &evaluate($COMMAND{$key}{in_name});
    &terminateProgram("Command template file $file does not exist")
      unless (-e $file);
    my $istream = new IO::File $file,'<'
      or &terminateProgram("Could not open command template $file ($!)");
    # Set output file name. If one isn't provided, make it up.
    if (exists $COMMAND{$key}{out_name}) {
      $file = &evaluate($COMMAND{$key}{out_name});
    }
    else {
      # Build a file based on timestamp _ PID _ file number
      $file = sprintf '%d_%d.cmd%d',time,$$,$Filenum++;
    }
    $file .= '.' . $COMMAND{$key}{out_ext}
      if (exists $COMMAND{$key}{out_ext});
    (my $type = lc($key)) =~ s/ /_/g;
    if (exists $grammar{$type}) {
      &terminateProgram("Could not create command file association for $key: "
                        . 'grammar term already exists');
    }
    else {
      $grammar{$type} = $file;
    }
    $file = '/dev/null' if ($TEST);
    print $handle "    Writing $file\n" if ($DEBUG);
    my $ostream = new IO::File $file,'>'
      or &terminateProgram("Could not open command file $file for write ($!)");
    while (defined(my $line = $istream->getline)) {
      print $ostream &evaluate($line);
    }
    $istream->close;
    $ostream->close;
    unless ($TEST) {
      &terminateProgram("Did not write command file $file")
        unless (-e $file);
      chmod 0755,$file;
    }
  }
}


# ****************************************************************************
# * Subroutine:  executeProcess                                              *
# * Description: This routine will execute the defined process flow for one  *
# *              item. Since we're fixed injection, the flow always starts   *
# *              with the same process. For every process, the action is     *
# *              determined and executed until the terminal process is       *
# *              reached.                                                    *
# *                                                                          *
# * Parameters:  item: the item to execute the flow on                       *
# * Returns:     NONE                                                        *
# ****************************************************************************
sub executeProcess
{
no strict 'refs';

  my $item = shift;
  print $handle "  Executing process flow\n" if ($DEBUG);
  @message_stack = ();
  $PROCESS{$_}->{visit_count} = 0 foreach (keys %PROCESS);
  my $process_step = $INITIAL;
  while ($process_step) {
    my $process = $PROCESS{$process_step};
    if ($process->{visit_count} >= $process->{visits}) {
      $process_step = $process->{post_loopback};
      next;
    }
    $process->{visit_count}++;
    my $function = lc($process->{action});
    print $handle "    Process step $process_step: ",
                  $process->{description}||$function,
                  " (visit $process->{visit_count}/$process->{visits})\n"
      if ($DEBUG);
    $function .= 'Action';
    $process->{item} = $item;
    my $success;
    if ($AUTOPASS eq $process_step) {
      $success = 1;
    }
    elsif ($AUTOFAIL eq $process_step) {
      $success = 0;
    }
    else {
      $success = &$function($process);
    }
    push @message_stack,sprintf ("Step %s %sed for item %s",$process->{name},
                                 (($success) ? 'pass' : 'fail'),$item);
    $process_step = $process->{($success) ? 'pass' : 'fail'};
  }
}


# ****************************************************************************
# * Subroutine:  evaluate                                                    *
# * Description: This routine will double-interpolate a variable. The        *
# *              variable must be either a scalar or a hash, and all         *
# *              components of the variable name must be a lowercase letter, *
# *              an underbar, or braces.                                     *
# *                                                                          *
# * Parameters:  (unspecified): variable(s) to interpolate                   *
# * Returns:     interpolated variable(s) as an array (scalar for single)    *
# ****************************************************************************
sub evaluate
{
use warnings FATAL => qw(all);
my @value;
my $var;

  foreach (@_) {
    if (! defined) {
      $var = undef;
      push @value,$var;
      next;
    }
    # Ooooh, double interpolation...
    eval { ($var = $_) =~ s/(\$[a-z_][a-z0-9{}_]*)/$1/eegs };
    &terminateProgram("Could not evaluate $_: " . $@) if $@;
    push @value,$var
  }
  return((wantarray) ? @value : $var);
}


# ****************************************************************************
# * Subroutine:  sendMail                                                    *
# * Description: This routine will send out mail messages specified in the   *
# *              %mail hash.                                                 *
# *                                                                          *
# * Parameters:  NONE                                                        *
# * Returns:     NONE                                                        *
# ****************************************************************************
sub sendMail
{
  foreach my $step (sort keys %mail) {
    print $handle "Send mail to $recipient{$step} for process step $step\n"
      if ($VERBOSE || $TEST);
    if (open(SENDMAIL,'|/usr/lib/sendmail -i -t')) {
      print SENDMAIL <<__EOT__;
To: $recipient{$step}
Subject: Pipeline messages for run $$ step $step

Pipeline run $$ started at $START_TIME
Configuration file: $xml_file
Grammar file:       $grammar_file
----------------------------------------------------------------------
$mail{$step}
__EOT__
      close(SENDMAIL);
    }
    else {
      print $handle "Can't fork for sendmail ($!)";
    }
  }
}


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
  # &sendMail() if (scalar keys %mail);  # no more e-mailing
  $handle->close if ($handle);
  $system_handle->close if ($system_handle);
  exit(($message) ? -1 : 0);
}


# ****************************************************************************
# * Actions                                                                  *
# ****************************************************************************

# ****************************************************************************
# * Subroutine:  bashAction                                                  *
# * Description: This routine implements the "bash" action - it will execute *
# *              a specified command file using the bash shell. The return   *
# *              status from the script determines success (0) or failure    *
# *              (non-zero).                                                 *
# *                                                                          *
# * Parameters:  process: process hash                                       *
# * Returns:     0 to fail, 1 to pass                                        *
# ****************************************************************************
sub bashAction
{
  my $process = shift;
  my @command = 'bash';
  my $args = &evaluate($process->{args});
  &terminateProgram("Must specify args for bash action") unless ($args);
  push @command,split(/\s+/,$args);
  my $stderr = &evaluate($process->{stderr});
  my $stdout = &evaluate($process->{stdout});
  push @command,'>'.$stdout if ($stdout);
  push @command,'2>'.$stderr if ($stderr);
  print $handle '    ' . join(' ',@command),"\n" if ($DEBUG);
  return(1) if ($TEST);
  if ($system_handle) {
    print $system_handle join(' ',@command),"\n";
    return(1);
  }
  my $status = system(join ' ',@command);
  print $handle "    Status: $status\n" if ($DEBUG);
  ($_ && !-s $_) && unlink($_) foreach ($stdout,$stderr);
  return ($status) ? 0 : 1;
}


# ****************************************************************************
# * Subroutine:  bump_counterAction                                          *
# * Description: This routine will add 1 to a specified counter.             *
# *                                                                          *
# * Parameters:  process: process hash                                       *
# * Returns:     1 (pass)                                                    *
# ****************************************************************************
sub bump_counterAction
{
  my $process = shift;
  &terminateProgram('Undefined counter') unless (exists $process->{counter});
  $ACCUMULATOR{$process->{counter}}++;
  return(1);
}


# ****************************************************************************
# * Subroutine:  cleanupAction                                               *
# * Description: This routine implements the "cleanup" action - it will      *
# *              remove all created command files for the current item.      *
# *                                                                          *
# * Parameters:  NONE                                                        *
# * Returns:     1 (pass)                                                    *
# ****************************************************************************
sub cleanupAction
{
  foreach my $key (keys %COMMAND) {
    (my $type = lc($key)) =~ s/ /_/g;
    my $file = &evaluate($grammar{$type});
    if ($TEST) {
      print $handle "    Remove $file\n" if ($DEBUG);
    }
    else {
      unlink($file);
    }
  }
  return(1);
}


# ****************************************************************************
# * Subroutine:  dumpAction                                                  *
# * Description: This routine implements the "dump" action - it will display *
# *              the contents of the %grammar hash.                          *
# *                                                                          *
# * Parameters:  NONE                                                        *
# * Returns:     1 (pass)                                                    *
# ****************************************************************************
sub dumpAction
{
  my $len = 0;
  ((length($_) > $len) && ($len = length($_))) foreach (keys %grammar);
  $len++;
  (printf $handle "%-*s %s\n",$len,"$_:",$grammar{$_})
    foreach (sort keys %grammar);
  return(1);
}


# ****************************************************************************
# * Subroutine:  equalsAction                                                *
# * Description: This routine implements the "equals" action - if the        *
# *              specified values are equal, we pass; otherwise we fail.     *
# *                                                                          *
# * Parameters:  process: process hash                                       *
# * Returns:     0 to fail, 1 to pass                                        *
# ****************************************************************************
sub equalsAction
{
  my $process = shift;
  return(0) unless (length(my $v1 = &evaluate($process->{value1}))
                    && length(my $v2 = &evaluate($process->{value2})));
  return($v1 eq $v2);
}


# ****************************************************************************
# * Subroutine:  file_emptyAction                                            *
# * Description: This routine implements the "file_empty" action - if the    *
# *              specified file exists and is empty, we pass; otherwise we   *
# *              fail.                                                       *
# *                                                                          *
# * Parameters:  process: process hash                                       *
# * Returns:     0 to fail, 1 to pass                                        *
# ****************************************************************************
sub file_emptyAction
{
  my $process = shift;
  &terminateProgram("Must specify file for file_empty action")
    unless (my $file = &evaluate($process->{file}));
  return(-z $file);
}


# ****************************************************************************
# * Subroutine:  file_existsAction                                           *
# * Description: This routine implements the "file_exists" action - if the   *
# *              specified file exists, we pass; otherwise we fail.          *
# *                                                                          *
# * Parameters:  process: process hash                                       *
# * Returns:     0 to fail, 1 to pass                                        *
# ****************************************************************************
sub file_existsAction
{
  my $process = shift;
  &terminateProgram("Must specify file for file_exists action")
    unless (my $file = &evaluate($process->{file}));
  return(-e $file);
}


# ****************************************************************************
# * Subroutine:  file_modifiedAction                                         *
# * Description: This routine implements the "file_modified" action - if the *
# *              specified file exists and was modified within the specified *
# *              timeframe (resolution is 1 day), we pass; otherwise we fail.*
# *                                                                          *
# * Parameters:  process: process hash                                       *
# * Returns:     0 to fail, 1 to pass                                        *
# ****************************************************************************
sub file_modifiedAction
{
  my $process = shift;
  &terminateProgram("Must specify file for file_modified action")
    unless (my $file = &evaluate($process->{file}));
  my @stat = stat($file);
  return unless(scalar(@stat) > 1);
  my $modified = &toDate($stat[9]);
  my($after,$before);
  $after = $process->{after} if (exists $process->{after});
  $before = $process->{before} if (exists $process->{before});
  &terminateProgram('Must specify before or after for file_modified action')
    unless ($after || $before);
  &terminateProgram('after parameter for file_modified action is not '
                    . 'formatted as YYYY-MM-DD')
    unless (!$after || ($after =~ /$DATE_FORMAT/));
  &terminateProgram('before parameter for file_modified action is not '
                    . 'formatted as YYYY-MM-DD')
    unless (!$before || ($before =~ /$DATE_FORMAT/));
  if ($after && $before) {
    &terminateProgram('before and after parameters for file_modified action '
                      . 'cannot be the same date') if ($after eq $before);
    &terminateProgram('before and after parameters for file_modified action '
                      . 'must be in the correct order') if ($after lt $before);
    return(($modified gt $after) && ($modified lt $before));
  }
  elsif ($after) {
    return($modified gt $after);
  }
  else {
    return($modified lt $before);
  }
}


# ****************************************************************************
# * Subroutine:  file_writableAction                                         *
# * Description: This routine implements the "file_writable" action - if the *
# *              specified file exists and can be written to, we pass;       *
# *              otherwise we fail.                                          *
# *                                                                          *
# * Parameters:  process: process hash                                       *
# * Returns:     0 to fail, 1 to pass                                        *
# ****************************************************************************
sub file_writableAction
{
  my $process = shift;
  return(-w &evaluate($process->{file}));
}


# ****************************************************************************
# * Subroutine:  gridAction                                                  *
# * Description: This routine implements the "grid" action - it will submit  *
# *              a specified command file to the grid using qsub. If the job *
# *              was successfully submitted, we pass; otherwise we fail.     *
# *                                                                          *
# * Parameters:  process: process hash                                       *
# * Returns:     0 to fail, 1 to pass                                        *
# ****************************************************************************
sub gridAction
{
  my $process = shift;
  my @command = 'qsub';
  my $stderr = &evaluate($process->{stderr});
  my $stdout = &evaluate($process->{stdout});
  $stdout = '"' . $stdout . '"' if $stdout;
  $stderr = '"' . $stderr . '"' if $stderr;
  push @command,'-o',$stdout || '/dev/null';
  push @command,'-e',$stderr || '/dev/null';
  my $qargs = &evaluate($process->{qsub_args});
  push @command,split(/\s+/,$qargs) if ($qargs);
  push @command,'-A',$ACCOUNT if ($ACCOUNT);
  my $args = &evaluate($process->{args});
  &terminateProgram("Must specify args for grid action") unless ($args);
  push @command,"'$args'";
  print $handle '    ' . join(' ',@command),"\n" if ($DEBUG);
  return(1) if ($TEST);
  if ($system_handle) {
    print $system_handle join(' ',@command),"\n";
    return(1);
  }
  my $status = system(join ' ',@command);
  print $handle "    Status: $status\n" if ($DEBUG);
  return ($status) ? 0 : 1;
}


# ****************************************************************************
# * Subroutine:  lsfAction                                                   *
# * Description: This routine implements the "lsf" action - it will submit   *
# *              a specified command file to the LSF cluster using. If the   *
# *              job was successfully submitted, we pass; otherwise we fail. *
# *                                                                          *
# * Parameters:  process: process hash                                       *
# * Returns:     0 to fail, 1 to pass                                        *
# ****************************************************************************
sub lsfAction
{
  my $process = shift;
  my @command = 'bsub';
  my $stderr = &evaluate($process->{stderr});
  my $stdout = &evaluate($process->{stdout});
  $stdout = '"' . $stdout . '"' if $stdout;
  $stderr = '"' . $stderr . '"' if $stderr;
  push @command,'-o',$stdout || '/dev/null';
  push @command,'-e',$stderr || '/dev/null';
  my $qargs = &evaluate($process->{bsub_args});
  push @command,split(/\s+/,$qargs) if ($qargs);
  push @command,'-P',$ACCOUNT if ($ACCOUNT);
  my $args = &evaluate($process->{args});
  &terminateProgram("Must specify args for lsf action") unless ($args);
  push @command,"'$args'";
  print $handle '    ' . join(' ',@command),"\n" if ($DEBUG);
  return(1) if ($TEST);
  if ($system_handle) {
    print $system_handle join(' ',@command),"\n";
    return(1);
  }
  my $status = system(join ' ',@command);
  print $handle "    Status: $status\n" if ($DEBUG);
  return ($status) ? 0 : 1;
}


# ****************************************************************************
# * Subroutine:  mail_messageAction                                          *
# * Description: This routine implements the "mail_message" action - a       *
# *              specified message (with the item appended) is added to a    *
# *              message that will be mailed when the program terminates.    *
# *                                                                          *
# * Parameters:  process: process hash                                       *
# * Returns:     1 (pass)                                                    *
# ****************************************************************************
sub mail_messageAction
{
  my $process = shift;
  return(1) unless (scalar @message_stack);
  my $message = &evaluate($process->{message})
    || &terminateProgram("Must specify message for mail_message action");
  my $address = &evaluate($process->{recipient})
    || &terminateProgram("Must specify recipient for mail_message action");
  $recipient{$process->{name}} = $address;
  $mail{$process->{name}} .= "$message (" . $process->{item} . ")\n";
  return(1);
}


# ****************************************************************************
# * Subroutine:  mail_stackAction                                            *
# * Description: This routine implements the "mail_stack" action - the       *
# *              message stack is added to a message that will be mailed     *
# *              when the program terminates.                                *
# *                                                                          *
# * Parameters:  process: process hash                                       *
# * Returns:     1 (pass)                                                    *
# ****************************************************************************
sub mail_stackAction
{
  my $process = shift;
  return(1) unless (scalar @message_stack);
  my $address = &evaluate($process->{recipient})
    || &terminateProgram("Must specify recipient for mail_stack action");
  $recipient{$process->{name}} = $address;
  my $regex = $process->{regex} || '';
  my @filtered = grep(/$regex/,@message_stack) if ($regex);
  return(1) if ($regex && !scalar(@filtered));
  $mail{$process->{name}} .= join("\n",($regex) ? @filtered
                                                : @message_stack) . "\n";
  return(1);
}


# ****************************************************************************
# * Subroutine:  nullAction                                                  *
# * Description: This routine implements the "null" action - we simply       *
# *              return a "pass" status                                      *
# *                                                                          *
# * Parameters:  NONE                                                        *
# * Returns:     1 (pass)                                                    *
# ****************************************************************************
sub nullAction
{
  return(1);
}


# ****************************************************************************
# * Subroutine:  perlAction                                                  *
# * Description: This routine implements the "perl" action - it will execute *
# *              a specified command file using Perl. The return status      *
# *              status from the script determines success (0) or failure    *
# *              (non-zero).                                                 *
# *                                                                          *
# * Parameters:  process: process hash                                       *
# * Returns:     0 to fail, 1 to pass                                        *
# ****************************************************************************
sub perlAction
{
  my $process = shift;
  my @command = 'perl';
  my $args = &evaluate($process->{args});
  &terminateProgram("Must specify args for perl action") unless ($args);
  push @command,split(/\s+/,$args);
  my $stderr = &evaluate($process->{stderr});
  my $stdout = &evaluate($process->{stdout});
  push @command,'>'.$stdout if ($stdout);
  push @command,'2>'.$stderr if ($stderr);
  print $handle '    ' . join(' ',@command),"\n" if ($DEBUG);
  return(1) if ($TEST);
  if ($system_handle) {
    print $system_handle join(' ',@command),"\n";
    return(1);
  }
  my $status = system(join ' ',@command);
  print $handle "    Status: $status\n" if ($DEBUG);
  ($_ && !-s $_) && unlink($_) foreach ($stdout,$stderr);
  return ($status) ? 0 : 1;
}


# ****************************************************************************
# * Subroutine:  print_stackAction                                           *
# * Description: This routine implements the "print_stack" action - the      *
# *              message stack is displayed.                                 *
# *                                                                          *
# * Parameters:  NONE                                                        *
# * Returns:     1 (pass)                                                    *
# ****************************************************************************
sub print_stackAction
{
  print $handle join("\n",@message_stack),"\n";
  return(1);
}


# ****************************************************************************
# * Subroutine:  pythonAction                                                *
# * Description: This routine implements the "python" action - it will       *
# *              execute a specified command file using Perl. The return     *
# *              status status from the script determines success (0) or     *
# *              failure (non-zero).                                         *
# *                                                                          *
# * Parameters:  process: process hash                                       *
# * Returns:     0 to fail, 1 to pass                                        *
# ****************************************************************************
sub pythonAction
{
  my $process = shift;
  my @command = 'python';
  my $args = &evaluate($process->{args});
  &terminateProgram("Must specify args for python action") unless ($args);
  push @command,split(/\s+/,$args);
  my $stderr = &evaluate($process->{stderr});
  my $stdout = &evaluate($process->{stdout});
  push @command,'>'.$stdout if ($stdout);
  push @command,'2>'.$stderr if ($stderr);
  print $handle '    ' . join(' ',@command),"\n" if ($DEBUG);
  return(1) if ($TEST);
  if ($system_handle) {
    print $system_handle join(' ',@command),"\n";
    return(1);
  }
  my $status = system(join ' ',@command);
  print $handle "    Status: $status\n" if ($DEBUG);
  ($_ && !-s $_) && unlink($_) foreach ($stdout,$stderr);
  return ($status) ? 0 : 1;
}


# ****************************************************************************
# * Subroutine:  sleepAction                                                 *
# * Description: This routine implements the "sleep" action - we sleep for a *
# *              specified interval (in seconds - defaults to 5), then       *
# *              return a pass status.                                       *
# *                                                                          *
# * Parameters:  process: process hash                                       *
# * Returns:     1 (pass)                                                    *
# ****************************************************************************
sub sleepAction
{
  my $process = shift;
  my $time = (exists $process->{interval}) ? $process->{interval} : 5;
  $time = 5 unless ($time > 0);
  sleep($time);
  return(1);
}


# ****************************************************************************
# * Subroutine:  AUTOLOAD                                                    *
# * Description: A standard AUTOLOAD function. This is used to trap unknown  *
# *              actions and terminate.                                      *
# *                                                                          *
# * Parameters:  NONE                                                        *
# * Returns:     NONE                                                        *
# ****************************************************************************
sub AUTOLOAD
{
  (my $action = $AUTOLOAD) =~ s/^.*::(.+)Action$/$1/;
  &terminateProgram("Unknown action: $action");
}


sub toDate
{
  my @tm = localtime(shift);
  return(sprintf '%04d-%02d-%02d',$tm[5]+1900,$tm[4]+1,$tm[3]);
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
    elsif ('ARRAY' eq ref($item_ref->{$key})) {
      (my $nk = $key) =~ s/\(.+//;
      $data{$nk} = (scalar @{$item_ref->{$key}}) ? $item_ref->{$key}->[0] : '';
    }
    else {
      $data{$key} = $item_ref->{$key};
    }
  }
  return(%data);
}


# ****************************************************************************
# * POD documentation                                                        *
# ****************************************************************************
__END__

=head1 NAME

pipeline - generalized processing pipeline

=head1 SYNOPSIS

pipeline -config <flow config file> [-grammar <grammar file>]
  [-file <input file>] [-autopass <step>] [-autofail <step>]
  [-output <output file>] [-system <output file>] [-test]
  [-debug | -verbose] [-help]

=head1 DESCRIPTION

This program will accept as input one or more files (or a stream from STDIN)
containing items to interpret (with a configured grammar) and process (with
a configured process flow). Items are specified one per line, and will be in
a form specified by the grammar.

This program simply executes a defined process flow for a set of items as
parsed according to a specified grammar. The details of the exact type of
processing (data creation, data transformation, etc.) is contained in the
process flow and grammar configuration files.

See http://wiki/wiki/display/ScientificComputing/Processing+pipeline

=head1 RUN INSTRUCTIONS

This program acts as a filter - it accepts as input a file or "piped in"
stream (see EXAMPLES). Monitoring output goes to STDOUT, unless redirected by
the -output parameter.

The following options are supported:

  -config:   (reguired) XML configuration file describing process flow
  -grammar:  (optional) grammar for recursive-descent parser
  -file:     (optional) input file name or glob term
  -autopass: (optional) step to forse pass for
  -autofail: (optional) step to forse fail for
  -output:   (optional) send monitoring output to specified file
  -system:   (optional) send system commands to specified file
  -test:     (optional) display process steps, but do not execute them
  -verbose:  (optional) verbose monitoring output (chatty)
  -debug:    (optional) verbose monitoring output (chatty in the extreme)
  -help:     (optional) display usage help and exit

While passing in the grammar on the command line is optional, a grammar
is required for processed. If not specified on the command line, the
grammar must be specified in the configuration file.

Note that a "glob term" can be specified for the file name. For example,
if the -file parameter is specified as "*.fasta", every file in the current
directory ending with "fasta" will be processed. If the -file parameter is
not specified, input is expected on STDIN. Options must be separated by
spaces.

All output goes to STDOUT, unless redirected by the -output parameter.

=head1 EXAMPLES

pipeline -file transformants.txt -grammar chacrm.gra -config rubinlab.xml

=head1 EXIT STATUS

The following exit values are returned:

   0  Successful completion

  -1  An error occurred

=head1 BUGS

None known.

=head1 AUTHOR INFORMATION

Copyright 2007 by Howard Hughes Medical Institute

Author: Robert R. Svirskas, HHMI Janelia Farm Research Campus

Address bug reports and comments to:
svirskasr@janelia.hhmi.org

=cut
