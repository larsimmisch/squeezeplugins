# IRBlaster::Settings.pm
package Plugins::IRBlaster::Settings;

# SqueezeCenter Copyright (c) 2001-2008 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License, 
# version 2.

use strict;
use base qw(Slim::Web::Settings);

use Slim::Utils::Strings qw(string);
use Slim::Utils::Log;
use Slim::Utils::Prefs;

# ----------------------------------------------------------------------------
# Global variables
# ----------------------------------------------------------------------------

my $gMaxItemsPerAction	= 5;	# IR commands per action (on/off/volup/voldown) in webinterface

# ----------------------------------------------------------------------------
# References to other classes
my $classPlugin		= undef;

# ----------------------------------------------------------------------------
my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.irblaster',
	'defaultLevel' => 'OFF',
	'description'  => 'PLUGIN_IRBLASTER_MODULE_NAME',
});

# ----------------------------------------------------------------------------
my $prefs = preferences( 'plugin.irblaster');


$prefs->migrate( 1, sub {
	$prefs->set('conffilepath',Slim::Utils::Prefs::OldPrefs->get('plugin_irblast_conffilepath'));
	1;
});

$prefs->migrateClient( 1, sub {
	my( $clientprefs, $client) = @_;

	$clientprefs->set('poweron_count',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_count_poweron'));
	$clientprefs->set('poweron_remote',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_remote_poweron'));
	$clientprefs->set('poweron_command',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_command_poweron'));
	$clientprefs->set('poweron_delay',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_delay_poweron'));

	$clientprefs->set('poweroff_count',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_count_poweroff'));
	$clientprefs->set('poweroff_remote',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_remote_poweroff'));
	$clientprefs->set('poweroff_command',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_command_poweroff'));
	$clientprefs->set('poweroff_delay',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_delay_poweroff'));

	$clientprefs->set('volumeup_count',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_count_volumeup'));
	$clientprefs->set('volumeup_remote',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_remote_volumeup'));
	$clientprefs->set('volumeup_command',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_command_volumeup'));
	$clientprefs->set('volumeup_delay',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_delay_volumeup'));

	$clientprefs->set('volumedown_count',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_count_volumedown'));
	$clientprefs->set('volumedown_remote',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_remote_volumedown'));
	$clientprefs->set('volumedown_command',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_command_volumedown'));
	$clientprefs->set('volumedown_delay',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_delay_volumedown'));

	$clientprefs->set('fixedvolume',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_fixedvolume'));
	$clientprefs->set('repeater',Slim::Utils::Prefs::OldPrefs->clientGet($client,'plugin_irblast_repeater'));
	1;
});

# ----------------------------------------------------------------------------
# Define own constructor
# - to save references to Plugin.pm
# ----------------------------------------------------------------------------
sub new {
	my $class = shift;

	$classPlugin = shift;

	$log->debug( "*** IRBlaster::Settings::new() " . $classPlugin . "\n");

	$class->SUPER::new();

	return $class;
}

# ----------------------------------------------------------------------------
# Name in the settings dropdown
# ----------------------------------------------------------------------------
sub name {
	return 'PLUGIN_IRBLASTER_MODULE_NAME';
}

# ----------------------------------------------------------------------------
# Webpage served for settings
# ----------------------------------------------------------------------------
sub page {
	return 'plugins/IRBlaster/setup_index.html';
}

# ----------------------------------------------------------------------------
# Settings are per player
# ----------------------------------------------------------------------------
sub needsClient {
	return 1;
}

# ----------------------------------------------------------------------------
# Only show plugin for SB2/3 and Transporter
# ----------------------------------------------------------------------------
sub validFor {
	my $class = shift;
	my $client = shift;

	my $valid = $client->isPlayer && ( ( $client->model() eq 'squeezebox2') || ( $client->model() eq 'transporter'));

	return $valid;
}

# ----------------------------------------------------------------------------
# Handler for settings for the four events (on,off,volup,voldown) and more
# ----------------------------------------------------------------------------
sub handler {
	my ($class, $client, $params) = @_;

# Sonm debugging info
#$log->debug("*** here\n");
#my %hhh = %$params;
#while( my ($kk, $vv) = each %hhh) {
#$log->debug("*** Key: " . $kk . "  Value: " . $vv . "\n");
#}

	
	# $client is the client that is selected on the right side of the web interface!!!
	# We need the client identified by 'player'

	# Find player that fits the mac address supplied in $params->{'player'}
	my @playerItems = Slim::Player::Client::clients();
	foreach my $play (@playerItems) {
		if( $params->{'player'} eq $play->macaddress()) {
			$client = $play;
			last;
		}
	}
	if( !defined( $client)) {
		return $class->SUPER::handler($client, $params);
	}
	
	$log->debug( "*** IR-Blaster: found player: " . $client . "\n");
	
	# Fill in name of player
	if( !$params->{'playername'}) {
		$params->{'playername'} = $client->name();
	}


	# ************************
	# ----- Config files -----

	# Needs to be here to make sure new .conf files are picked up immediately
	
	# Get path to config files
	if( !$params->{'conffilepath'}) {
		$params->{'conffilepath'} = $prefs->get( 'conffilepath');
	} else {
		$prefs->set( 'conffilepath', $params->{'conffilepath'});
	}
	# User wants to reload config files
	if( $params->{'mode'} eq "reload") {
#		Plugins::IRBlaster::Plugin::loadRemotes();
		$classPlugin->loadRemotes();
	}

	# *********************************
	# ----- Remote codes dropdown -----

#	my %remotes = Plugins::IRBlaster::Plugin::getRemotes();
	my %remotes = $classPlugin->getRemotes();

	# Empty all remote codes
	$params->{'remotes'} = ();
	# Fill all remote codes
	if( keys ( %remotes) > 0) {
		while( ( my $key, my $item) = each( %remotes)) {
			$params->{'remotes'}{$key} = $item;
		}
	}
	
	my $tempPref1;
	my $tempPref2;
	my $tempPref3;

	# ********************
	# ----- Power on -----

	# Make sure there is at least one entry in preferences file
	if( $prefs->client($client)->get('poweron_count') eq "") {
		$prefs->client($client)->set('poweron_count', '1');

		$tempPref1 = $prefs->client($client)->get('poweron_remote');
		$tempPref1->[0] = '-1';
		$prefs->client($client)->set('poweron_remote', $tempPref1);
		$tempPref2 = $prefs->client($client)->get('poweron_command');
		$tempPref2->[0] = '';
		$prefs->client($client)->set('poweron_command', $tempPref2);
		$tempPref3 = $prefs->client($client)->get('poweron_delay');
		$tempPref3->[0] = '0.25';
		$prefs->client($client)->set('poweron_delay', $tempPref3);
	}

	# Get data from webinterface and set data in preferences file
	$tempPref1 = $prefs->client($client)->get('poweron_remote');
	$tempPref2 = $prefs->client($client)->get('poweron_command');
	$tempPref3 = $prefs->client($client)->get('poweron_delay');
	for( my $i = 0; $i < $prefs->client($client)->get('poweron_count'); $i++) {
		if( $params->{'selRemPowerOn_' . $i} ne "") {
			$tempPref1->[$i] = $params->{'selRemPowerOn_' . $i};
			$tempPref2->[$i] = $params->{'selCmdPowerOn_' . $i};
			$tempPref3->[$i] = $params->{'selDelayPowerOn_' . $i};
		}
	}
	$prefs->client($client)->set('poweron_remote', $tempPref1);
	$prefs->client($client)->set('poweron_command', $tempPref2);
	$prefs->client($client)->set('poweron_delay', $tempPref3);

	# Add row clicked - only add if maximum is not reached
	my $button = -1;
	for( my $i = 0; $i < $gMaxItemsPerAction; $i++) {
		if( $params->{'mode'} eq "addPowerOn_" . $i) {
			$button = $i;
			last;
		}
	}
	if( $button != -1) {
		my $count = $prefs->client($client)->get('poweron_count');
		if( $count < $gMaxItemsPerAction) {
			$tempPref1 = $prefs->client($client)->get('poweron_remote');
			$tempPref2 = $prefs->client($client)->get('poweron_command');
			$tempPref3 = $prefs->client($client)->get('poweron_delay');
			for( my $i = $button; $i < $prefs->client($client)->get('poweron_count'); $i++) {
				my $from = $count - $i + $button - 1;
				my $to = $from + 1;
				$tempPref1->[$to] = $prefs->client($client)->get('poweron_remote')->[$from];
				$tempPref2->[$to] = $prefs->client($client)->get('poweron_command')->[$from];
				$tempPref3->[$to] = $prefs->client($client)->get('poweron_delay')->[$from];
			}
			$tempPref1->[$button] = '-1';
			$tempPref2->[$button] = '';
			$tempPref3->[$button] = '0.25';

			$prefs->client($client)->set('poweron_remote',$tempPref1);
			$prefs->client($client)->set('poweron_command',$tempPref2);
			$prefs->client($client)->set('poweron_delay',$tempPref3);
			
			$prefs->client($client)->set('poweron_count', $count + 1);
		}
	}

	# Remove row clicked - only remove if minimum is not reached
	$button = -1;
	for( my $i = 0; $i < $prefs->client($client)->get('poweron_count'); $i++) {
		if( $params->{'mode'} eq "delPowerOn_" . $i) {
			$button = $i;
			last;
		}
	}
	if( $button != -1) {
		my $count = $prefs->client($client)->get('poweron_count');
		if( $count > 1) {
			$tempPref1 = $prefs->client($client)->get('poweron_remote');
			$tempPref2 = $prefs->client($client)->get('poweron_command');
			$tempPref3 = $prefs->client($client)->get('poweron_delay');

			for( my $i = $button; $i < $prefs->client($client)->get('poweron_count') - 1; $i++) {
				my $from = $i + 1;
				my $to = $i;
				$tempPref1->[$to] = $prefs->client($client)->get('poweron_remote')->[$from];
				$tempPref2->[$to] = $prefs->client($client)->get('poweron_command')->[$from];
				$tempPref3->[$to] = $prefs->client($client)->get('poweron_delay')->[$from];
			}
			$prefs->client($client)->set('poweron_remote',$tempPref1);
			$prefs->client($client)->set('poweron_command',$tempPref2);
			$prefs->client($client)->set('poweron_delay',$tempPref3);

			$prefs->client($client)->set('poweron_count', $count - 1);
		}
	}
	
	# Test buttons clicked
	for( my $i = 0; $i < $prefs->client($client)->get('poweron_count'); $i++) {
		if( $params->{'mode'} eq "testPowerOn_" . $i) {
#			Plugins::IRBlaster::Plugin::IRBlastSend( $client,
			$classPlugin->IRBlastSend( $client,
				$prefs->client($client)->get('poweron_remote')->[$i],
				$prefs->client($client)->get('poweron_command')->[$i]);
		}
	}	
	
	# Get data from pref file and set in webinterface
	for( my $i = 0; $i < $prefs->client($client)->get('poweron_count'); $i++) {
		my %list_form = %$params;
		$list_form{'max'} = $gMaxItemsPerAction;
		$list_form{'count'} = $prefs->client($client)->get('poweron_count');
		$list_form{'id'} = $i;
		$list_form{'poweron_remote'} = $prefs->client($client)->get('poweron_remote')->[$i];
		$list_form{'poweron_command'} = $prefs->client($client)->get('poweron_command')->[$i];
		$list_form{'poweron_delay'} = $prefs->client($client)->get('poweron_delay')->[$i];
		$params->{'poweron_list'} .= ${Slim::Web::HTTP::filltemplatefile('plugins/IRBlaster/poweron_list.html',\%list_form)};
	}

	# *********************
	# ----- Power off -----

	# Make sure there is at least one entry in preferences file
	if( $prefs->client($client)->get('poweroff_count') eq "") {
		$prefs->client($client)->set('poweroff_count', '1');

		$tempPref1 = $prefs->client($client)->get('poweroff_remote');
		$tempPref1->[0] = '-1';
		$prefs->client($client)->set('poweroff_remote', $tempPref1);
		$tempPref2 = $prefs->client($client)->get('poweroff_command');
		$tempPref2->[0] = '';
		$prefs->client($client)->set('poweroff_command', $tempPref2);
		$tempPref3 = $prefs->client($client)->get('poweroff_delay');
		$tempPref3->[0] = '0.25';
		$prefs->client($client)->set('poweroff_delay', $tempPref3);
	}

	# Get data from webinterface and set data in preferences file
	$tempPref1 = $prefs->client($client)->get('poweroff_remote');
	$tempPref2 = $prefs->client($client)->get('poweroff_command');
	$tempPref3 = $prefs->client($client)->get('poweroff_delay');
	for( my $i = 0; $i < $prefs->client($client)->get('poweroff_count'); $i++) {
		if( $params->{'selRemPowerOff_' . $i} ne "") {
			$tempPref1->[$i] = $params->{'selRemPowerOff_' . $i};
			$tempPref2->[$i] = $params->{'selCmdPowerOff_' . $i};
			$tempPref3->[$i] = $params->{'selDelayPowerOff_' . $i};
		}
	}
	$prefs->client($client)->set('poweroff_remote', $tempPref1);
	$prefs->client($client)->set('poweroff_command', $tempPref2);
	$prefs->client($client)->set('poweroff_delay', $tempPref3);

	# Add row clicked - only add if maximum is not reached
	my $button = -1;
	for( my $i = 0; $i < $gMaxItemsPerAction; $i++) {
		if( $params->{'mode'} eq "addPowerOff_" . $i) {
			$button = $i;
			last;
		}
	}
	if( $button != -1) {
		my $count = $prefs->client($client)->get('poweroff_count');
		if( $count < $gMaxItemsPerAction) {
			$tempPref1 = $prefs->client($client)->get('poweroff_remote');
			$tempPref2 = $prefs->client($client)->get('poweroff_command');
			$tempPref3 = $prefs->client($client)->get('poweroff_delay');
			for( my $i = $button; $i < $prefs->client($client)->get('poweroff_count'); $i++) {
				my $from = $count - $i + $button - 1;
				my $to = $from + 1;
				$tempPref1->[$to] = $prefs->client($client)->get('poweroff_remote')->[$from];
				$tempPref2->[$to] = $prefs->client($client)->get('poweroff_command')->[$from];
				$tempPref3->[$to] = $prefs->client($client)->get('poweroff_delay')->[$from];
			}
			$tempPref1->[$button] = '-1';
			$tempPref2->[$button] = '';
			$tempPref3->[$button] = '0.25';

			$prefs->client($client)->set('poweroff_remote',$tempPref1);
			$prefs->client($client)->set('poweroff_command',$tempPref2);
			$prefs->client($client)->set('poweroff_delay',$tempPref3);
			
			$prefs->client($client)->set('poweroff_count', $count + 1);
		}
	}

	# Remove row clicked - only remove if minimum is not reached
	$button = -1;
	for( my $i = 0; $i < $prefs->client($client)->get('poweroff_count'); $i++) {
		if( $params->{'mode'} eq "delPowerOff_" . $i) {
			$button = $i;
			last;
		}
	}
	if( $button != -1) {
		my $count = $prefs->client($client)->get('poweroff_count');
		if( $count > 1) {
			$tempPref1 = $prefs->client($client)->get('poweroff_remote');
			$tempPref2 = $prefs->client($client)->get('poweroff_command');
			$tempPref3 = $prefs->client($client)->get('poweroff_delay');

			for( my $i = $button; $i < $prefs->client($client)->get('poweroff_count') - 1; $i++) {
				my $from = $i + 1;
				my $to = $i;
				$tempPref1->[$to] = $prefs->client($client)->get('poweroff_remote')->[$from];
				$tempPref2->[$to] = $prefs->client($client)->get('poweroff_command')->[$from];
				$tempPref3->[$to] = $prefs->client($client)->get('poweroff_delay')->[$from];
			}
			$prefs->client($client)->set('poweroff_remote',$tempPref1);
			$prefs->client($client)->set('poweroff_command',$tempPref2);
			$prefs->client($client)->set('poweroff_delay',$tempPref3);

			$prefs->client($client)->set('poweroff_count', $count - 1);
		}
	}
	
	# Test buttons clicked
	for( my $i = 0; $i < $prefs->client($client)->get('poweroff_count'); $i++) {
		if( $params->{'mode'} eq "testPowerOff_" . $i) {
#			Plugins::IRBlaster::Plugin::IRBlastSend( $client,
			$classPlugin->IRBlastSend( $client,
				$prefs->client($client)->get('poweroff_remote')->[$i],
				$prefs->client($client)->get('poweroff_command')->[$i]);
		}
	}	
	
	# Get data from pref file and set in webinterface
	for( my $i = 0; $i < $prefs->client($client)->get('poweroff_count'); $i++) {
		my %list_form = %$params;
		$list_form{'max'} = $gMaxItemsPerAction;
		$list_form{'count'} = $prefs->client($client)->get('poweroff_count');
		$list_form{'id'} = $i;
		$list_form{'poweroff_remote'} = $prefs->client($client)->get('poweroff_remote')->[$i];
		$list_form{'poweroff_command'} = $prefs->client($client)->get('poweroff_command')->[$i];
		$list_form{'poweroff_delay'} = $prefs->client($client)->get('poweroff_delay')->[$i];
		$params->{'poweroff_list'} .= ${Slim::Web::HTTP::filltemplatefile('plugins/IRBlaster/poweroff_list.html',\%list_form)};
	}

	# *********************
	# ----- Volume up -----

	# Make sure there is at least one entry in preferences file
	if( $prefs->client($client)->get('volumeup_count') eq "") {
		$prefs->client($client)->set('volumeup_count', '1');

		$tempPref1 = $prefs->client($client)->get('volumeup_remote');
		$tempPref1->[0] = '-1';
		$prefs->client($client)->set('volumeup_remote', $tempPref1);
		$tempPref2 = $prefs->client($client)->get('volumeup_command');
		$tempPref2->[0] = '';
		$prefs->client($client)->set('volumeup_command', $tempPref2);
		$tempPref3 = $prefs->client($client)->get('volumeup_delay');
		$tempPref3->[0] = '0.25';
		$prefs->client($client)->set('volumeup_delay', $tempPref3);
	}

	# Get data from webinterface and set data in preferences file
	$tempPref1 = $prefs->client($client)->get('volumeup_remote');
	$tempPref2 = $prefs->client($client)->get('volumeup_command');
	$tempPref3 = $prefs->client($client)->get('volumeup_delay');
	for( my $i = 0; $i < $prefs->client($client)->get('volumeup_count'); $i++) {
		if( $params->{'selRemVolumeUp_' . $i} ne "") {
			$tempPref1->[$i] = $params->{'selRemVolumeUp_' . $i};
			$tempPref2->[$i] = $params->{'selCmdVolumeUp_' . $i};
			$tempPref3->[$i] = $params->{'selDelayVolumeUp_' . $i};
		}
	}
	$prefs->client($client)->set('volumeup_remote', $tempPref1);
	$prefs->client($client)->set('volumeup_command', $tempPref2);
	$prefs->client($client)->set('volumeup_delay', $tempPref3);

	# Add row clicked - only add if maximum is not reached
	my $button = -1;
	for( my $i = 0; $i < $gMaxItemsPerAction; $i++) {
		if( $params->{'mode'} eq "addVolumeUp_" . $i) {
			$button = $i;
			last;
		}
	}
	if( $button != -1) {
		my $count = $prefs->client($client)->get('volumeup_count');
		if( $count < $gMaxItemsPerAction) {
			$tempPref1 = $prefs->client($client)->get('volumeup_remote');
			$tempPref2 = $prefs->client($client)->get('volumeup_command');
			$tempPref3 = $prefs->client($client)->get('volumeup_delay');
			for( my $i = $button; $i < $prefs->client($client)->get('volumeup_count'); $i++) {
				my $from = $count - $i + $button - 1;
				my $to = $from + 1;
				$tempPref1->[$to] = $prefs->client($client)->get('volumeup_remote')->[$from];
				$tempPref2->[$to] = $prefs->client($client)->get('volumeup_command')->[$from];
				$tempPref3->[$to] = $prefs->client($client)->get('volumeup_delay')->[$from];
			}
			$tempPref1->[$button] = '-1';
			$tempPref2->[$button] = '';
			$tempPref3->[$button] = '0.25';

			$prefs->client($client)->set('volumeup_remote',$tempPref1);
			$prefs->client($client)->set('volumeup_command',$tempPref2);
			$prefs->client($client)->set('volumeup_delay',$tempPref3);
			
			$prefs->client($client)->set('volumeup_count', $count + 1);
		}
	}

	# Remove row clicked - only remove if minimum is not reached
	$button = -1;
	for( my $i = 0; $i < $prefs->client($client)->get('volumeup_count'); $i++) {
		if( $params->{'mode'} eq "delVolumeUp_" . $i) {
			$button = $i;
			last;
		}
	}
	if( $button != -1) {
		my $count = $prefs->client($client)->get('volumeup_count');
		if( $count > 1) {
			$tempPref1 = $prefs->client($client)->get('volumeup_remote');
			$tempPref2 = $prefs->client($client)->get('volumeup_command');
			$tempPref3 = $prefs->client($client)->get('volumeup_delay');

			for( my $i = $button; $i < $prefs->client($client)->get('volumeup_count') - 1; $i++) {
				my $from = $i + 1;
				my $to = $i;
				$tempPref1->[$to] = $prefs->client($client)->get('volumeup_remote')->[$from];
				$tempPref2->[$to] = $prefs->client($client)->get('volumeup_command')->[$from];
				$tempPref3->[$to] = $prefs->client($client)->get('volumeup_delay')->[$from];
			}
			$prefs->client($client)->set('volumeup_remote',$tempPref1);
			$prefs->client($client)->set('volumeup_command',$tempPref2);
			$prefs->client($client)->set('volumeup_delay',$tempPref3);

			$prefs->client($client)->set('volumeup_count', $count - 1);
		}
	}
	
	# Test buttons clicked
	for( my $i = 0; $i < $prefs->client($client)->get('volumeup_count'); $i++) {
		if( $params->{'mode'} eq "testVolumeUp_" . $i) {
#			Plugins::IRBlaster::Plugin::IRBlastSend( $client,
			$classPlugin->IRBlastSend( $client,
				$prefs->client($client)->get('volumeup_remote')->[$i],
				$prefs->client($client)->get('volumeup_command')->[$i]);
		}
	}	
	
	# Get data from pref file and set in webinterface
	for( my $i = 0; $i < $prefs->client($client)->get('volumeup_count'); $i++) {
		my %list_form = %$params;
		$list_form{'max'} = $gMaxItemsPerAction;
		$list_form{'count'} = $prefs->client($client)->get('volumeup_count');
		$list_form{'id'} = $i;
		$list_form{'volumeup_remote'} = $prefs->client($client)->get('volumeup_remote')->[$i];
		$list_form{'volumeup_command'} = $prefs->client($client)->get('volumeup_command')->[$i];
		$list_form{'volumeup_delay'} = $prefs->client($client)->get('volumeup_delay')->[$i];
		$params->{'volumeup_list'} .= ${Slim::Web::HTTP::filltemplatefile('plugins/IRBlaster/volumeup_list.html',\%list_form)};
	}

	# ***********************
	# ----- Volume down -----

	# Make sure there is at least one entry in preferences file
	if( $prefs->client($client)->get('volumedown_count') eq "") {
		$prefs->client($client)->set('volumedown_count', '1');

		$tempPref1 = $prefs->client($client)->get('volumedown_remote');
		$tempPref1->[0] = '-1';
		$prefs->client($client)->set('volumedown_remote', $tempPref1);
		$tempPref2 = $prefs->client($client)->get('volumedown_command');
		$tempPref2->[0] = '';
		$prefs->client($client)->set('volumedown_command', $tempPref2);
		$tempPref3 = $prefs->client($client)->get('volumedown_delay');
		$tempPref3->[0] = '0.25';
		$prefs->client($client)->set('volumedown_delay', $tempPref3);
	}

	# Get data from webinterface and set data in preferences file
	$tempPref1 = $prefs->client($client)->get('volumedown_remote');
	$tempPref2 = $prefs->client($client)->get('volumedown_command');
	$tempPref3 = $prefs->client($client)->get('volumedown_delay');
	for( my $i = 0; $i < $prefs->client($client)->get('volumedown_count'); $i++) {
		if( $params->{'selRemVolumeDown_' . $i} ne "") {
			$tempPref1->[$i] = $params->{'selRemVolumeDown_' . $i};
			$tempPref2->[$i] = $params->{'selCmdVolumeDown_' . $i};
			$tempPref3->[$i] = $params->{'selDelayVolumeDown_' . $i};
		}
	}
	$prefs->client($client)->set('volumedown_remote', $tempPref1);
	$prefs->client($client)->set('volumedown_command', $tempPref2);
	$prefs->client($client)->set('volumedown_delay', $tempPref3);

	# Add row clicked - only add if maximum is not reached
	my $button = -1;
	for( my $i = 0; $i < $gMaxItemsPerAction; $i++) {
		if( $params->{'mode'} eq "addVolumeDown_" . $i) {
			$button = $i;
			last;
		}
	}
	if( $button != -1) {
		my $count = $prefs->client($client)->get('volumedown_count');
		if( $count < $gMaxItemsPerAction) {
			$tempPref1 = $prefs->client($client)->get('volumedown_remote');
			$tempPref2 = $prefs->client($client)->get('volumedown_command');
			$tempPref3 = $prefs->client($client)->get('volumedown_delay');
			for( my $i = $button; $i < $prefs->client($client)->get('volumedown_count'); $i++) {
				my $from = $count - $i + $button - 1;
				my $to = $from + 1;
				$tempPref1->[$to] = $prefs->client($client)->get('volumedown_remote')->[$from];
				$tempPref2->[$to] = $prefs->client($client)->get('volumedown_command')->[$from];
				$tempPref3->[$to] = $prefs->client($client)->get('volumedown_delay')->[$from];
			}
			$tempPref1->[$button] = '-1';
			$tempPref2->[$button] = '';
			$tempPref3->[$button] = '0.25';

			$prefs->client($client)->set('volumedown_remote',$tempPref1);
			$prefs->client($client)->set('volumedown_command',$tempPref2);
			$prefs->client($client)->set('volumedown_delay',$tempPref3);
			
			$prefs->client($client)->set('volumedown_count', $count + 1);
		}
	}

	# Remove row clicked - only remove if minimum is not reached
	$button = -1;
	for( my $i = 0; $i < $prefs->client($client)->get('volumedown_count'); $i++) {
		if( $params->{'mode'} eq "delVolumeDown_" . $i) {
			$button = $i;
			last;
		}
	}
	if( $button != -1) {
		my $count = $prefs->client($client)->get('volumedown_count');
		if( $count > 1) {
			$tempPref1 = $prefs->client($client)->get('volumedown_remote');
			$tempPref2 = $prefs->client($client)->get('volumedown_command');
			$tempPref3 = $prefs->client($client)->get('volumedown_delay');

			for( my $i = $button; $i < $prefs->client($client)->get('volumedown_count') - 1; $i++) {
				my $from = $i + 1;
				my $to = $i;
				$tempPref1->[$to] = $prefs->client($client)->get('volumedown_remote')->[$from];
				$tempPref2->[$to] = $prefs->client($client)->get('volumedown_command')->[$from];
				$tempPref3->[$to] = $prefs->client($client)->get('volumedown_delay')->[$from];
			}
			$prefs->client($client)->set('volumedown_remote',$tempPref1);
			$prefs->client($client)->set('volumedown_command',$tempPref2);
			$prefs->client($client)->set('volumedown_delay',$tempPref3);

			$prefs->client($client)->set('volumedown_count', $count - 1);
		}
	}
	
	# Test buttons clicked
	for( my $i = 0; $i < $prefs->client($client)->get('volumedown_count'); $i++) {
		if( $params->{'mode'} eq "testVolumeDown_" . $i) {
#			Plugins::IRBlaster::Plugin::IRBlastSend( $client,
			$classPlugin->IRBlastSend( $client,
				$prefs->client($client)->get('volumedown_remote')->[$i],
				$prefs->client($client)->get('volumedown_command')->[$i]);
		}
	}	
	
	# Get data from pref file and set in webinterface
	for( my $i = 0; $i < $prefs->client($client)->get('volumedown_count'); $i++) {
		my %list_form = %$params;
		$list_form{'max'} = $gMaxItemsPerAction;
		$list_form{'count'} = $prefs->client($client)->get('volumedown_count');
		$list_form{'id'} = $i;
		$list_form{'volumedown_remote'} = $prefs->client($client)->get('volumedown_remote')->[$i];
		$list_form{'volumedown_command'} = $prefs->client($client)->get('volumedown_command')->[$i];
		$list_form{'volumedown_delay'} = $prefs->client($client)->get('volumedown_delay')->[$i];
		$params->{'volumedown_list'} .= ${Slim::Web::HTTP::filltemplatefile('plugins/IRBlaster/volumedown_list.html',\%list_form)};
	}



	# ***********************************
	# ----- IR Blaster fixed volume -----

	if( $prefs->client($client)->get('fixedvolume') eq "") {
		$prefs->client($client)->set('fixedvolume', '60');
	}

	# User changed ir blaster fixed volume
	if( $params->{'mode'} eq "fixedvolume") {
		$prefs->client($client)->set( 'fixedvolume', $params->{'selFixedVolume'});
	}
	$params->{'selFixedVolume'} = $prefs->client($client)->get( 'fixedvolume');

	# Check if there is at least one volume command assigned
	#  and only if so, enable the firxed volume selector
	if( $classPlugin->checkVolumeCommandAssigned( $client) == 1) {
		$params->{'selFixedVolumeDisabled'} = 0;
	} else {
		$params->{'selFixedVolumeDisabled'} = 1;
	}

	# ******************************
	# ----- IR Repeater status -----

	# User changed ir repeater status
	if( $params->{'mode'} eq "repeater") {
		if( $params->{'irrepeater'} eq 'on') {
			$prefs->client($client)->set( 'repeater', 'on');
#			Plugins::IRBlaster::Plugin::switchIRRepeaterStatus( $client, "on");
			$classPlugin->switchIRRepeaterStatus( $client, "on");
		} else {
			$prefs->client($client)->set( 'repeater', 'off');
#			Plugins::IRBlaster::Plugin::switchIRRepeaterStatus( $client, "off");
			$classPlugin->switchIRRepeaterStatus( $client, "off");
		}
	}
	$params->{'irrepeater'} = $prefs->client($client)->get( 'repeater');

	return $class->SUPER::handler($client, $params);
}

1;

__END__

