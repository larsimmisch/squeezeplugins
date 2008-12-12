#	I2C::Plugin.pm
#
#	Author: Felix Mueller <felix(dot)mueller(at)gwendesign(dot)com>
#
#   Ported to SqueezeCenter, extended and renamed from 
#   ExtendedIO to I2C by Lars Immisch <lars@ibp.de> 
#
#	Copyright (c) 2003-2005 GWENDESIGN
#	All rights reserved.
#
#	Based on: Kevin Walsh's simple phone book, plus ideas from 
#             Peter Watkins VolumeLock
#
#	----------------------------------------------------------------------
#	8 bit output through i2c
#	----------------------------------------------------------------------
#	Function:
#
#	- Each of the 8 I/Os has 6 modes, selectable in the I2C setup menu
#	  -> (out) output:    switchable by the number buttons 1..8 on the 
#                         remote from the I2C menu or
#	                      when the client is turned off 
#                         (needs Power.pm change)
#	  -> (pow) power:     same as output, but linked with the power of the
#	                      client
#	  -> (pls) short pulse (length is $pulseWidth seconds) 
#	  -> (pon) short pulse when client is turned on
#	  -> (pof) short pulse when client is turned off
#     -> (pop) short pulse when clent is turned on or off
#
#	If used with a skin (Fishbone) that has power on/off possibilities,
#	the amplifier can be turned on/off together with the client
#
#	----------------------------------------------------------------------
#	Technical:
#
#       The PCF 8574N (TI) is used. Slave address: 0x20
#
#	Connections:
#	PCF 8574		SLIMP3 U8	Squeezebox Geek Connector	Comment
#
#	Pin 14			U8 Pin 6	Pin 7				SCL (Clock)
#	Pin 15			U8 Pin 7	Pin 8				SDA (Data)
#
#	Pin 1,2,3		(*) Pin 2	Pin 1				A0, A1, A2 
#                                                   (part of slave address)
#	Pin 8			(*) Pin 2	Pin 1				GND
#
#	Pin 16			(*) Pin 1	Pin 2				V+ (5V)
#	Pin 4									I/0 0 (only one used so far)
#
#	Pin 5, 6, 7, 9, 10, 11, 12, 13						not used
#
#	(*) 6 pin connector (JTAG) next to PIC16F877
#
#	----------------------------------------------------------------------
#	History (obsolete, see subversion now):
#
#   2006/11/29 v1.1 - Additions for mechanical flip-flop
#	2005/02/28 v1.0 - Slimserver v6 ready
#	2004/07/19 v0.9	- Get power on/off state through callback function
#			- Pulse output when client powers on or off
#			- Get buttons 1..8 when turned off through callback function
#	2003/11/21 v0.8 - Adaption to Squeezebox (write only, since the Firmware 
#                     does not support read yet)
#	2003/11/19 v0.7 - Adaption to SlimServer v5.0
#	2003/07/27 v0.6 - Timed output can be turned off by pressing the button 
#                     again
#	2003/07/20 v0.5 - Timed output option (output turns off after certain time
#	2003/07/06 v0.4 - Some tests
#	2003/05/22 v0.3 - Persistency for state and command per client
#	2003/05/19 v0.2 - Use of channels (1..8) for output (array index 0..7)
#	2003/05/17 v0.1	- Initial version
#	----------------------------------------------------------------------
#	To do:
#
#	- Find a way to distinguish between different slave read answers
#	- Input functionality (on Squeezebox)
#	- Multi language
#	- Clean up code
#
#	This program is free software; you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation; either version 2 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program; if not, write to the Free Software
#	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
#	02111-1307 USA
#
package Plugins::I2C::Plugin;

use strict;
use Slim::Utils::Prefs;
use Slim::Utils::Log;
use Slim::Utils::Strings qw(string);
use base qw(Slim::Plugin::Base);
use vars qw($VERSION);
use Plugins::I2C::PlayerSettings;

$VERSION = substr(q$Revision: 1.1 $,10);

my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.i2c',
	'defaultLevel' => 'ERROR',
	'description'  => getDisplayName(),
});

my $prefs = preferences('plugin.i2c');
my $serverPrefs = preferences('server');

# ----------------------------------------------------------------------------
# Global variables
# ----------------------------------------------------------------------------
my $pulseWidth	= 0.1;	# in seconds
my $volumePulseWidth = 0.2;

my @Pages = ();	# 0 = Setup, 1 = State
my %Display;	# Current display for a client

my %Timer;

my @LinesSetup = ( "Setup   1   2   3   4   5   6   7   8", "");
$Pages[0] = \@LinesSetup;

my @LinesState = ( "State   1   2   3   4   5   6   7   8", "");
$Pages[1] = \@LinesState;

# whether we're enabled (the callback remains in the function
# stack after "disabling" the plugin, so we need to keep track of this)
my $pluginEnabled = 0;

my $originalVolumeFunction;

# The Commands array; each item has four fields:
#
# - a short description (like 'out')
#
# - a long description for display on the Web UI
#
# - a function with arguments $client, $index and $state that is called to 
#     change the state (through the remote)
#   
# - a function with arguments $client, $index, $state and $power that is
#     called when the player is switched on or off
#
# Volume changes are handled outside of this table

our @Commands = (["out", string("PLUGIN_I2C_OUT"), \&toggleIO, undef],
				 ["pls", string("PLUGIN_I2C_PULSE"), \&pulseIO, undef],
				 ["pow", string("PLUGIN_I2C_POWER"), \&toggleIO, \&toggleIO],
				 ["pon", string("PLUGIN_I2C_POWERON"), \&pulseIO, 
				  sub {
					 my ($client, $index, $state, $power) = @_;

					 if ($power) {
						 pulseIO($client, $index, $state);
					 }
				 }],
				 ["pof", string("PLUGIN_I2C_POWEROFF"), \&pulseIO, 
				  sub {
					 my ($client, $index, $state, $power) = @_;
					 
					 if (!$power) {
						 pulseIO($client, $index, $state);
					 }
				 }],
				 ["pop", string("PLUGIN_I2C_POWERPULSE"), \&pulseIO, 
				  sub {
					  my ($client, $index, $state, $power) = @_;
					  
					  pulseIO($client, $index, $state);
				  }],
				 ["v-", string("PLUGIN_I2C_VOLUMEDEC"), \&pulseIO, undef],
				 ["v+", string("PLUGIN_I2C_VOLUMEINC"), \&pulseIO, undef]);

				 
sub initPlugin {
	my $class = shift;

	$class->SUPER::initPlugin();

	Plugins::I2C::PlayerSettings->new;

	if (!$pluginEnabled) 
	{
		$originalVolumeFunction = $Slim::Buttons::Common::functions{'volume'};

		$log->debug("$originalVolumeFunction");
		
		Slim::Buttons::Common::setFunction('volume', \&volumeFunction);

		# Install callback to get client power state changes
		# Slim::Control::Command::setExecuteCallback( \&commandCallback);
		 Slim::Control::Request::subscribe(\&commandCallback, 
										  [['power', 'button', 'client']]);

	}

	$pluginEnabled = 1;
}

sub shutdownPlugin {
	$pluginEnabled = 0;
}

# ----------------------------------------------------------------------------
# Functions
# ----------------------------------------------------------------------------

my %functions = (
	'left' => sub {
		Slim::Buttons::Common::popModeRight(shift);
	},
	'up' => sub {
		my $client = shift;
		$Display{$client} = 0;    # setup page
		$client->update();
	},
	'down' => sub {
		my $client = shift;
		$Display{$client} = 1;    # state page
		$client->update();
	},
	'numberScroll' => sub  {
		no strict 'refs';
		my $client = shift;
		my $button = shift;
		my $digit = shift;
		my $index = $digit - 1;

		if( $Display{$client} == 1) {
			# State page
			if( ( $digit >= 1) && ( $digit <= 8)) {
				my @command = readIOCommand( $client);
				my @output = readIOState( $client);

				$Commands[$command[$index]][2]->($client, $index, 
												 $output[$index]);
			}
		} else {
			# Setup page
			if( ( $digit >= 1) && ( $digit <= 8)) {
				my $index = $digit - 1;

				my @command = readIOCommand($client);

				# Rotate through the different command modes
				$command[$index] = ($command[$index] + 1) % ($#Commands + 1);

				writeIOCommand( $client, @command);
			}
		}
	}
);

# ----------------------------------------------------------------------------
# lines()
# Create and return the two-line display.
# ----------------------------------------------------------------------------
sub lines {
	my $client = shift;
	my $szState = "        ";
	my $szSetup = "        ";

	my @output = readIOState( $client);
	my @command = readIOCommand( $client);

	for my $index (0 .. $#output) {
		if( $output[$index] == 0) {
			$szState .= "Off ";
		} else {
			$szState .= "On  ";
		}
		$szSetup .= $Commands[$command[$index]][0] . " ";
	}
	$LinesState[1] = $szState;
	$LinesSetup[1] = $szSetup;

	return( { 'line' => $Pages[$Display{$client} || 0]} );
}

# ----------------------------------------------------------------------------
sub setMode {
	my $class = shift;
	my $client = shift;

	readIOState($client);        # make sure the enties are generated
	readIOCommand($client);     # make sure the enties are generated 

	$Display{$client} = 1;

	$client->lines( \&lines);
	$client->update();
}

# ----------------------------------------------------------------------------
# State persistency
# ----------------------------------------------------------------------------
sub writeIOState {
	my ($client, @output) = @_;

	my $szOutput = join(" ", @output);

	$log->debug($client->id . " write: $szOutput");

	$prefs->client($client)->set("ioOutput", $szOutput);
}

# ----------------------------------------------------------------------------
# State persistency
# ----------------------------------------------------------------------------
sub readIOState {
	my $client = shift;

	my $szOutput = $prefs->client($client)->get("ioOutput");
	if( !defined( $szOutput)) {
		writeIOState( $client, (0, 0, 0, 0, 0, 0, 0, 0));
		$szOutput = $prefs->client($client)->get("ioOutput");
	}
	
	# $log->debug($client->id . " read: $szOutput");

	return split( " ", $szOutput, 8);
}

# ----------------------------------------------------------------------------
# Command (mode) persistency
# ----------------------------------------------------------------------------
sub writeIOCommand {
	my ($client, @command) = @_;

	my $szCommand = join(' ', @command);

	$log->debug($client->id . " write: $szCommand");

	$prefs->client($client)->set("ioDirection", $szCommand);
}

# ----------------------------------------------------------------------------
# Command persistency
# ----------------------------------------------------------------------------
sub readIOCommand {
	my $client = shift;

	my $szCommand =  $prefs->client($client)->get("ioDirection");
	if( !defined( $szCommand)) {
		### to do ### empty command
		writeIOCommand( $client, (0, 0, 0, 0, 0, 0, 0, 0));
		$szCommand =  $prefs->client($client)->get("ioDirection");
	}

	# $log->debug($client->id . " read: $szCommand");

	return split( " ", $szCommand, 8);
}

# ----------------------------------------------------------------------------
sub getFunctions {
	my $class = shift;

	\%functions;
}

# ----------------------------------------------------------------------------
sub getDisplayName {
	return 'PLUGIN_I2C_NAME';
}

sub volumeFunction {
	my $client = shift;
	my $button = shift;
	my $last = $client->lastirbutton();
	# cut off the potential .repeat
	my $abbr = (split(/\./, $last, 2))[0];
	my $handled = 0;
	my %tt = ("volup" => "v+", "voldown" => "v-");

	$log->debug("$last $abbr");

	my @command = readIOCommand($client);

	if ($tt{$abbr})
	{
		for my $index (0 .. $#command) 
		{
			my $cmd = $Commands[$command[$index]][0];

			if ($tt{$abbr} eq $cmd)
			{
				$handled = 1;
				pulseIO($client, $index, 0, $volumePulseWidth);
			}
		}
	}

	if (!$handled)
	{
		&$originalVolumeFunction($client);
	}
}

# ----------------------------------------------------------------------------
# Callback to get client power state changes
# ----------------------------------------------------------------------------
sub commandCallback {
	my $request = shift;
	my $client = $request->client();

	# Get power on and off commands
	if( $request->getRequest(0) eq 'power') {
		my $power = $client->power();

		$log->debug($client->id . " power: $power\n");

		# Direct call doesn't work
		# handlePowerOnOff( $client, $power);
		Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + 0.1, 
									   \&handlePowerOnOff_1, ( $power));

	# Get buttons 1..8 if player is turned off
	} elsif( $request->getRequest(0) eq 'button') {
		my $power = $client->power();
		my $button = $request->getRequest(1) || '';

		if( $power == 0) {
			if( $button =~ m/^numberScroll_/) {
				$button =~ s/numberScroll_//;

				my $index = $button - 1;
				my @command = readIOCommand($client);
				my @output = readIOState($client);

				$log->debug($client->id ." *** p: $power b: $button\n");

				$Commands[$command[$index]][2]->($client, $index, 
												 $output[$index]);
			}
		}
	} elsif( $request->getRequest(0) eq 'client') {
		my $cmd = $request->getRequest(1) || '';

		$log->debug("client $cmd " . $client->id . " " . $client->name . "\n");

		if ($cmd eq "reconnect") {
			# Make sure IO is in sync with our state
			switchIO($client);
		}
		elsif ($cmd eq "new") {
			# Make sure preferences exist
			readIOState($client);
			readIOCommand($client);
		}
	}
}

# ----------------------------------------------------------------------------
sub handlePowerOnOff_1 {
	my $client = shift;

	Slim::Utils::Timers::killTimers( $client, \&handlePowerOnOff_1); 
	handlePowerOnOff( $client, shift);
}

# ----------------------------------------------------------------------------
sub handlePowerOnOff {
	my $client = shift;
	my $power = shift;

	$log->debug($client->id . " power: $power\n");

	my @command = readIOCommand( $client);
	my @output = readIOState($client);

	for my $i (0 .. $#command) {
		if (defined $Commands[$command[$i]][3]) {
			$Commands[$command[$i]][3]->($client, $i, $output[$i], $power);
		}
	}
}

# ----------------------------------------------------------------------------
sub toggleIO {
	my ($client, $index, $state) = @_;

	$log->debug($client->id . " button: $index\n");

	if( ($index < 0) || ($index > 7)) {
		return;
	}

	if( $state == 0) {
		switchIO( $client, $index, 1);
	} else {
		switchIO( $client, $index, 0);
	}
}

# ----------------------------------------------------------------------------
sub pulseIO {
	my $client = shift;
	my $index = shift;
	my $state = shift;
	my $length = shift;

	$log->debug($client->id . " index: $index, state: $state, length: $length\n");

	if( ($index < 0) || ($index > 7)) {
		return;
	}

	if (!defined $length) {
		$length = $pulseWidth;
	}

	my $ti = $Timer{$client}{$index};

	if ($ti) {
		# Kill the pending timer
		Slim::Utils::Timers::killSpecific($ti);
	}

	switchIO($client, $index, 1);
	
	$Timer{$client}{$index} = Slim::Utils::Timers::setTimer(
        $client, Time::HiRes::time() + $length, \&pulseIO2, ($index));
}

# ----------------------------------------------------------------------------
sub pulseIO2 {
	my $client = shift;
	my $index = shift;

	$log->debug($client->id . " index: $index\n");

	# Remove timer from our internal hash
	delete $Timer{$client}{$index};
	switchIO( $client, $index, 0);
}

# ----------------------------------------------------------------------------
sub switchIO {
	my $client = shift;
	my $channel = shift;  # 0..7
	my $state = shift;

	$log->debug($client->id . "index: $channel state: $state\n");

	my @output = readIOState( $client);
	my @command = readIOCommand( $client);

	# switchIO can be called with just the client argument to bring the
	# hardware in sync with our perception of reality
	if ((defined $state) && (defined $channel)) {
		$output[$channel] = $state;
	}

	my $byValue = 0xff;

	if( $output[7] == 1) { $byValue = $byValue & 0x7f;}
	if( $output[6] == 1) { $byValue = $byValue & 0xbf;}
	if( $output[5] == 1) { $byValue = $byValue & 0xdf;}
	if( $output[4] == 1) { $byValue = $byValue & 0xef;}
	if( $output[3] == 1) { $byValue = $byValue & 0xf7;}
	if( $output[2] == 1) { $byValue = $byValue & 0xfb;}
	if( $output[1] == 1) { $byValue = $byValue & 0xfd;}
	if( $output[0] == 1) { $byValue = $byValue & 0xfe;}

	my $szValue = sprintf( "%02x", $byValue);

	$log->debug($client->id . " " . join(" ", @output) . " $szValue\n");

	my $i2c = undef;


### Old stuff
#	# MAX 7310 address: 0x11
#	$i2c = "s 22 03 00 ps 22 01 ff p";

#	# PCF 8574N address: 0x20 -> 0x40
#	$i2c = "s 40 ff p";
### Old stuff end


	# We decide on the format for the i2c command by the decoder
	# SLIMP3 -> mas3507d
	# Squeeze -> mas35x9

	if( $client->decoder eq 'mas3507d') {
		$i2c = "s 40 " . $szValue . " p";

		# pack hex values and add write, ack commands
		$i2c =~ s/ ?([\dA-Fa-f][\dA-Fa-f]) ?/'w'.pack ("C", hex ($1))/eg;
	} elsif( $client->decoder eq 'mas35x9') {
		$i2c = "s40p" . $szValue;

		$i2c =~ s/s([\dA-Fa-f][\dA-Fa-f]) ?/'s'.pack ("C", hex ($1))/eg;
		$i2c =~ s/p([\dA-Fa-f][\dA-Fa-f]) ?/'p'.pack ("C", hex ($1))/eg;
		$i2c =~ s/ ?([\dA-Fa-f][\dA-Fa-f]) ?/'w'.pack ("C", hex ($1))/eg;
	}

	$client->i2c( $i2c);

	writeIOState($client, @output);
}

# *************************************************************
# Experimental (not used)
# *************************************************************

# *************************************************************
sub readIO
{
	my $client = shift;

	$log->debug( "I2C::readIO()\n");

#	# MAX 7310 address: 0x11
#	my $i2c = "s 22 03 ff ps 22 02 00 ps 22 00 s 23 rn p";

	# PCF 8574N address: 0x20
	my $i2c = "s 40 s 41 rn p";

	# pack hex values and add write, ack commands
	$i2c =~ s/ ?([\dA-Fa-f][\dA-Fa-f]) ?/'w'.pack ("C", hex ($1))/eg;
	$i2c = '2                 ' . $i2c;

## SlimServer change
#	Slim::Hardware::i2c::send( $client, $i2c);
	$client->i2c( $i2c);

}

1;
