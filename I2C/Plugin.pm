#	I2C.pm
#
#	Author: Felix Mueller <felix(dot)mueller(at)gwendesign(dot)com>
#
#   Small modifications for a mechanical flip-flop, updated to SqueezeCenter
#   and renamed from ExtendedIO to I2C Lars Immisch <lars@ibp.de> 
#
#	Copyright (c) 2003-2005 GWENDESIGN
#	All rights reserved.
#
#	Based on: Kevin Walsh's simple phone book
#
#	----------------------------------------------------------------------
#	8 bit output / input through i2c
#	----------------------------------------------------------------------
#	Function:
#
#	- Each of the 8 I/Os has 7 modes, selectable in the I2C setup menu
#	  -> (in)  input:         (ATTENTION: functionality is missing.)
#	  -> (out) output:        switchable by the number buttons 1..8 on the remote
#	                           from the I2C menu or
#	                           when the client is turned off (needs Power.pm change)
#	  -> (pow) linked output: same as output, but linked with the power of the
#	                           client
#	  -> (pls) timed output:  same as output, but turns off after a certain time
#	  -> (pon) pulse output: when client is turned on
#	  -> (pof) pulse output: when client is turned off
#     -> (pop) pulse output; when clent is turned on or off
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
#	Pin 1,2,3		(*) Pin 2	Pin 1				A0, A1, A2 (part of slave address)
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
#	History:
#
#   2006/11/29 v1.1 - Additions for mechanical flip-flop
#	2005/02/28 v1.0 - Slimserver v6 ready
#	2004/07/19 v0.9	- Get power on/off state through callback function
#			- Pulse output when client powers on or off
#			- Get buttons 1..8 when turned off through callback function
#	2003/11/21 v0.8 - Adaption to Squeezebox (write only, since the Firmware does not support read yet)
#	2003/11/19 v0.7 - Adaption to SlimServer v5.0
#	2003/07/27 v0.6 - Timed output can be turned off by pressing the button again
#	2003/07/20 v0.5 - Timed output option (output turns off after certain time
#	2003/07/06 v0.4 - Some tests
#	2003/05/22 v0.3 - Persistency for state and direction per client
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

# Our prefs
my $prefs = preferences('plugin.i2c');

# ----------------------------------------------------------------------------
# Global variables
# ----------------------------------------------------------------------------
my $autoTurnOffTime	= 3.0;	# in seconds
my $ipoDelayTime	= 0.1;	# in seconds

my @arrPages = ();	# 0 = Setup, 1 = State
my %hshDisplayCurrent;	# Current display for a client

#          Channel  1 . . . . . . 8
my @arrDirection = (0,0,0,0,1,1,1,1);  # See %setupdesc for values 
my @arrOutput =    (0,0,0,0,0,0,0,0);  # 0 = off, 1 = on
my @arrInput =     (1,1,1,1,1,1,1,1);  # 0 = low, 1 = high

my @arrPendingTimer = ();

my @arrLinesSetup = ( "Setup   1   2   3   4   5   6   7   8", "");
$arrPages[0] = \@arrLinesSetup;

my @arrLinesState = ( "State   1   2   3   4   5   6   7   8", "");
$arrPages[1] = \@arrLinesState;

# 0 = Output: toggle
# 1 = Input
# 2 = Output: linked to power state
# 3 = Output: timed 
#     (turns off after a certain time)
# 4 = Output: pulse when power on
# 5 = Output: pulse when power off
# 6 = Output: negated pulse when power 
#     changes
my @setupdesc = (["out", string("PLUGIN_I2C_OUT")],
				 ["in ", string("PLUGIN_I2C_IN")],
				 ["pow", string("PLUGIN_I2C_POWER")],
				 ["pls", string("PLUGIN_I2C_PULSE")],
				 ["pon", string("PLUGIN_I2C_POWERON")],
				 ["pof", string("PLUGIN_I2C_POWEROFF")],
				 ["pop", string("PLUGIN_I2C_POWERPULSE")]);
				 
sub initPlugin {
	my $class = shift;

	$class->SUPER::initPlugin();

	Plugins::I2C::PlayerSettings->new;

	# Install callback to get client power state changes
	# Slim::Control::Command::setExecuteCallback( \&commandCallback);
	Slim::Control::Request::subscribe(\&commandCallback, 
									  [['power', 'button']]);
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
		$hshDisplayCurrent{$client} = 0;    # setup page
		$client->update();
	},
	'down' => sub {
		my $client = shift;
		$hshDisplayCurrent{$client} = 1;    # state page
		$client->update();
	},
	'numberScroll' => sub  {
		no strict 'refs';
		my $client = shift;
		my $button = shift;
		my $digit = shift;

		if( $hshDisplayCurrent{$client} == 1) {
			# State page
			toggleIO( $client, $digit);
		} else {
			# Setup page
			if( ( $digit >= 1) && ( $digit <= 8)) {
				my $iIndex = $digit - 1;

				readIODirection( $client);

				# Rotate thru the different modes
				if( $arrDirection[$iIndex] == 1) {
					$arrDirection[$iIndex] = 0;		# Output: toggle
				} elsif( $arrDirection[$iIndex] == 0) {
					$arrDirection[$iIndex] = 2;		# Output: linked to power state
				} elsif( $arrDirection[$iIndex] == 2) {
					$arrDirection[$iIndex] = 3;		# Output: timed
				} elsif( $arrDirection[$iIndex] == 3) {
					$arrDirection[$iIndex] = 4;		# Output: pulse when power on
				} elsif( $arrDirection[$iIndex] == 4) {
					$arrDirection[$iIndex] = 5;		# Output: pulse when power off
				} elsif( $arrDirection[$iIndex] == 5) {
					$arrDirection[$iIndex] = 6;		# Output: pulse when power changes
				} elsif( $arrDirection[$iIndex] == 6) {
					$arrDirection[$iIndex] = 1;		# Input
				}
				writeIODirection( $client);
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
	my $iIndex = 0;
	my $szState = "        ";
	my $szSetup = "        ";

	readIOOutput( $client);
	readIODirection( $client);

	for( $iIndex = 0; $iIndex <= 7; $iIndex++) {
		if( $arrDirection[$iIndex] == 1) {
			if( $arrInput[$iIndex] == 1) {
				$szState .= "H   ";
			} else {
				$szState .= "L   ";
			}
			$szSetup .= $setupdesc[$arrDirection[$iIndex]][0] . " ";
		} else {
			if( $arrOutput[$iIndex] == 0) {
				$szState .= "Off ";
			} else {
				$szState .= "On  ";
			}
			$szSetup .= $setupdesc[$arrDirection[$iIndex]][0] . " ";
		}
	}
	$arrLinesState[1] = $szState;
	$arrLinesSetup[1] = $szSetup;

	return( { 'line' => $arrPages[$hshDisplayCurrent{$client} || 0]} );
}

# ----------------------------------------------------------------------------
sub setMode {
	my $class = shift;
	my $client = shift;

	readIOOutput($client);        # make sure the enties are generated
	readIODirection($client);     # make sure the enties are generated 

	$hshDisplayCurrent{$client} = 1;

	$client->lines( \&lines);
	$client->update();
}

# ----------------------------------------------------------------------------
# State persistency
# ----------------------------------------------------------------------------
sub writeIOOutput {
	my $client = shift;
	$prefs->client($client)->set(
					"ioOutput",
					$arrOutput[0] . " " .
					$arrOutput[1] . " " .
					$arrOutput[2] . " " .
					$arrOutput[3] . " " .
					$arrOutput[4] . " " .
					$arrOutput[5] . " " .
					$arrOutput[6] . " " .
					$arrOutput[7]);
}

# ----------------------------------------------------------------------------
# State persistency
# ----------------------------------------------------------------------------
sub readIOOutput {
	my $client = shift;
	my $szOutput;    

	$szOutput = $prefs->client($client)->get("ioOutput");
	if( !defined( $szOutput)) {
		### to do ### empty arrOutput
		writeIOOutput( $client);
		$szOutput = $prefs->client($client)->get("ioOutput");
	}
	@arrOutput = split( " ", $szOutput, 8);
}

# ----------------------------------------------------------------------------
# Direction (mode) persistency
# ----------------------------------------------------------------------------
sub writeIODirection {
	my $client = shift;
	$prefs->client($client)->set(
					"ioDirection",
					$arrDirection[0] . " " .
					$arrDirection[1] . " " .
					$arrDirection[2] . " " .
					$arrDirection[3] . " " .
					$arrDirection[4] . " " .
					$arrDirection[5] . " " .
					$arrDirection[6] . " " .
					$arrDirection[7]);
}

# ----------------------------------------------------------------------------
# Direction persistency
# ----------------------------------------------------------------------------
sub readIODirection {
	my $client = shift;
	my $szDirection;

	$szDirection =  $prefs->client($client)->get("ioDirection");
	if( !defined( $szDirection)) {
		### to do ### empty arrDirection
		writeIODirection( $client);
		$szDirection =  $prefs->client($client)->get("ioDirection");
	}
	@arrDirection = split( " ", $szDirection, 8);
}

# ----------------------------------------------------------------------------
# Build an intern list of timer references
# ----------------------------------------------------------------------------
sub addPendingTimer {
	my $timer = shift;
	my $iNum = scalar( @arrPendingTimer);
	splice( @arrPendingTimer, $iNum, 0, $timer);  # Add timer to end of list
	$iNum = scalar( @arrPendingTimer);

	$log->debug( "addPendingTimer() $iNum    $timer\n");
}

# ----------------------------------------------------------------------------
sub removePendingTimer {
	my $client = shift;
	my $iButton = shift;
	my $i = 0;
	my $timer;
	while( $timer = $arrPendingTimer[$i]) {
		$log->debug( "$timer->{'client'}\n");
		$log->debug( "$timer->{'when'}\n");
		$log->debug( "$timer->{'subptr'}\n");
		$log->debug( "$timer->{'args'}[0]\n");

		# Find timer that belongs to specific client and I/O channel
		if( ( $timer->{'client'} == $client) && ( $timer->{'args'}[0]) == $iButton) {
			splice( @arrPendingTimer, $i, 1);  # Remove timer from list
			last;
		}
		$i++;
	}
	my $iNum = scalar( @arrPendingTimer);

	$log->debug( "removePendingTimer() $iNum\n");

	return $timer;
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

# ----------------------------------------------------------------------------
# Callback to get client power state changes
# ----------------------------------------------------------------------------
sub commandCallback {
	my $request = shift;
	my $client = $request->client();

	# Get power on and off commands
	if( $request->getRequest(0) eq 'power') {
		my $iPower = $client->power();

		$log->debug("I2C::commandCallback() Power: $iPower\n");

# Direct call doesn't work
#		handlePowerOnOff( $client, $iPower);
		Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + 1.0, 
									   \&handlePowerOnOff_1, ( $iPower));

	# Get buttons 1..8 if player is turned off
	} elsif( $request->getRequest(0) eq 'button') {
		my $iPower = $client->power();
		my $iButton = $request->getRequest(1) || '';

		if( $iPower == 0) {
			if( $iButton =~ m/^numberScroll_/) {
				$iButton =~ s/numberScroll_//;

				$log->debug("*** p: $iPower   b: $iButton\n");

				toggleIO( $client, $iButton);
			}
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
	my $bOn = shift;

	$log->debug( "I2C::handlePowerSwitch() on: $bOn\n");

	readIODirection( $client);  
	for( my $iIndex = 0; $iIndex <= 7; $iIndex++) {
		if( $arrDirection[$iIndex] == 2) {
			if( $bOn) {
				switchIO( $client, $iIndex + 1, 1);  # Channel 1, on
			} else {
				switchIO( $client, $iIndex + 1, 0);  # Channel 1, off
			}
		} elsif( ( $arrDirection[$iIndex] == 4) && ( $bOn == 1)) {
			timedIO( $client, $iIndex + 1);
		} elsif( ( $arrDirection[$iIndex] == 5) && ( $bOn == 0)) {
			timedIO( $client, $iIndex + 1);
		} elsif( $arrDirection[$iIndex] == 6) {
			switchIO( $client, $iIndex + 1, 1);  # on
			my $timer = Slim::Utils::Timers::setTimer( $client, 
													   Time::HiRes::time()
													   + $ipoDelayTime, 
													   \&timedIO_IPO, 
													   $iIndex + 1);
			addPendingTimer( $timer);
		}
	}
}

# ----------------------------------------------------------------------------
sub toggleIO {
	my $client = shift;
	my $iButton = shift;

	$log->debug( "I2C::toggleIO() button: $iButton\n");

	if( ( $iButton < 1) || ( $iButton > 8)) {
		return;
	}

	my $iIndex = $iButton - 1;

	readIODirection( $client);  
	if( $arrDirection[$iIndex] == 1) {		# Input
		return;
	} elsif( $arrDirection[$iIndex] == 3) {		# Output: timed
		timedIO( $client, $iButton);
	} elsif( $arrDirection[$iIndex] == 4) {		# Output: pulse on
		timedIO( $client, $iButton);
	} elsif( $arrDirection[$iIndex] == 5) {		# Output: pulse off
		timedIO( $client, $iButton);
	} elsif( $arrDirection[$iIndex] == 6) {		# IPO
		switchIO( $client, $iButton, 1);        # on
		my $timer = Slim::Utils::Timers::setTimer( $client, Time::HiRes::time()
												   + $ipoDelayTime, 
												   \&timedIO_IPO, $iButton);
		addPendingTimer( $timer);
	} elsif( $arrDirection[$iIndex] == 0) {		# Output: toggle
		readIOOutput( $client);
		if( $arrOutput[$iIndex] == 0) {
			switchIO( $client, $iButton, 1);
		} else {
			switchIO( $client, $iButton, 0);
		}
	}
}

# ----------------------------------------------------------------------------
sub timedIO {
	my $client = shift;
	my $iButton = shift;
	my $iIndex = $iButton - 1;

	$log->debug( "I2C::timedIO() button: $iButton state: $arrOutput[$iIndex]\n");

	readIOOutput( $client);
	if( $arrOutput[$iIndex] == 0) {
		switchIO( $client, $iButton, 1);
		my $timer = Slim::Utils::Timers::setTimer( $client, Time::HiRes::time()
												   + $autoTurnOffTime, 
												   \&timedIO_Part2, 
												   ( $iButton));
		# Add timer to our intern list of pending timers for later reference
		addPendingTimer( $timer);  
	} else {
		# Remove timer from our internal list
		my $timer = removePendingTimer( $client, $iButton);  
		if( defined( $timer)) {
			# Remove the timer from global list
			Slim::Utils::Timers::killSpecific( $timer);  
		  }
		switchIO( $client, $iButton, 0);
	}
}

# ----------------------------------------------------------------------------
sub timedIO_Part2 {
	my $client = shift;
	my $iButton = shift;

	$log->debug( "I2C::timedIO_Part2() button: $iButton\n");

	# Remove timer from our internal list
	removePendingTimer( $client, $iButton);
	switchIO( $client, $iButton, 0);
}

# ----------------------------------------------------------------------------
sub timedIO_IPO {
	my $client = shift;
	my $iButton = shift;

	$log->debug( "I2C::timedIO_IPO() button: $iButton\n");

	removePendingTimer( $client, $iButton);  # Remove timer from our intern list
	switchIO( $client, $iButton, 0);
}

# ----------------------------------------------------------------------------
sub switchIO {
	my $client = shift;
	my $iChannel = shift;  # 1..8
	my $bState = shift;

	$log->debug( "I2C::switchIO() channel: $iChannel state: $bState\n");

	readIOOutput( $client);
	readIODirection( $client);

	$arrOutput[$iChannel - 1] = $bState;

	my $byValue = 0xff;

	if( $arrOutput[7] == 1) { $byValue = $byValue & 0x7f;}
	if( $arrOutput[6] == 1) { $byValue = $byValue & 0xbf;}
	if( $arrOutput[5] == 1) { $byValue = $byValue & 0xdf;}
	if( $arrOutput[4] == 1) { $byValue = $byValue & 0xef;}
	if( $arrOutput[3] == 1) { $byValue = $byValue & 0xf7;}
	if( $arrOutput[2] == 1) { $byValue = $byValue & 0xfb;}
	if( $arrOutput[1] == 1) { $byValue = $byValue & 0xfd;}
	if( $arrOutput[0] == 1) { $byValue = $byValue & 0xfe;}

	if( $arrDirection[7] == 1) { $byValue = $byValue | 0x80;}
	if( $arrDirection[6] == 1) { $byValue = $byValue | 0x40;}
	if( $arrDirection[5] == 1) { $byValue = $byValue | 0x20;}
	if( $arrDirection[4] == 1) { $byValue = $byValue | 0x10;}
	if( $arrDirection[3] == 1) { $byValue = $byValue | 0x08;}
	if( $arrDirection[2] == 1) { $byValue = $byValue | 0x04;}
	if( $arrDirection[1] == 1) { $byValue = $byValue | 0x02;}
	if( $arrDirection[0] == 1) { $byValue = $byValue | 0x01;}

	my $szValue = sprintf( "%02x", $byValue);

	$log->debug( $arrOutput[7]);
	$log->debug( $arrOutput[6]);
	$log->debug( $arrOutput[5]);
	$log->debug( $arrOutput[4]);
	$log->debug( $arrOutput[3]);
	$log->debug( $arrOutput[2]);
	$log->debug( $arrOutput[1]);
	$log->debug( $arrOutput[0]);
	$log->debug( " $szValue\n");

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

	writeIOOutput( $client);


### More old stuff
#    if( $bState == 1)  # on
#    {
#        # MAX 7310 address: 0x11
##       my $i2c = "s 22 03 00 ps 22 01 fb p";
#
#        # PCF 8574N address: 0x20
#        my $i2c = "s 40 fe p";
#
#        # pack hex values and add write, ack commands
#        $i2c =~ s/ ?([\dA-Fa-f][\dA-Fa-f]) ?/'w'.pack ("C", hex ($1))/eg;
#        $i2c = '2                 ' . $i2c;
#        Slim::Hardware::i2c::send( $client, $i2c);
##        Slim::Networking::Protocol::sendClient( $client, $i2c);
#    }
#    else  # off
#    {
#        # MAX 7310 address: 0x11
##       my $i2c = "s 22 03 00 ps 22 01 ff p";
#
#        # PCF 8574N address: 0x20
#        my $i2c = "s 40 ff p";
#
#        # pack hex values and add write, ack commands
#        $i2c =~ s/ ?([\dA-Fa-f][\dA-Fa-f]) ?/'w'.pack ("C", hex ($1))/eg;
#        $i2c = '2                 ' . $i2c;
#        Slim::Hardware::i2c::send( $client, $i2c);
##        Slim::Networking::Protocol::sendClient( $client, $i2c);
#    }
### End more old stuff

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


# ----------------------------------------------------------------------------
# ----------------------------------------------------------------------------
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
## Preparation for input polling
#my $interval = 1; # check every x seconds
#
#setTimer();
#
# ----------------------------------------------------------------------------
#sub setTimer
#{
#  Slim::Utils::Timers::setTimer( 0, Time::HiRes::time() + $interval, \&checkIO);
#}
#
# ----------------------------------------------------------------------------
#sub checkIO
#{
#	foreach my $client ( Slim::Player::Client::clients())
#	{
#	}
#	setTimer();
#}

# ----------------------------------------------------------------------------
#	$powerSwitchMode = Slim::Utils::Prefs::clientGet( $client, "powerSwitchMode");
#	if( !defined( $powerSwitchMode))
#	{
#		$powerSwitchMode = 0;
#	}
#	Slim::Utils::Prefs::clientSet( $client, "powerSwitchMode", 0);
#	my $power1Switch = Slim::Utils::Prefs::clientGet( $client, "power1Switch");
#	if( !defined( $power1Switch))
#	{
#		$power1Switch = 0;
#	}
#	Slim::Utils::Prefs::clientSet( $client, "power1Switch", 1);

