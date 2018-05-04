#!/usr/bin/perl

use warnings;
use strict;
use POE qw/Component::IRC::State Component::IRC::Plugin::Connector Component::IRC::Plugin::AutoJoin Wheel::Run/;
use BSD::Resource;
use LWP::Simple;
use Class::Date;
use Safe;
use Data::Dumper;

my %channels	= (
	'#tdbot'	=> '');

sub _start {
	my ($kernel, $heap)	= @_[KERNEL, HEAP];

	$heap->{irc}->yield	( register	=> 'all' );

	# Add plugins
	$heap->{irc}->plugin_add ('Connector'	=> POE::Component::IRC::Plugin::Connector->new( delay	=> 30));
	$heap->{irc}->plugin_add ('AutoJoin'	=> POE::Component::IRC::Plugin::AutoJoin->new( Channels	=> $heap->{channels}, RejoinOnKick	=> 1 ));

	$heap->{irc}->yield	('connect');

	# Handle events when children exit
	$kernel->sig (CHLD	=> 'child_exit');
}

sub irc_001 {
	my ($kernel, $heap)	= @_[KERNEL, HEAP];
}

sub child_exit {
	my ($kernel, $heap, $pid, $retval)	= @_[KERNEL, HEAP, ARG1, ARG2];

	# We have to search for the PID amongst our wheels
	my $id;
	for (keys %{$heap->{safe_procs}}) {
		if ($heap->{safe_procs}{$_}->{'PID'} == $pid) {
			$id	= $_;
			last;
		}
	}

	# If we do not have an ID, then the reference is already gone and the proc exited normally
	return unless $id;

	my $details	= delete ($heap->{safe_procs}{$id});

	# Stop the alarm
	$kernel->alarm_remove($details->{'ALARM'});

	my $signal	= $retval >> 8;
	$signal		= $signal & 127;

	if ($signal	== 12) { # Corresponds with exceeding a limit, probably memory
		my $who		= ($details->{'WHO'}	=~ /^([^!]+)/)[0];
		my $code	= $details->{'CODE'};

		$heap->{irc}->yield('privmsg', $details->{'CHANNEL'}, "Execution of ($code) by $who exceeded memory limits");
	} elsif ($retval) {
		my $code	= $details->{'CODE'};

		$heap->{irc}->yield('privmsg', $details->{'CHANNEL'}, "Unknown error executing ($code)");
	}
}

sub get {
	my $uri	= shift;
	return LWP::Simple::get($uri);
}
sub execute_safe {
	my $code	= shift;

	# Set memory limits for execution
	my $lim		= setrlimit (RLIMIT_AS, 30*(2**20), 35*(2**20));

	my $safe	= new Safe;
	$safe->permit_only (qw/:base_core :base_mem :base_loop padany gvsv gv/);
	$safe->share('get');

	my $return	= $safe->reval($code);

	local $|=1;
	if ($return) {
		# We got some data back, print to STDOUT so POE can trigger an event
		print $return;
	} elsif ($@) {
		# We got an error, we can handle this differently in the future
		print "Error: $@";
	}
}

sub irc_public {
	my ($kernel, $heap, $who, $where, $public)	= @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
	my $channel	= $where->[0];

	if ($public	=~ /^!pl / || $public	=~ /^!perl /) {
		# Executing perl code
		my $test	= "lol";
		my $code	= ($public	=~ /^![a-z]+ (.*)/)[0];

		if (keys %{$heap->{safe_procs}} > 4) {
			$heap->{irc}->yield('privmsg', $channel, 'Too many simultaneous executions');
			return 0;
		}

		my $wheel	= POE::Wheel::Run->new (
			Program		=> \&execute_safe,
			ProgramArgs	=> [$code],

			StdoutEvent	=> 'execute_out',
			StderrEvent	=> 'execute_debug',
			StdoutFilter	=> POE::Filter::Stream->new(),
		);

		# Set an alarm so we can terminate this process if it runs too long
		my $alarm	= $kernel->alarm_set( execute_timeout	=> time() + 10, $wheel->ID);

		# Store details keyed by PID so we can look up output information
		# at a later date
		$heap->{safe_procs}{$wheel->ID}	= {
			WHEEL	=> $wheel,
			PID	=> $wheel->PID,
			ALARM	=> $alarm,
			CODE	=> $code,
			CHANNEL	=> $channel,
			WHO	=> $who };
	}
}

sub execute_debug {
	my ($kernel, $heap, $output)	= @_[KERNEL, HEAP, ARG0];

	print STDERR "Debug from child: $output\n";
}

sub execute_timeout {
	my ($kernel, $heap, $wheel_id)	= @_[KERNEL, HEAP, ARG0];

	print STDERR "Execute timed out!\n";

	# Remove the references
	my $details	 = delete $heap->{safe_procs}{$wheel_id};

	my $error;
#	if (length($details->{'CODE'}) > 20) {
#		$error	= substr($details->{'CODE'},10) . "...";
#	} else {
		$error = $details->{'CODE'};
#	}

	my $who	= ($details->{'WHO'}	=~ /^([^!]+)/)[0];

	$error = "Execution of ($error) by $who timed out";

	# Print an error to IRC
	$heap->{irc}->yield('privmsg', $details->{'CHANNEL'}, $error);

	# Kill the process
	$details->{'WHEEL'}->kill;
}

sub execute_out {
	my ($kernel, $heap, $output, $wheel_id)	= @_[KERNEL, HEAP, ARG0, ARG1];

	print "Got output: $output\nFrom $wheel_id\n";

	my $details	= $heap->{safe_procs}{$wheel_id};

	# Print to IRC
	my @lines	= split(/\n/, $output);
	if (@lines > 5) {
		@lines	= @lines[0..4];
		push (@lines, "Error: Output exceeded maximum number of lines");
	}

	for (@lines) {
		$heap->{irc}->yield('privmsg', $details->{'CHANNEL'}, $_);
	}

	# Stop the alarm
	$kernel->alarm_remove($details->{'ALARM'});

	# Delete the reference
	delete $heap->{safe_procs}{$wheel_id};
}

sub irc_disconnected {
	print STDERR "Disconnected!\n";
}

sub irc_error {
	print STDERR "IRC Error!\n";
}

my $irc	= POE::Component::IRC::State->spawn(
	nick		=> 'TDBot',
	ircname		=> 'dicks',
	username	=> 'lol',
#	debug		=> 1,
	server		=> 'irc.buttes.org' ) or die "Failed to create IRC session: $!";


POE::Session->create (
	package_states	=> [
		main		=> [ qw/_start irc_001 irc_public execute_out execute_timeout execute_debug child_exit/ ],
	],
	heap		=> {	irc		=> $irc,
				channels	=> \%channels,
				safe_procs	=> {}	},
);

POE::Kernel->run;