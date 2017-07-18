#!/usr/bin/perl
################################################################################
#
# Copyright (c) 2014-2017, Cassandra Brockett
# Permission not granted for commercial usage, without a full code review, you
# have been warned!
#
# Script uses an sqlite database for the backend, logs entries, and hooks irssi
# for commands.
#
# Not controllable/editable from irssi, it requires a script reload to accept
# changes... at the moment, it's on my 'honeydo' list to fix that sometime...
################################################################################
use strict;
use vars qw($VERSION %IRSSI);

use Irssi;

use DBI;

use Data::Dumper;

$VERSION = "0.1.2";
%IRSSI = (
    authors     => "Cassandra Brockett",
    contact     => "cbrockett\@ophiuchi.net",
    name        => "autohello",
    description => "Say hello to all users that join a channel on every joining nick",
    license     => "Creative Commons",
    url         => "",
    changed     => "20170325",
    modules     => ""
);


################################################################################
# Config: Setup database and load in config.
#
# If this is a new install, setup the database for use
#
################################################################################
my $dbh = DBI->connect("dbi:SQLite:dbname=.irssi/autohello.sqlite3","","");

my $tablehashref = $dbh->selectall_hashref("SELECT * FROM sqlite_master WHERE type='table';", "name");

#print Dumper($tablehashref);

if (%$tablehashref{'config'} == undef) {
	$dbh->do("CREATE TABLE config (option, value)");
}

if (%$tablehashref{'seenpeople'} == undef) {
	$dbh->do("CREATE TABLE seenpeople (chatnet, channel, address, time)");
}

my $mynickbase	= "illi";

my $alwaysgreet	= "Newbie";

my @ah_chanlist = (
	"blitzed/#yayforqueers",
	"ophiuchi/#scripttest"
	);

my $welcometext  = "[auto]: Hi %s, and welcome to %s.";
my $welcometext2 = "[auto]: Please say hi and be patient, folks are in and out :)";

my $wbtext = "[auto]: Welcome Back %s!";


################################################################################
# Event Subroutine.
################################################################################
sub event_message_join ($$$$) {
	my ($server, $channel, $nick, $address) = @_;

	# Short-circuit this if it's me
	if ($nick =~ /$mynickbase.*/) {
		return;
	}

	my $chan;
	my $chanpair;

	my %svrhash = %{$server};

	my $chatnet = $svrhash{chatnet};
	chomp($chatnet);

	foreach $chanpair (@ah_chanlist) {
#		print Dumper($chanpair);

		if ($chanpair eq "$chatnet/$channel") {
			if ($nick =~ /$alwaysgreet.*/) {
				# Message 1
				my $message = sprintf("MSG $channel $welcometext", $nick, $channel);
				$server->command($message);

				# Message 2
				my $message = sprintf("MSG $channel $welcometext2", $nick, $channel);
				$server->command($message);
		
			} else {
				my $sth = $dbh->prepare("SELECT * FROM seenpeople WHERE chatnet = ? AND channel = ? AND address = ?");
				$sth->bind_param(1, $chatnet);
				$sth->bind_param(2, $channel);
				$sth->bind_param(3, $address);
				$sth->execute();

				# Might not be needed....
				my $seencheck = $sth->fetchall_arrayref;

#				print Dumper($sth->rows);
#				print Dumper($seencheck);
			
				if ($sth->rows == 0) {
					# Message 1
					my $message = sprintf("MSG $channel $welcometext", $nick, $channel);
					$server->command($message);

					# Message 2
					my $message = sprintf("MSG $channel $welcometext2", $nick, $channel);
					$server->command($message);

					my $writesth = $dbh->prepare("INSERT INTO seenpeople (chatnet, channel, address, time) VALUES (?, ?, ?, datetime('now'))");
					$writesth->bind_param(1, $chatnet);
					$writesth->bind_param(2, $channel);
					$writesth->bind_param(3, $address);
					$writesth->execute();
				} else {
					# Welcome Back message
					my $message = sprintf("MSG $channel $wbtext", $nick, $channel);
					$server->command($message);
				}
			}
		}
	}
}	

##################################################################
#print Dumper(%autohello_channels);
#print Dumper($autohello_channels{blitzed});

Irssi::signal_add('message join', 'event_message_join');

