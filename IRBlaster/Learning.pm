# IRBlaster::Learning.pm
package Plugins::IRBlaster::Learning;

# SqueezeCenter Copyright (c) 2001-2008 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License, 
# version 2.

use strict;
use base qw(Slim::Web::Settings);

use File::Spec::Functions qw(:ALL);

use Slim::Utils::Strings qw(string);
use Slim::Utils::Log;
use Slim::Utils::Prefs;

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

# ----------------------------------------------------------------------------
# Define own constructor
# - to save references to Plugin.pm
# ----------------------------------------------------------------------------
sub new {
	my $class = shift;

	$classPlugin = shift;

	$log->debug( "*** IRBlaster::Learning::new() " . $classPlugin . "\n");

	$class->SUPER::new();

	return $class;
}

# ----------------------------------------------------------------------------
# Name in the settings dropdown
# ----------------------------------------------------------------------------
sub name {
	return 'PLUGIN_IRBLASTER_IR_LEARNING_WIZARD';
}

# ----------------------------------------------------------------------------
# Webpage served for learning wizard
# ----------------------------------------------------------------------------
sub page {
	return 'plugins/IRBlaster/setup_learn.html';
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
# IR Learning: global vars
# ----------------------------------------------------------------------------
my $learnFileNameWithPath = "";
my $learnFileDeviceName = "";
my $learnButtonName = "";
my $learnCode = "";
# The first gap is always too long since it is the time since the last
#  IR command was received by SB2/SB3
# So we store the first gap and use it at the very end
my $learnLastGap = 0;

# ----------------------------------------------------------------------------
sub getLearnCode {
	my $class = shift;

	return $learnCode;
}

# ----------------------------------------------------------------------------
# IR Learning: web-interface (wizard)
# ----------------------------------------------------------------------------
sub handler {
	my ($class, $client, $params) = @_;

	# $client is the client that is selected on the right side of the web interface!!!
	# We need the client identified by 'playerid'

	# Find player that fits the mac address supplied in $params->{'playerid'}
	my @playerItems = Slim::Player::Client::clients();
	foreach my $play (@playerItems) {
		if( $params->{'playerid'} eq $play->macaddress()) {
			$client = $play;
			last;
		}
	}
	if( !defined( $client)) {
		return $class->SUPER::handler($client, $params);
	}
	
	$log->debug( "*** IR-Blaster: found player: " . $client . "\n");

	# Fill in current step
	if( !$params->{'step'}) {
		$params->{'step'} = 1;
		
		$learnFileDeviceName = "";
		$learnButtonName = "";
	}

	if( $params->{'mode'} eq "next") {
		if( $params->{'step'} == 1) {
	
		} elsif( $params->{'step'} == 2) {

			$learnFileDeviceName = "";
			if( $params->{'filedevicename'}) {
				$learnFileDeviceName = $params->{'filedevicename'};
			}
			if( $learnFileDeviceName eq "") {

				$log->warn( "*** IR-Learning: Warn: File/Device name cannot be empty\n");

				$params->{'step'} = 1;  # Is incremented later on
				$params->{'warn'} = $client->string( 'PLUGIN_IRBLASTER_FILE_DEVICE_NAME_CANNOT_BE_EMPTY');
			} else {
				# Remove .conf if user has entered it
				$learnFileDeviceName =~ s/\.conf$//;
				
				# Check that filename is valid for filesystem
				if( $learnFileDeviceName !~ /^[A-Za-z0-9_]+$/) {
				
					$log->warn( "*** IR-Learning: Warn: File/device can only consist of letters and numbers\n");

					$learnFileDeviceName = "";
					$params->{'step'} = 1;  # Is incremented later on
					$params->{'warn'} = $client->string( 'PLUGIN_IRBLASTER_FILE_DEVICE_NAME_CAN_ONLY_CONSIST_OF_LETTERS_AND_NUMBERS');
				} else {
					# Add full path and extension
					$learnFileNameWithPath = catfile( $prefs->get( 'conffilepath'),
						 $learnFileDeviceName . ".conf");
					# Check if file exists already
					if( -e $learnFileNameWithPath) {

						$log->warn( "*** IR-Learning: Warn: A file/device with that name exists\n");

						$learnFileDeviceName = "";
						$learnFileNameWithPath = "";
						$params->{'step'} = 1;  # Is incremented later on
						$params->{'warn'} = $client->string( 'PLUGIN_IRBLASTER_A_FILE_DEVICE_WITH_THAT_NAME_EXISTS');
					} else {

						if( open( FH, "> $learnFileNameWithPath")) {

							$log->debug( "*** IR-Learning: Create file\n");

							$log->debug( "*** IR-Learning: Append device header\n");

							print FH "begin remote\n";
							print FH "  name " . $learnFileDeviceName . "\n";
							print FH "  flags  RAW_CODES\n\n";
							print FH "  begin raw_codes\n";					
							close( FH);
						} else {
						
							$log->warn( "*** IR-Learning: Warn: Cannot open file/device for writing\n");

							$learnFileDeviceName = "";
							$learnFileNameWithPath = "";
							$params->{'step'} = 1;  # Is incremented later on
							$params->{'warn'} = $client->string( 'PLUGIN_IRBLASTER_CANNOT_OPEN_FILE_DEVICE_FOR_WRITING');
						}
					}
				}
			}

		} elsif( $params->{'step'} == 3) {
			if( $params->{'buttonname'}) {
				$learnButtonName = $params->{'buttonname'};
			}
			if( $learnButtonName eq "") {

				$log->warn( "*** IR-Learning: Warn: button name cannot be empty\n");

				$params->{'step'} = 2;  # Is incremented later on
				$params->{'warn'} = $client->string( 'PLUGIN_IRBLASTER_BUTTON_NAME_CANNOT_BE_EMPTY');
			} else {

				$log->debug( "*** IR-Learning: Append button 1\n");

				open( FH, ">> $learnFileNameWithPath");
				print FH "    name " . $learnButtonName . "\n";
				close( FH);
				
				$learnCode = "";

				$learnLastGap = 0;
				
				# Check if function is available
				if( UNIVERSAL::can( "Slim::Networking::Slimproto","setCallbackRAWI")) {
					Slim::Networking::Slimproto::setCallbackRAWI( \&RAWICallbackLearn);
				}

				# Ask SB2/SB3 or Transporter to send 5 ir codes (containing x samples)
				my $num_codes = pack( 'C', 5);
				$client->sendFrame( 'ilrn', \$num_codes);
				
				$client->showBriefly(
					{
						'line1' => $client->string( 'PLUGIN_IRBLASTER_IR_LEARNING_WIZARD'),
						'line2' => $client->string( 'PLUGIN_IRBLASTER_PRESS_BUTTON_ON_REMOTE')
					},
					{
						'duration' => "5"
					}
				);
			}

		} elsif( $params->{'step'} == 4) {

			$log->debug( "*** IR-Learning: Append button code\n");

			if( $learnLastGap > 0) {
				open( FH, ">> $learnFileNameWithPath");
				print FH "    " . $learnLastGap . "\n";
				close( FH);
			}
			
			# Check if function is available
			if( UNIVERSAL::can( "Slim::Networking::Slimproto","clearCallbackRAWI")) {
				Slim::Networking::Slimproto::clearCallbackRAWI( \&RAWICallbackLearn);
			}
			$learnButtonName = "";
		}

	} elsif( $params->{'mode'} eq 'done') {
	
		$log->debug( "*** IR-Learning: Append button code - append remote footer\n");

		open( FH, ">> $learnFileNameWithPath");
		print FH "  end raw_codes\n";
		print FH "end remote\n";
		close( FH);

	} elsif( $params->{'mode'} eq 'restart') {

		$log->debug( "*** IR-Learning: Restart wizard\n");

		$learnFileDeviceName = "";
		$learnButtonName = "";
	}

	# Advance to next step
	if( $params->{'mode'} eq "next") {
		if( $params->{'step'} == 4) {
			$params->{'step'} = 3;
		} else {
			$params->{'step'} += 1;
		}
	} elsif( $params->{'mode'} eq 'restart') {
		$params->{'step'} = 1;
	} elsif( $params->{'mode'} eq "done") {
		$params->{'step'} = 5;
	}

	$params->{'filedevicename'} = $learnFileDeviceName;
	$params->{'buttonname'} = $learnButtonName;
	
	return $class->SUPER::handler($client, $params);
}

# ----------------------------------------------------------------------------
# IR Learning: callback to write raw ir codes into file
# ----------------------------------------------------------------------------
sub RAWICallbackLearn {
	my $client = shift;
	my $data = shift;

	my $newline = 0;
	my $mask = "n";
	my $gap = 0;
	
	open( FH, ">> $learnFileNameWithPath");

	# Get first sample (gap)
	$gap = unpack( $mask, $data);
	# Firmware divides values by 25 to fit into 16 bits
	# 25 is about the modulation used in IR blasting (1000000 / 38400 = 26.042)
	$gap = $gap * 25;			

	# The first gap becomes the last
	if( $learnLastGap == 0) {
		# Limit gap to 20000
		if( $gap > 20000) {
			$gap = 20000;
		}
		$learnLastGap = $gap;
	} else {
		$learnCode .= $gap . "\n\n";
		print FH "    " . $gap . "\n";
	}
	# Shift mask by 2 bytes
	$mask = "xx" . $mask;
	for( my $i = 1; $i < (length($data)/2); $i++) {
		my $sample = 0;

		# Get next sample
		$sample = unpack( $mask, $data);
		# Firmware divides values by 25 to fit into 16 bits
		# 25 is about the modulation used in IR blasting (1000000 / 38400 = 26.042)
		$sample = $sample * 25;
		
		$log->debug( "*** IR-Learning: " . $sample . "\n");
	
		# Feedback for user in webinterface
		$learnCode .= $sample . " ";
		# Make nice groups of 6 values in .conf file
		$newline++;
		if( $newline gt 6) {
			$newline = 1;
			print FH "\n";
		}
		# Write samples into .conf file
		print FH "    " . $sample;
		# Shift mask by 2 bytes
		$mask = "xx" . $mask;
	}

	$log->debug( "*** IR-Learning: " . $gap . "\n");

	close( FH);
}

1;

__END__

