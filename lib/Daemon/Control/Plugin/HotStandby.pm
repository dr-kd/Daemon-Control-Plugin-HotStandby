package Daemon::Control::Plugin::HotStandby;
use warnings;
use strict;
use Role::Tiny;
use Class::Method::Modifiers qw/fresh/;

# ABSTRACT: Daemon::Control plugin to bring up new processes before disposing of the old ones.

=head2 NAME

Daemon::Control::Plugin::HotStandby

=head2 DESCRIPTION

This is a plugin basically for PSGI workers so that a standby worker
can be spun up prior to terminating the original worker.

=head2 USAGE 

  Daemon::Control->with_plugins('HotStandby')->new({ ... });

=head2 NOTES and CAUTIONS

This is not a particularly smart hot standby daemon.  It uses double
the value of $self->kill_timeout to work out how long to wait before
killing the original process, after bringing its hot standby up.
L<HADaemon::Control> does something smarter, but it has the
disadvantage of being based on a forked, older version of
L<Daemon::Control>, and doesn't ship with any tests.  Hopefully one day
there will be a Daemon::Control::Plugin::HighAvailability that deals
with these problems, but for now this is a reasonable solution.  Just
test it thoroughly with your kit before you send it out into the wild.

Until we work out and optimise what needs to be factored out into
separate utility subroutines in L<Daemon::Control>, this module contains
far more code than is needed (copy/paste/refactor from the parent
module).  Also it might break depending on future releases post
version 0.001007 of L<Daemon::Control>.

=head2 LICENCE

This code can be distributed under the same terms as perl itself.

=head2 AUTHOR

Kieren Diment <zarquon@cpan.org>

=cut


around do_restart => sub {
  my $orig = shift;
  my ($self) = @_;

  # check old running
  $self->read_pid;
  my $old_pid = $self->pid;
  if ($self->pid && $self->pid_running) {
    $self->pretty_print("Found existing process");
  }
  else {   #    warn if not
    $self->pretty_print("No process running for hot standby zero downtime", "red");
  }

  $self->_finish_start;
  # Start new get pid.
  $self->read_pid;
  my $new_pid = $self->pid;
  # check new came up.  Die if failed.
  sleep (($self->kill_timeout * 2) + 1);


  return 1 unless $old_pid > 1;
  if ( $self->pid_running($old_pid) ) {
    my $failed = $self->_send_stop_signals($old_pid);
    return 1 if  $failed;
  } else {
    $self->pretty_print( "Not Running", "red" );
  }

  $self->_ensure_pid_file_exists;
  return 0;
};

fresh _finish_start => sub {
    my ($self) = @_;
    $self->_create_resource_dir;

    $self->fork( 2 ) unless defined $self->fork;
    $self->_double_fork if $self->fork == 2;
    $self->_fork if $self->fork == 1;
    $self->_foreground if $self->fork == 0;
    $self->pretty_print( "Started" );
    return 0;
};

fresh _send_stop_signals => sub {
  my ($self, $start_pid) = @_;
 SIGNAL:
  foreach my $signal (@{ $self->stop_signals }) {
    $self->trace( "Sending $signal signal to pid $start_pid..." );
    kill $signal => $start_pid;
    
    for (1..$self->kill_timeout)
      {
	# abort early if the process is now stopped
	$self->trace("checking if pid $start_pid is still running...");
	last if not $self->pid_running($start_pid);
	sleep 1;
      }
    last unless $self->pid_running($start_pid);
  }
  if ( $ARGV[0] ne 'restart' && $self->pid_running($start_pid) ) {
    $self->pretty_print( "Failed to Stop", "red" );
    return 1;
  }
  $self->pretty_print( "Stopped" );
};

fresh _ensure_pid_file_exists => sub {
	my ($self) = @_;
	if ( ! -f $self->pid_file ) {
		$self->pid( 0 ); # Make PID invalid.
		$self->write_pid();
	}
};



# We need to nuke these methods and replace with our own until
# Daemon::Control supports what we want to do with them.

around 'pid_running' => sub {
	my $orig = shift;
	my ($self, $pid) = @_;
	$pid ||= $self->read_pid;

	return 0 unless $self->pid >= 1;
	return 0 unless kill 0, $self->pid;

	if ( $self->scan_name ) {
		open my $lf, "-|", "ps", "-p", $self->pid, "-o", "command="
		  or die "Failed to get pipe to ps for scan_name.";
		while ( my $line = <$lf> ) {
			return 1 if $line =~ $self->scan_name;
		}
		return 0;
	}
	# Scan name wasn't used, testing normal PID.
	return kill 0, $self->pid;
};


1;
