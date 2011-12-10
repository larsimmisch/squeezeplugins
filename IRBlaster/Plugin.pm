#	IRBlaster::Plugin.pm
#
#	Author: Felix Mueller <felix(dot)mueller(at)gwendesign(dot)com>
#
#	Copyright (c) 2003-2008 by GWENDESIGN
#	All rights reserved.
#
#   Extended by Lars Immisch <lars@ibp.de>
#	----------------------------------------------------------------------
#	IR-Blaster
#	----------------------------------------------------------------------
#	Function:	- Reading LIRC files (www.lirc.org)
#			- Sending an IR command if SB2/3 or Transporter is powered on / off
#			- Relaying volume up / down to a receiver / amplifier (via ir)
#			- Multiple IR commands can be sent for each action
#
#			- IR Repeater: Relaying any IR commands to other equipment
#
#			- IR Learning: Learn ir commands through SB2 / SB3
#
#			- CLI: <player> irblaster send <device> <button>	- send a command
#			- CLI: irblaster devices				- get list of devices
#			- CLI: irblaster buttons <device>			- get list of codes for a device
#
#			-CLI: subscribe getexternalvolumeinfo			- subscribe to notification
#			-CLI: getexternalvolumeinfo				- get info about external volume
#
#	----------------------------------------------------------------------
#	Technical:	- You need an IR emitter plugged into the head-
#			   phone/IR jack of your SB2/SB3 or Transporter
#
#	----------------------------------------------------------------------
#	History:
#
#	2010/03/08 v5.6.1 - Fix minimal SC version required (Thanks epoch1970)
#	2010/02/02 v5.6 - Add getexternalvolumeinfoCLI (Thanks Peter)
#			- Apply patch to fix bug 9611 (Thanks Chris)
#			- Add CLI to get all remotes and buttons
#			- Better way to find directory where we are installed
#	2008/11/25 v5.5	- PluginMaker structure
#	2008/07/20 v5.4 - Fix volume again
#			- French translations (Thanks to Seb)
#	2008/01/06 v5.3 - Do not show settings option if player does not support it
#	2007/12/21 v5.2 - Fix volume (Thanks James)
#	2007/08/01 v5.1 - Fix player settings page for SS 7.0
#	2007/06/02 v5.0 - Implement new preferences handling
#	2007/05/31 v4.9.3 - Block sending while still busy (raw code only)
#	2007/04/09 v4.9.2 - Fix a missing string
#	2007/04/09 v4.9.1 - Added DE language
#	2007/04/03 v4.9 - Remove player UI - not used
#	2007/03/31 v4.8 - Use new debug logging
#	2007/02/16 v4.7 - Reorder code to make sure reloading .conf files are reflected immediately
#	2007/01/02 v4.6 - Disable fixedVolume setting in web-interface if no volume commands are assigned
#			- Use same logic to set volume to fixed value or not as for web-interface
#			- Only go through custom mixer volume function if SB2/3 or Transporter
#			- Version is now set in install.xml
#	2006/12/30 v4.5 - Fix Player UI (i.e. setMode)
#	2006/12/26 v4.4 - Make plugin a class
#	2006/12/09 v4.3 - Clean up
#	2006/12/07 v4.2 - SlimServer 7.0 version (new plugin API)
#	2006/11/02 v4.1 - Add CLI interface to send ir commands
#	2006/10/25 v4.0 - Rename index.html to setup_index.html
#			- Rename learn.html to setup_learn.html
#	2006/09/28 v3.9 - Use new addDispatch function to get volume changes
#	2006/08/22 v3.8 - Fix webpages to use setup drop down menu
#	2006/08/09 v3.7 - IR Repeater: Fix a situation where repeating would stop working
#			   after some blasting commands
#	2006/08/01 v3.6 - IR Repeater: Possible fix for remotes with special repeat codes
#			   Tested with (regular repeat code): Slim, Sony Receiver, Sharp TV
#			   Tested with (special repeat code): Archos Player
#	2006/05/27 v3.5 - Only use the new callbacks if already supported by SlimServer
#			- Another fix for situations where no power event is sent
#			   by SlimServer even if power state of SB has changed (Thanks Peter)
#	2006/03/06 v3.4 - Additional fix to block IR Repeater while IR Blasting
#			- Use new callback functions: 'client new', 'client reconnect',
#			   'client disconnect' to get current power state and IR Repeater mode
#			- Fix a problem where IR Blaster entry was not visible
#	2006/02/16 v3.3 - Block IR Repeater while IR Blasting to prevent overlapping IR commands
#	2006/02/10 v3.2 - Possible fix for situations where no power event is sent
#			   by SlimServer even if power state of SB has changed
#	2006/01/15 v3.1 - Limit last gap to 200'000 (IR Repeater, IR Learning)
#	2006/01/05 v3.0 - IR Repeater functionality through SlimServer
#	2005/12/07 v2.9 - Learning: Remove first step of learning wizard
#			- Support for: 'plead', 'pre_databits' and 'post_databits' in RC5 remotes
#			- Check if file/device name is valid for filesystem
#	2005/10/30 v2.8 - Learning: Fix first (too long) gap
#	2005/10/19 v2.7 - Learning: Add ir learning wizard (done through SB2/SB3)
#	2005/10/11 v2.6 - Support of RAW_CODES format
#	2005/10/06 v2.5 - Fix a .conf parser error
#			- Ignore empty lines
#			- Fix a crash if a remote is not available anymore
#	2005/09/19 v2.4	- User selectable path for .conf files (defaults to where Plugin.pm is)
#			- Change name of setupGroup() to setupPrefs() to avoid confusion (Thanks kdf)
#			- Expose volume preset to top of file
#	2005/09/18 v2.3	- Rename IR BlastTest to IR-Blaster
#	2005/09/18 v2.2 - Read LIRC files with one or more remote descriptions
#	2005/09/17 v2.1	- Put strings into string table
#			- Use initPlugin, shutdownPlugin
#	2005/09/16 v2.0	- Web-page added to player settings if Setup.pm is tweaked (Thanks kdf)
#	2005/09/15 v1.9	- Remove some debug info, add (s) to delays, EN skin
#	2005/09/14 v1.8	- Better way to detect new clients
#	2005/09/13 v1.7	- Functionality to add/delete a specific row
#	2005/09/12 v1.6	- Allow multiple ir commands per action (done for volume up/down)
#	2005/09/11 v1.5	- Allow multiple ir commands per action (done for power on/off)
#	2005/09/10 v1.4	- Apply changes if clicking a test button (Thanks Greg)
#			- Support for SHIFT_ENC (which is the same as RC5)
#	2005/09/09 v1.3	- Support for old ITT format (no carrier)
#	2005/09/08 v1.2	- Make delay before sending a client parameter (Thanks Adrian & Dave)
#			- Replace select() with timer (Thanks Adrian)
#	2005/09/07 v1.1	- Per client web interface (only SB2/SB3)
#			- Persistent settings (per client)
#	2005/09/05 v1.0	- Support for: 'toogle_mask'
#	2005/08/28 v0.9	- Support for RC5 (Philips)
#			- Added test buttons for each command
#			- Make sure 'min_repeat' is at least set to 1
#	2005/08/26 v0.8	- Fix potental crash if no player is present (Thanks KDF)
#			- Fix path problem for different plattforms (Thanks Dave)
#	2005/08/22 v0.7	- Evaluate flag: NO_FOOT_REP
#			- Support for: 'foot'
#			- Fix flag NO_HEAD_REP
#	2005/08/21 v0.6	- Evaluate some flags: NO_HEAD_REP
#			- Format: SPACE_ENC supported only so far
#			- Support for 'frequency'
#			- Only link to power on/off if remote is selected
#			- Only link to volume up/down if remote is selected
#	2005/08/21 v0.5	- Link to power on/off and volume up/down
#	2005/08/20 v0.4	- Simplify command select in index.html
#			- Fix bug when sending 0 length header
#			- Support for 'post_data_bits'
#	2005/08/20 v0.3	- Simple Web interface
#	2005/08/19 v0.2	- Read LIRC config files
#	2005/08/01 v0.1	- Initial version
#	---------------------------------------------------------------------
#	To do:
#
#	- Path for config files is wrong on Mac OS X plattform
#	- Power/Volume does not work if players are synched
#	- Test (and fix) RC6 remotes
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
package Plugins::IRBlaster::Plugin;
use base qw(Slim::Plugin::Base);
use strict;

use Slim::Utils::Strings qw(string);
use Slim::Utils::Log;
use Slim::Utils::Prefs;

use File::Spec::Functions qw(:ALL);

use Plugins::IRBlaster::Settings;
use Plugins::IRBlaster::Learning;
use Plugins::IRBlaster::LearningXML;


# ----------------------------------------------------------------------------
# Global variables
# ----------------------------------------------------------------------------

my $gMaxFirmwareFifoSize = 50;	# Maximum number of ir codes the firmware fifo can hold
				# Increasing this value without changing firmware is not recommended

my $gOrigVolCmdFuncRef;			# Original function reference in SC
my $gOrigIRCmdFuncRef;			# Original function reference in SC
my $gOrigGetExternalVolumeInfoFuncRef;	# Original function reference in SC

# ----------------------------------------------------------------------------

our %remotes;	# Contains a record for each found remote

# ----------------------------------------------------------------------------
# References to other classes
my $classPlugin = undef;

# ----------------------------------------------------------------------------
my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.irblaster',
	'defaultLevel' => 'OFF',
	'description'  => 'PLUGIN_IRBLASTER_MODULE_NAME',
});

# ----------------------------------------------------------------------------
my $prefs = preferences( 'plugin.irblaster');

# ----------------------------------------------------------------------------
sub getDisplayName {
	return 'PLUGIN_IRBLASTER_MODULE_NAME';
}

# ----------------------------------------------------------------------------
sub initPlugin {
	$classPlugin = shift;

	# Initialize settings classes
	my $classSettings = Plugins::IRBlaster::Settings->new( $classPlugin);
	my $classLearning = Plugins::IRBlaster::Learning->new( $classPlugin);
	my $classLearningXML = Plugins::IRBlaster::LearningXML->new( $classPlugin, $classLearning);

	# Defaults to where the plugin resides (i.e. Plugins/IRBlaster/)
	if( !defined( $prefs->get( 'conffilepath'))) {
		my @pluginDir = Slim::Utils::OSDetect::dirsFor('Plugins');
		my $installDir = "";

		foreach my $dir (@pluginDir) {
			$log->debug( "*** IR-Blaster: plugin directory: " . $dir . "\n");

			opendir( DIR, $dir);
			if( grep { /^IRBlaster$/ } readdir( DIR)) {
				$log->debug( "*** IR-Blaster: found in plugin directory: " . $dir . "\n");
				$installDir = $dir;
			}
			closedir( DIR);
		}
		$prefs->set( 'conffilepath', catdir( $installDir, "IRBlaster"));
	}

	# Load remote files
	loadRemotes();
	
	# Install callback to get client power state, volume and connect/disconnect changes
	Slim::Control::Request::subscribe( \&commandCallback, [['power', 'play', 'playlist', 'pause', 'client']]);
	
	# Reroute all mixer volume requests
	$gOrigVolCmdFuncRef = Slim::Control::Request::addDispatch( ['mixer', 'volume', '_newvalue'], [1, 0, 0, \&myMixerVolumeCommand]);

	# Reroute all ir requests
	$gOrigIRCmdFuncRef = Slim::Control::Request::addDispatch( ['ir', '_ircode', '_time'], [1, 0, 0, \&myIRCommand]);

	# Expose to CLI
	Slim::Control::Request::addDispatch( ['irblaster', 'send', '_device', '_button'], [1, 0, 0, \&irblasterSendCommandCLI]);
	Slim::Control::Request::addDispatch( ['irblaster', 'devices'], [0, 0, 0, \&irblasterGetRemotesCLI]);
	Slim::Control::Request::addDispatch( ['irblaster', 'buttons', '_device'], [0, 0, 0, \&irblasterGetCodesCLI]);

	# Expose volume capabilities to CLI
	$gOrigGetExternalVolumeInfoFuncRef = Slim::Control::Request::addDispatch( ['getexternalvolumeinfo'], [0, 0, 0, \&getexternalvolumeinfoCLI]);

	# Turn on IR Repeater for all connected players if needed
	#  Might be after an SB got reset or SqueezeCenter restarted
	#
	# If SqueezeCenter supports 'client new' and 'client reconnect' this polling function is
	#  not needed anymore and the timer will be killed
	#
	Slim::Utils::Timers::setTimer( 47114711, (Time::HiRes::time() + 5.0), \&repeatCheckConnectedPlayers);

# Not calling our parent class prevents us from getting added in the player UI
#	$classPlugin->SUPER::initPlugin();
}

# ----------------------------------------------------------------------------
sub shutdownPlugin {

	Slim::Control::Request::unsubscribe( \&commandCallback);
	
	# Give up rerouting
	Slim::Control::Request::addDispatch( ['mixer', 'volume', '_newvalue'], [1, 0, 0, $gOrigVolCmdFuncRef]);

	# Give up rerouting
	Slim::Control::Request::addDispatch( ['ir', '_ircode', '_time'], [1, 0, 0, $gOrigIRCmdFuncRef]);

	# Give up rerouting
	Slim::Control::Request::addDispatch( ['getexternalvolumeinfo'], [0, 0, 0, $gOrigGetExternalVolumeInfoFuncRef]);

	Slim::Utils::Timers::killTimers( 47114711, \&repeatCheckConnectedPlayers); 
}

# ----------------------------------------------------------------------------
sub getRemotes {
	my $class = shift;

	return %remotes;
}

# ----------------------------------------------------------------------------
# IR Blaster: read all lirc remote files
# ----------------------------------------------------------------------------
sub loadRemotes {
	my $absPathToConfigFiles = $prefs->get( 'conffilepath');

	%remotes = ();	# Forget about all old remotes

	# Get all remote config files
	opendir( DIR, $absPathToConfigFiles);
	my @configFileNames = grep { /\.conf$/ } readdir( DIR);
	closedir( DIR);
	
	# Check if we have at least one config file
	if( scalar( @configFileNames) <= 0) {
		return;
	}
	
	# Read all LIRC files
	foreach my $configFileName ( @configFileNames) {
		$log->debug( "*** IR-Blaster: " . catfile( $absPathToConfigFiles, $configFileName) . "\n");

		# Read LIRC files - each file contains one or more remote descriptions
		my $remotesRef = readLIRCConfigFile( catfile( $absPathToConfigFiles, $configFileName));
		foreach my $remoteRef ( @$remotesRef) {
			$remotes{$remoteRef->{NAME}} = $remoteRef;
		}
	}

	# Debug output
	while( ( my $key, my $item) = each( %remotes)) {
		$log->debug( "********************************\n");
		$log->debug( "name:           " . $item->{NAME} . "\n");
		$log->debug( "bits:           " . $item->{BITS} . "\n");
		$log->debug( "flags:          " . $item->{FLAGS} . "\n");
		$log->debug( "header_high:    " . $item->{HEADER_HIGH} . "\n");
		$log->debug( "header_low:     " . $item->{HEADER_LOW} . "\n");
		$log->debug( "one_high:       " . $item->{ONE_HIGH} . "\n");
		$log->debug( "one_low:        " . $item->{ONE_LOW} . "\n");
		$log->debug( "zero_high:      " . $item->{ZERO_HIGH} . "\n");
		$log->debug( "zero_low:       " . $item->{ZERO_LOW} . "\n");
		$log->debug( "plead:          " . $item->{PLEAD} . "\n");
		$log->debug( "ptrail:         " . $item->{PTRAIL} . "\n");
		$log->debug( "pre_data_bits:  " . $item->{PRE_DATA_BITS} . "\n");
		$log->debug( "pre_data:       " . $item->{PRE_DATA} . "\n");
		$log->debug( "post_data_bits: " . $item->{POST_DATA_BITS} . "\n");
		$log->debug( "post_data:      " . $item->{POST_DATA} . "\n");
		$log->debug( "gap:            " . $item->{GAP} . "\n");
		$log->debug( "foot_high:      " . $item->{FOOT_HIGH} . "\n");
		$log->debug( "foot_low:       " . $item->{FOOT_LOW} . "\n");
		$log->debug( "min_repeat:     " . $item->{MIN_REPEAT} . "\n");
		$log->debug( "toggle_mask:    " . $item->{TOGGLE_MASK} . "\n");
		$log->debug( "frequency:      " . $item->{FREQUENCY} . "\n");
		foreach my $code (sort keys %{$item->{CODES}}) {
			$log->debug( $code . ":         " . $item->{CODES}{$code} . "\n");
		}
	}

#	# Get code sample
#	$log->debug( "*** IR-Blaster: " . $remotes{'SlimDevices'}->{CODES}{'power'} . "\n");
}

# ----------------------------------------------------------------------------
# IR Blaster: read a config file
#
# A LIRC config file contains one or more remote descriptions
# ----------------------------------------------------------------------------
sub readLIRCConfigFile {
	my $absPathToConfigFile = shift;

	my $line = "";
	my $remoteSection = 0;
	my $codesSection = 0;
	my $rawCodesSection = 0;
	
	my $rawCodeButtonName = "";
	
	my $i = 0;
	my @remotes = ();
	
	open( FH, $absPathToConfigFile);
	while( ( $line = <FH>)) {
		# Trim: Remove spaces before and after
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		
		$log->debug( $line . "\n");

		# Ignore empty lines
		if( $line eq "") {
			next;	
		}
		# Ignore comment lines starting with a #
		if( $line =~ m/^#/) {
			next;
		}

		if( $line =~ m/^begin remote/) {
			$remoteSection = 1;
			
			# Define new empty remote
			$remotes[$i]->{NAME} = "",
			$remotes[$i]->{BITS} = 0,
			$remotes[$i]->{FLAGS} = "",
			$remotes[$i]->{HEADER_HIGH} = 0,
			$remotes[$i]->{HEADER_LOW} = 0,
			$remotes[$i]->{ONE_HIGH} = 0,
			$remotes[$i]->{ONE_LOW} = 0,
			$remotes[$i]->{ZERO_HIGH} = 0,
			$remotes[$i]->{ZERO_LOW} = 0,
			$remotes[$i]->{PLEAD} = 0,
			$remotes[$i]->{PTRAIL} = 0,
			$remotes[$i]->{PRE_DATA_BITS} = 0,
			$remotes[$i]->{PRE_DATA} = 0,
			$remotes[$i]->{POST_DATA_BITS} = 0,
			$remotes[$i]->{POST_DATA} = 0,
			$remotes[$i]->{GAP} = 0,
			$remotes[$i]->{FOOT_HIGH} = 0,
			$remotes[$i]->{FOOT_LOW} = 0,
			$remotes[$i]->{MIN_REPEAT} = 1,
			$remotes[$i]->{TOGGLE_MASK} = 0,
			$remotes[$i]->{FREQUENCY} = 38400,
			$remotes[$i]->{CODES} = {},
			next;
		}
		if( $line =~ m/^end remote/) {
			$remoteSection = 0;
			$i++;			# Next remote description
			next;
		}
		if( $line =~ m/^begin codes/) {
			$codesSection = 1;
			next;
		}
		if( $line =~ m/^end codes/) {
			$codesSection = 0;
			next;
		}
		if( $line =~ m/^begin raw_codes/) {
			$rawCodesSection = 1;
			next;
		}
		if( $line =~ m/^end raw_codes/) {
			$rawCodesSection = 0;
			next;
		}
		

		if( $remoteSection == 1) {
			# Description of the remote, but not codes or raw_codes section
			if( ( $codesSection == 0) && ( $rawCodesSection == 0)) {
				if( $line =~ m/^name/) {
					$line =~ s/^name//;
					$line =~ s/^\s+//;
					$remotes[$i]->{NAME} = $line;
				} elsif( $line =~ m/^bits/) {
					$line =~ s/^bits//;
					$line =~ s/^\s+//;
					$remotes[$i]->{BITS} = $line;
				} elsif( $line =~ m/^flags/) {
					$line =~ s/^flags//;
					$line =~ s/^\s+//;
					$remotes[$i]->{FLAGS} = $line;
				} elsif( $line =~ m/^header/) {
					$line =~ s/^header//;
					$line =~ s/^\s+//;
					$line =~ s/ /,/;
					$line =~ s/ //g;
					my @arr = split( /,/, $line);
					$remotes[$i]->{HEADER_HIGH} = $arr[0];
					$remotes[$i]->{HEADER_LOW} = $arr[1];
				} elsif( $line =~ m/^one/) {
					$line =~ s/^one//;
					$line =~ s/^\s+//;
					$line =~ s/ /,/;
					$line =~ s/ //g;
					my @arr = split( /,/, $line);
					$remotes[$i]->{ONE_HIGH} = $arr[0];
					$remotes[$i]->{ONE_LOW} = $arr[1];
				} elsif( $line =~ m/^zero/) {
					$line =~ s/^zero//;
					$line =~ s/^\s+//;
					$line =~ s/ /,/;
					$line =~ s/ //g;
					my @arr = split( /,/, $line);
					$remotes[$i]->{ZERO_HIGH} = $arr[0];
					$remotes[$i]->{ZERO_LOW} = $arr[1];
				} elsif( $line =~ m/^plead/) {
					$line =~ s/^plead//;
					$line =~ s/^\s+//;
					$remotes[$i]->{PLEAD} = $line;
				} elsif( $line =~ m/^ptrail/) {
					$line =~ s/^ptrail//;
					$line =~ s/^\s+//;
					$remotes[$i]->{PTRAIL} = $line;
				} elsif( $line =~ m/^pre_data_bits/) {
					$line =~ s/^pre_data_bits//;
					$line =~ s/^\s+//;
					$remotes[$i]->{PRE_DATA_BITS} = $line;
				} elsif( $line =~ m/^pre_data /) {
					$line =~ s/^pre_data//;
					$line =~ s/^\s+//;
					$remotes[$i]->{PRE_DATA} = $line;
				} elsif( $line =~ m/^post_data_bits/) {
					$line =~ s/^post_data_bits//;
					$line =~ s/^\s+//;
					$remotes[$i]->{POST_DATA_BITS} = $line;
				} elsif( $line =~ m/^post_data /) {
					$line =~ s/^post_data//;
					$line =~ s/^\s+//;
					$remotes[$i]->{POST_DATA} = $line;
				} elsif( $line =~ m/^gap/) {
					$line =~ s/^gap//;
					$line =~ s/^\s+//;
					$remotes[$i]->{GAP} = $line;
				} elsif( $line =~ m/^foot/) {
					$line =~ s/^foot//;
					$line =~ s/^\s+//;
					$line =~ s/ /,/;
					$line =~ s/ //g;
					my @arr = split( /,/, $line);
					$remotes[$i]->{FOOT_HIGH} = $arr[0];
					$remotes[$i]->{FOOT_LOW} = $arr[1];
				} elsif( $line =~ m/^min_repeat/) {
					$line =~ s/^min_repeat//;
					$line =~ s/^\s+//;
					$remotes[$i]->{MIN_REPEAT} = $line;
					# Make sure MIN_REPEAT is at least set to 1
					if( $remotes[$i]->{MIN_REPEAT} < 1) {
						$remotes[$i]->{MIN_REPEAT} = 1;
					}
				} elsif( $line =~ m/^toggle_mask/) {
					$line =~ s/^toggle_mask//;
					$line =~ s/^\s+//;
					$remotes[$i]->{TOGGLE_MASK} = $line;
				} elsif( $line =~ m/^frequency/) {
					$line =~ s/^frequency//;
					$line =~ s/^\s+//;
					$remotes[$i]->{FREQUENCY} = $line;
					# Make sure FREQUENCY is at least set to 36000
					if( $remotes[$i]->{FREQUENCY} < 36000) {
						$remotes[$i]->{FREQUENCY} = 36000;
					}
				}
			# Codes section
			} elsif( $codesSection == 1) {
				# $line = <button-name>             <button-code>
				$line =~ s/ /,/;
				# $line = <button-name>,            <button-code>
				$line =~ s/ //g;
				# $line = <button-name>,<button-code>
				my @arr = split( /,/, $line);
		
				$log->debug( "*** IR-Blaster: " . $arr[0] . " " . $arr[1] . "\n");
	
				$remotes[$i]->{CODES}{$arr[0]} = $arr[1];
			# RAW Codes section
			} elsif( $rawCodesSection == 1) {
				if( $line =~ m/^name/) {
					$line =~ s/^name//;
					$line =~ s/^\s+//;
					$rawCodeButtonName = $line;	
				} elsif( $rawCodeButtonName ne "") {
					# $line = <pulse>    <space>    <pulse>    <space>    <pulse>    <space>
					$line =~ s/\s+/,/g;					
					# $line = <pulse>,<space>,<pulse>,<space>,<pulse>,<space>
					$remotes[$i]->{CODES}{$rawCodeButtonName} .= $line . ',';
				}
			} else {
				$log->debug( "*** IR-Blaster: Unknown section\n");
			}
		}  # if( $remoteSection == 1)
	}
	close( FH);
	return( \@remotes);
}

# ----------------------------------------------------------------------------
# IRBlaster: Expose to CLI - send a command
# ----------------------------------------------------------------------------
sub irblasterSendCommandCLI {
	my $request = shift;

	# Check this is the correct query
	if( $request->isNotCommand( [['irblaster', 'send']])) {
		$request->setStatusBadDispatch();
		return;
	}

	# get our parameters
	my $client = $request->client();
	my $device   = $request->getParam( '_device');
	my $button   = $request->getParam( '_button');
	
	$log->debug( "*** IRBlaster CLI Device: " . $device . "\n");
	$log->debug( "*** IRBlaster CLI Button: " . $button . "\n");

	# IRBlaster only works with SB2/3 and Transporter
	if( !defined( $client) || !( ( $client->model() eq 'squeezebox2') || ( $client->model() eq 'transporter'))) {
		return;
	}

	$classPlugin->IRBlastSend( $client, $device, $button);

	$request->setStatusDone();
}

# ----------------------------------------------------------------------------
# IRBlaster: Expose to CLI - list with all loaded remotes
# ----------------------------------------------------------------------------
sub irblasterGetRemotesCLI {
	my $request = shift;

	# Check this is the correct query
	if( $request->isNotCommand( [['irblaster', 'devices']])) {
		$request->setStatusBadDispatch();
		return;
	}

	my $deviceList = join ',', (sort keys %remotes);

	$request->addResult('devices', $deviceList);
}

# ----------------------------------------------------------------------------
# IRBlaster: Expose to CLI - list with all codes for a remote
# ----------------------------------------------------------------------------
sub irblasterGetCodesCLI {
	my $request = shift;

	# Check this is the correct query
	if( $request->isNotCommand( [['irblaster', 'buttons']])) {
		$request->setStatusBadDispatch();
		return;
	}

	my $device   = $request->getParam( '_device');
	my $codeList = "";

	while( ( my $key, my $item) = each( %remotes)) {
		if( $device eq $item->{NAME}) {
			$codeList = join ',', (sort keys %{$item->{CODES}});
		}
	}
	$request->addResult('buttons', $codeList);
}

# ----------------------------------------------------------------------------
# IRBlaster: Expose volume capabilities to CLI
# ----------------------------------------------------------------------------
sub getexternalvolumeinfoCLI {
        my @args = @_;

        &reportOnOurPlayers();
        if ( defined( $gOrigGetExternalVolumeInfoFuncRef)) {
                # chain to the next implementation
                return &$gOrigGetExternalVolumeInfoFuncRef( @args);
        }
        # else we're authoritative
        my $request = $args[0];
        $request->setStatusDone();
}

# ----------------------------------------------------------------------------
# IRBlaster: Expose volume capabilities to CLI
# ----------------------------------------------------------------------------
sub reportOnOurPlayers() {
        # loop through all currently attached players
        foreach my $client (Slim::Player::Client::clients()) {
                if( $classPlugin->checkVolumeCommandAssigned( $client)) {
                        # using our volume control, report on our capabilities
                        $log->debug( "Note that " . $client->name() . " uses us for external volume control");
                        Slim::Control::Request::notifyFromArray( $client, ['getexternalvolumeinfo', 'relative:1', 'precise:0', 'plugin:IR-Blaster']);
                        # precise:0             can _not_ set exact volume
                        # relative:1            can make relative volume changes
                        # plugin:IR-Blaster     this plugin's name
                }
        }
}

# ----------------------------------------------------------------------------
# IR Blaster: send out a command in one of the supported formats (NEC,RC5,RAW,...)
#
# This function needs to be called as class member function, i.e. first parameter is reference to class
# ----------------------------------------------------------------------------
sub IRBlastSend {
	my $class = shift;
	my $client = shift;
	my $remoteName = shift;
	my $button = shift;
	
	$log->debug( "*** IR-Blaster: IRBlastSend - client:" . $client . "\n");
	$log->debug( "*** IR-Blaster: IRBlastSend - remoteName:" . $remoteName . "\n");
	$log->debug( "*** IR-Blaster: IRBlastSend - button:" . $button . "\n");

	if( !defined( $client)) {
		$log->debug( "*** IR-Blaster: Error: no client defined\n");
		return;
	}
	if( $remoteName eq "-1") {
		$log->debug( "*** IR-Blaster: Error: no remote defined\n");
		return;
	}
	if( $button eq "") {
		$log->debug( "*** IR-Blaster: Error: no command defined\n");
		return;
	}
	
	my $bFound = 0;
	while( ( my $key, my $item) = each( %remotes)) {
		if( $item->{NAME} eq $remoteName) {
			$bFound = 1;
		}
	}
	if( $bFound == 0) {
		$log->debug( "*** IR-Blaster: Error: requested remote is not loaded (anymore)\n");
		return;	
	}		

	# (Microseconds / modulation period)
	my $IR_BITS 		= $remotes{$remoteName}->{BITS};
	my $IR_FLAGS            = $remotes{$remoteName}->{FLAGS};
	my $IR_HEADER_H		= $remotes{$remoteName}->{HEADER_HIGH};
	my $IR_HEADER_L		= $remotes{$remoteName}->{HEADER_LOW};
	my $IR_ZERO_H		= $remotes{$remoteName}->{ZERO_HIGH};
	my $IR_ZERO_L		= $remotes{$remoteName}->{ZERO_LOW};
	my $IR_ONE_H		= $remotes{$remoteName}->{ONE_HIGH};
	my $IR_ONE_L		= $remotes{$remoteName}->{ONE_LOW};
	my $IR_PLEAD		= $remotes{$remoteName}->{PLEAD};
	my $IR_PTRAIL		= $remotes{$remoteName}->{PTRAIL};
	my $IR_PRE_DATA_BITS	= $remotes{$remoteName}->{PRE_DATA_BITS};
	my $IR_PRE_DATA		= $remotes{$remoteName}->{PRE_DATA};
	my $IR_POST_DATA_BITS	= $remotes{$remoteName}->{POST_DATA_BITS};
	my $IR_POST_DATA	= $remotes{$remoteName}->{POST_DATA};
	my $IR_GAP		= $remotes{$remoteName}->{GAP};
	my $IR_FOOT_H		= $remotes{$remoteName}->{FOOT_HIGH};
	my $IR_FOOT_L		= $remotes{$remoteName}->{FOOT_LOW};
	my $IR_MIN_REPEAT 	= $remotes{$remoteName}->{MIN_REPEAT};
	my $IR_TOGGLE_MASK	= $remotes{$remoteName}->{TOGGLE_MASK};
	my $IR_FREQUENCY	= $remotes{$remoteName}->{FREQUENCY};

	my $MODULATION		= 1000000 / $IR_FREQUENCY;  # IR_FREQUENCY default: 38400 ==> 26.042 uS

	my $code = $remotes{$remoteName}->{CODES}{$button};

	$log->debug( "IR-Blaster: min_repeat: $IR_MIN_REPEAT, code: $code\n");

	my $nextTime = 0.2;

	# SPACE_ENC, ITT, RC5 (=SHIFT_ENC), RC6 (_not_ RAW_CODES)
	if( $IR_FLAGS !~ m/RAW_CODES/) {
	
		$IR_PRE_DATA = hex( $IR_PRE_DATA);
		$IR_POST_DATA = hex( $IR_POST_DATA);
		$code = hex( $code);

		for( my $iRepeatCount = 0; $iRepeatCount < $IR_MIN_REPEAT; $iRepeatCount++) {
			my $ircode = "";
			my $bitcount = 0;

			# Apply toggle_mask to bits
			if( $iRepeatCount > 0) {
				$code = $code ^ hex( $IR_TOGGLE_MASK);
			}			

			# **********************
			# *** SPACE_ENC - Remote
		
			if( $IR_FLAGS =~ m/SPACE_ENC/) {
				# Header (only sent if not 0)
				if( ( $IR_HEADER_H != 0) && ( $IR_HEADER_L != 0)) {
					# Send header only once if NO_HEAD_REP is present
					if( $iRepeatCount == 0) {
						$ircode .= IRBlastPulse( $IR_HEADER_H, $IR_HEADER_L, $MODULATION);
					} elsif( $IR_FLAGS !~ m/NO_HEAD_REP/) {
						$ircode .= IRBlastPulse( $IR_HEADER_H, $IR_HEADER_L, $MODULATION);
					}			
				}
				# PreDataBits
				for( $bitcount = $IR_PRE_DATA_BITS - 1; $bitcount >= 0; $bitcount--) {	
					if( $IR_PRE_DATA & ( 1 << $bitcount)) {
						$ircode .= IRBlastPulse( $IR_ONE_H, $IR_ONE_L, $MODULATION);
						$log->debug( "1");
					} else {
						$ircode .= IRBlastPulse( $IR_ZERO_H, $IR_ZERO_L, $MODULATION);
						$log->debug( "0");
					}
				}
				# Bits
				for( $bitcount = $IR_BITS - 1; $bitcount >= 0; $bitcount--) {	
					if( $code & ( 1 << $bitcount)) {
						$ircode .= IRBlastPulse( $IR_ONE_H, $IR_ONE_L, $MODULATION);
						$log->debug( "1");
					} else {
						$ircode .= IRBlastPulse( $IR_ZERO_H, $IR_ZERO_L, $MODULATION);
						$log->debug( "0");
					}
				}
				# PostDataBits
				for( $bitcount = $IR_POST_DATA_BITS - 1; $bitcount >= 0; $bitcount--) {	
					if( $IR_POST_DATA & ( 1 << $bitcount)) {
						$ircode .= IRBlastPulse( $IR_ONE_H, $IR_ONE_L, $MODULATION);
						$log->debug( "1");
					} else {
						$ircode .= IRBlastPulse( $IR_ZERO_H, $IR_ZERO_L, $MODULATION);
						$log->debug( "0");
					}
				}
				# Ptrail (only sent if not 0)
				if( ( $IR_PTRAIL != 0) && ( $IR_GAP != 0)) {
					$ircode .= IRBlastPulse( $IR_PTRAIL, $IR_GAP, $MODULATION);
				}
				# Foot (only sent if not 0)
				if( ( $IR_FOOT_H != 0) && ( $IR_FOOT_L != 0)) {
					# Send foot only once if NO_FOOT_REP is present
					if( $iRepeatCount == 0) {
						$ircode .= IRBlastPulse( $IR_FOOT_H, $IR_FOOT_L, $MODULATION);
					} elsif( $IR_FLAGS !~ m/NO_FOOT_REP/) {
						$ircode .= IRBlastPulse( $IR_FOOT_H, $IR_FOOT_L, $MODULATION);
					}			
				}

			# ****************
			# *** ITT - Remote

			# Setting the first parameter (high-time) and the third parameter (modulation)
			#  in IRBlastPulse() to 1 forces the firmware to use ITT mode which
			#  consists of 20us pulses with different low-times and no carrier

			} elsif( $IR_FLAGS =~ m/ITT/) {
				# Header (only sent if not 0)
				if( ( $IR_HEADER_H != 0) && ( $IR_HEADER_L != 0)) {
					$ircode .= IRBlastPulse( 1, $IR_HEADER_L, 1);
				}
				# Bits
				for( $bitcount = $IR_BITS - 1; $bitcount >= 0; $bitcount--) {	
					if( $code & ( 1 << $bitcount)) {
						$ircode .= IRBlastPulse( 1, $IR_ONE_L, 1);
						$log->debug( "1");
					} else {
						$ircode .= IRBlastPulse( 1, $IR_ZERO_L, 1);
						$log->debug( "0");
					}
				}
				# Ptrail (only sent if not 0)
				if( ( $IR_PTRAIL != 0) && ( $IR_GAP != 0)) {
					$ircode .= IRBlastPulse( 1, $IR_GAP, 1);
				}
				# Foot (only sent if not 0)
				if( ( $IR_FOOT_H != 0) && ( $IR_FOOT_L != 0)) {
					$ircode .= IRBlastPulse( 1, $IR_FOOT_L, 1);
				}

			# ****************
			# *** RC5 - Remote (same as SHIFT_ENC - remotes)
		
			# Setting the second parameter (low-time) in IRBlastPulse() to 0 forces
			#  the firmware to use RC5 mode to produce a symmetric space-mark-pulse
		
			} elsif( ( $IR_FLAGS =~ m/RC5/) || ( $IR_FLAGS =~ m/SHIFT_ENC/)) {

				# Plead (only sent if not 0)
				if( $IR_PLEAD != 0) {
					# Setting low time to 0 means space-mark-pulse
					$ircode .= IRBlastPulse( $IR_PLEAD, 0, $MODULATION);
					$log->debug( "1");
				}
				# PreDataBits
				for( $bitcount = $IR_PRE_DATA_BITS - 1; $bitcount >= 0; $bitcount--) {	
					if( $IR_PRE_DATA & ( 1 << $bitcount)) {
						# Setting low time to 0 means space-mark-pulse
						$ircode .= IRBlastPulse( $IR_ONE_H, 0, $MODULATION);
						$log->debug( "1");
					} else {
						$ircode .= IRBlastPulse( $IR_ZERO_H, $IR_ZERO_L, $MODULATION);
						$log->debug( "0");
					}
				}
				# Bits
				for( $bitcount = $IR_BITS - 1; $bitcount >= 0; $bitcount--) {	
					if( $code & ( 1 << $bitcount)) {
						# Setting low time to 0 means space-mark-pulse
						$ircode .= IRBlastPulse( $IR_ONE_H, 0, $MODULATION);
						$log->debug( "1");
					} else {
						$ircode .= IRBlastPulse( $IR_ZERO_H, $IR_ZERO_L, $MODULATION);
						$log->debug( "0");
					}
				}
				# PostDataBits
				for( $bitcount = $IR_POST_DATA_BITS - 1; $bitcount >= 0; $bitcount--) {	
					if( $IR_POST_DATA & ( 1 << $bitcount)) {
						# Setting low time to 0 means space-mark-pulse
						$ircode .= IRBlastPulse( $IR_ONE_H, 0, $MODULATION);
						$log->debug( "1");
					} else {
						$ircode .= IRBlastPulse( $IR_ZERO_H, $IR_ZERO_L, $MODULATION);
						$log->debug( "0");
					}
				}

			# ***********************************
			# *** RC6 - Remote - _not_ tested yet
		
			} elsif( $IR_FLAGS =~ m/RC6/) {
				# Header (only sent if not 0)
				if( ( $IR_HEADER_H != 0) && ( $IR_HEADER_L != 0)) {
					# Send header only once if NO_HEAD_REP is present
					if( $iRepeatCount == 0) {
						$ircode .= IRBlastPulse( $IR_HEADER_H, $IR_HEADER_L, $MODULATION);
					} elsif( $IR_FLAGS !~ m/NO_HEAD_REP/) {
						$ircode .= IRBlastPulse( $IR_HEADER_H, $IR_HEADER_L, $MODULATION);
					}			
				}
				# Start Bit
				$ircode .= IRBlastPulse( $IR_ONE_H, $IR_ONE_L, $MODULATION);
				$log->debug( "1");
				# Mode Bits
				$ircode .= IRBlastPulse( $IR_ONE_H, $IR_ONE_L, $MODULATION);
				$log->debug( "1");
				$ircode .= IRBlastPulse( $IR_ONE_H, $IR_ONE_L, $MODULATION);
				$log->debug( "1");
				$ircode .= IRBlastPulse( $IR_ONE_H, $IR_ONE_L, $MODULATION);
				$log->debug( "1");
				# Toggle Bit
				$ircode .= IRBlastPulse( $IR_ONE_H * 2, $IR_ONE_L * 2, $MODULATION);
				$log->debug( "1");
				# Bits
				for( $bitcount = 16 - 1; $bitcount >= 0; $bitcount--) {	
					if( $code & ( 1 << $bitcount)) {
						$ircode .= IRBlastPulse( $IR_ONE_H, $IR_ONE_L, $MODULATION);
						$log->debug( "1");
					} else {
						$ircode .= IRBlastPulse( $IR_ZERO_H, 0, $MODULATION);
						$log->debug( "0");
					}
				}

			# ***********************************
			# *** Unknown remote
		
			} else {
				$log->debug( "*** IR-Blaster: Unknown remote type.\n");
			}		

			$log->debug( "\n");

			Slim::Utils::Timers::setTimer( $client,
				Time::HiRes::time() + $nextTime,
				\&IRBlastSendCallback,
				(\$ircode));
			
			$nextTime += 0.05;
		}  # for( .. )

	# ***********************************
	# *** RAW_CODES

	} else {
		my $ircode = "";
# Block sending while still busy
		my $irtime = "";
		my @arrCodes = split( /,/, $code);
		my $numCodes = scalar( @arrCodes);
	
		$log->debug( "*** IRBlaster: RAW: num of codes: " . $numCodes . "\n");
		
		# Firmware: Max fifo buffer size is currently 50 high-low-pairs
		if( $numCodes > ( 2 * $gMaxFirmwareFifoSize)) {
			$numCodes = ( 2 * $gMaxFirmwareFifoSize);
		}
	
		for( my $i = 0; $i < $numCodes; $i = $i + 2) {
			if( ( $i + 1) < $numCodes) {
				$ircode .= IRBlastPulse( $arrCodes[$i], $arrCodes[$i+1], $MODULATION);
# Block sending while still busy
				$irtime += $arrCodes[$i] + $arrCodes[$i+1];

				$log->debug( "*** IRBlaster: RAW: mark: " . $arrCodes[$i] . " space: " . $arrCodes[$i+1] . "\n");

			} else {
				$ircode .= IRBlastPulse( $arrCodes[$i], $IR_GAP, $MODULATION);
# Block sending while still busy
				$irtime += $arrCodes[$i] + $IR_GAP;

				$log->debug( "*** IRBlaster: RAW: mark: " . $arrCodes[$i] . " gap: " . $IR_GAP . "\n");

			}
		}
# Block sending while still busy
#		Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + $nextTime, \&IRBlastSendCallback, (\$ircode));
		Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + $nextTime, \&IRBlastSendCallback_2, (\$ircode, $irtime/1000000));
	}

}

# ---------------------------------------------------------------------------- 
# IR Blaster:
# ----------------------------------------------------------------------------
sub IRBlastSendCallback {
	my $client = shift;
	my $ircoderef = shift;
	
	# Setting the geekport is only needed for SB2/3, but it doesn't hurt
	#  on a Transporter, it's just ignored
	# Set geekport mode to 'BLASTER'
	my $geekmode = pack( 'C', 1);
	$client->sendFrame( 'geek', \$geekmode);

	$client->sendFrame( 'blst', $ircoderef);
}

# Block sending while still busy
my %bBlockSendWhileBusy;

# Block sending while still busy
# ---------------------------------------------------------------------------- 
# IR Blaster:
# ----------------------------------------------------------------------------
sub IRBlastSendCallback_2 {
	my $client = shift;
	my $ircoderef = shift;
	my $irtime = shift;

	$log->info( "*** IRBlaster: IRBlasttSendCallback_2 - enter\n");
	if( defined( $bBlockSendWhileBusy{$client}) && $bBlockSendWhileBusy{$client} == 1) {
		$log->info( "*** IRBlaster: IRBlasttSendCallback_2 - blocked\n");
		return;
	}
	$bBlockSendWhileBusy{$client} = 1;
	
	# Setting the geekport is only needed for SB2/3, but it doesn't hurt
	#  on a Transporter, it's just ignored
	# Set geekport mode to 'BLASTER'
	my $geekmode = pack( 'C', 1);
	$client->sendFrame( 'geek', \$geekmode);

	$client->sendFrame( 'blst', $ircoderef);

	Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + $irtime, \&UnblockSendWhileBusy);
}

# Block sending while still busy
# ---------------------------------------------------------------------------- 
# IR Blaster:
# ----------------------------------------------------------------------------
sub UnblockSendWhileBusy {
	my $client = shift;

	$bBlockSendWhileBusy{$client} = 0;
}

# ----------------------------------------------------------------------------
# IR Blaster:
#
# If lowtime is _not_ set to 0			-> Firmware generates a MARK(hightime) SPACE(lowtime) pulse
# If lowtime is set to 0			-> Firmware generates a SPACE(hightime) MARK(hightime) pulse (symmetric)
# If hightime and modulation are set to 1	-> Firmware generates a 20uS ITT format (no carrier) pulse
# ----------------------------------------------------------------------------
sub IRBlastPulse {
	my $hightime = shift;
	my $lowtime = shift;
	my $MODULATION = shift;

	my $ircode = pack('n', int($hightime / $MODULATION));
	$ircode .= pack('n', int($lowtime / $MODULATION));
	
	return $ircode;
}

# Actual power state (needed for internal tracking)
my %iOldPowerState;
# Used to temporarily block IR Repeater functionality (while IR Blasting)
my %iBlockIRRepeater;

# ----------------------------------------------------------------------------
# IR Blaster: Callback to get client power state changes
# ----------------------------------------------------------------------------
sub commandCallback {
	my $request = shift;

	my $client = $request->client();

	$log->debug( "*** IR-Blaster: commandCallback() p0: " . $request->{'_request'}[0] . "\n");
	$log->debug( "*** IR-Blaster: commandCallback() p1: " . $request->{'_request'}[1] . "\n");
	
	# IRBlaster only works with SB2/3 and Transporter
	if( !defined( $client) || !( ( $client->model() eq 'squeezebox2') || ( $client->model() eq 'transporter'))) {
		return;
	}

	# Get power on and off commands
	# Sometimes we do get only a power command, sometimes only a play/pause command and sometimes both
	if( $request->isCommand([['power']])
	 || $request->isCommand([['play']])
	 || $request->isCommand([['pause']])
	 || $request->isCommand([['playlist'], ['newsong']]) ) {
		my $iPower = $client->power();
		
		# Check with last known power state -> if different send IR command
		if( $iOldPowerState{$client} ne $iPower) {
			$iOldPowerState{$client} = $iPower;

			$log->debug( "*** IR-Blaster: commandCallback() Power: $iPower\n");

			handlePowerOnOff( $client, $iPower);
		}

	# Get newclient events
	} elsif( $request->isCommand([['client'], ['new']])
	      || $request->isCommand([['client'], ['reconnect']])) {
		my $subCmd = $request->{'_request'}[1];
	
		$log->debug( "*** IR-Blaster: commandCallback() client: $subCmd\n");
			
		# SqueezeCenter supports 'client new' and 'client reconnect' so we do not need
		#  our polling function
		Slim::Utils::Timers::killTimers( 47114711, \&repeatCheckConnectedPlayers); 

		reInitializePlayer( $client);
	}
}

# ----------------------------------------------------------------------------
# IR Blaster: Volume changes are rerouted here, if volume ir commands are
#              defined, we leave the volume in SB at fixed volume level
# ----------------------------------------------------------------------------
sub myIRCommand {
	my $request = shift;

	my $client = $request->client();

	$log->info( "*** IR-Blaster: ******\n");

	# IRBlaster only works with SB2/3 and Transporter
	if( !defined( $client) || !( ( $client->model() eq 'squeezebox2') || ( $client->model() eq 'transporter'))) {
		# Call original function in SqueezeCenter
		eval { & { $gOrigIRCmdFuncRef} ($request) };
		return;
	}

	my $irCodeBytes = $request->getParam( '_ircode');
	my $irCode = Slim::Hardware::IR::lookupCodeBytes( $client, $irCodeBytes);
	if( $irCode eq 'volup') {
		&handleVolUpDown( $client, '+1');
	}
	if( $irCode eq 'voldown') {
		&handleVolUpDown( $client, '-1');
	}
	
	# Call original function in SqueezeCenter
	eval { & { $gOrigIRCmdFuncRef} ($request) };
}

# ----------------------------------------------------------------------------
# IR Blaster: Volume changes are rerouted here, if volume ir commands are
#              defined, we leave the volume in SB at fixed volume level
# ----------------------------------------------------------------------------
sub myMixerVolumeCommand {
	my $request = shift;

	my $client = $request->client();

	$log->info( "*** IR-Blaster: ******\n");

	# IRBlaster only works with SB2/3 and Transporter
	if( !defined( $client) || !( ( $client->model() eq 'squeezebox2') || ( $client->model() eq 'transporter'))) {
		# Call original function in SqueezeCenter
		eval { & { $gOrigVolCmdFuncRef} ($request) };
		return;
	}

	&handleVolUpDown( $client, $request->getParam( '_newvalue'));

	# Check if there is at least one volume command assigned
	#  and only if so, fix the volume
	my $atLeastOneUpCommand = 0;
	for( my $i = 0; $i < $prefs->client($client)->get('volumeup_count'); $i++) {
		if( $prefs->client($client)->get('volumeup_remote')->[$i] ne "-1") {
			$atLeastOneUpCommand = 1;
			last;
		}
	}
	my $atLeastOneDownCommand = 0;
	for( my $i = 0; $i < $prefs->client($client)->get('volumedown_count'); $i++) {
		if( $prefs->client($client)->get('volumedown_remote')->[$i] ne "-1") {
			$atLeastOneDownCommand = 1;
			last;
		}
	}
	if( ( $atLeastOneUpCommand == 1) || ( $atLeastOneDownCommand == 1)) {

		my $fixedVolume = $prefs->client($client)->get('fixedvolume');

		if( $fixedVolume > 100) {
			$fixedVolume = 100;
		}

		$request->deleteParam( '_newvalue');
		$request->addParam( '_newvalue', $fixedVolume);

	}

	# Call original function in SqueezeCenter
	eval { & { $gOrigVolCmdFuncRef} ($request) };
}

# ----------------------------------------------------------------------------
# IR Blaster: PowerOnOff handler
# ----------------------------------------------------------------------------
sub handlePowerOnOff {
	my $client = shift;
	my $bOn = shift;

	$log->debug( "*** IR-Blaster: handlePowerSwitch() on: $bOn\n");

	if( $bOn == 1) {
		if( $prefs->client($client)->get('poweron_count') > 0) {
			Slim::Utils::Timers::setTimer( $client,
				Time::HiRes::time() + $prefs->client($client)->get('poweron_delay')->[0],
				\&handlePowerOnCallback,
				( 0));
		}
	} else {
		if( $prefs->client($client)->get('poweroff_count') > 0) {
			Slim::Utils::Timers::setTimer( $client,
				Time::HiRes::time() + $prefs->client($client)->get('poweroff_delay')->[0],
				\&handlePowerOffCallback,
				( 0));
		}
	}
}

# ----------------------------------------------------------------------------
# IR Blaster: PowerOnOff handler
# ----------------------------------------------------------------------------
sub handlePowerOnCallback {
	my $client = shift;
	my $i = shift;
	
	# Block IR Repeater for about 1 second
	Slim::Utils::Timers::killTimers( $client, \&unblockIRRepeater);
	$iBlockIRRepeater{$client} = 1;
	Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + 1.0, \&unblockIRRepeater);

	Slim::Utils::Timers::killTimers( $client, \&handlePowerOnCallback); 
	$classPlugin->IRBlastSend( $client,
		$prefs->client($client)->get('poweron_remote')->[$i],
		$prefs->client($client)->get('poweron_command')->[$i]);
	$i++;
	if( $prefs->client($client)->get('poweron_count') > $i) {
		Slim::Utils::Timers::setTimer( $client,
			Time::HiRes::time() +  + $prefs->client($client)->get('poweron_delay')->[$i],
			\&handlePowerOnCallback,
			( $i));
	}
}

# ----------------------------------------------------------------------------
# IR Blaster: PowerOnOff handler
# ----------------------------------------------------------------------------
sub handlePowerOffCallback {
	my $client = shift;
	my $i = shift;
	
	# Block IR Repeater for about 1 second
	Slim::Utils::Timers::killTimers( $client, \&unblockIRRepeater);
	$iBlockIRRepeater{$client} = 1;
	Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + 1.0, \&unblockIRRepeater);

	Slim::Utils::Timers::killTimers( $client, \&handlePowerOffCallback); 
	$classPlugin->IRBlastSend( $client,
		$prefs->client($client)->get('poweroff_remote')->[$i],
		$prefs->client($client)->get('poweroff_command')->[$i]);
	$i++;
	if( $prefs->client($client)->get('poweroff_count') > $i) {
		Slim::Utils::Timers::setTimer( $client,
			Time::HiRes::time() + $prefs->client($client)->get('poweroff_delay')->[$i],
			\&handlePowerOffCallback,
			( $i));
	}
}

# ----------------------------------------------------------------------------
# IR Blaster: VolumeUpDown handler
# ----------------------------------------------------------------------------
sub handleVolUpDown {
	my $client = shift;
	my $newVol = shift;
	
	my $sign = 0;
	my $up = 0;

	my $fixedVolume = $prefs->client($client)->get('fixedvolume') || 100;

	# Up / Down volume commands (remote) have a sign (i.e. -2.5)
	# Absolute volumes (Web interface) do not have a sign
	# Transporter knob volume is also absolute and not useable at the moment

	if( $newVol =~ m/(^[+-])/) {
		$sign = 1;
	}
	
	$log->debug( "*** IR-Blaster: new volume: " . $newVol . "\n");
	$log->debug( "*** IR-Blaster: sign: " . $sign . "\n");

	if( ( $sign == 1) && ( $newVol == 0)) {
		return;
	}
	
	if( $sign == 0) {
		if( $newVol > ( $fixedVolume - 1)) {
			$up = 1;
		}
	} else {
		if( $newVol > 0) {
			$up = 1;
		}
	}

	$log->debug( "*** IR-Blaster: up: " . $up . "\n");
	
	if( $up eq 1) {
		if( $prefs->client($client)->get('volumeup_count') > 0) {
			Slim::Utils::Timers::setTimer( $client,
				Time::HiRes::time() + $prefs->client($client)->get('volumeup_delay')->[0],
				\&handleVolumeUpCallback,
				( 0));
		}
	} else {
		if( $prefs->client($client)->get('volumedown_count') > 0) {
			Slim::Utils::Timers::setTimer( $client,
				Time::HiRes::time() + $prefs->client($client)->get('volumedown_delay')->[0],
				\&handleVolumeDownCallback,
				( 0));
		}
	}
}

# ----------------------------------------------------------------------------
# IR Blaster: VolumeUpDown handler
# ----------------------------------------------------------------------------
sub handleVolumeUpCallback {
	my $client = shift;
	my $i = shift;
	
	# Block IR Repeater for about 1 second
	Slim::Utils::Timers::killTimers( $client, \&unblockIRRepeater);
	$iBlockIRRepeater{$client} = 1;
	Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + 1.0, \&unblockIRRepeater);
	
	Slim::Utils::Timers::killTimers( $client, \&handleVolumeUpCallback); 
	$classPlugin->IRBlastSend( $client,
		$prefs->client($client)->get('volumeup_remote')->[$i],
		$prefs->client($client)->get('volumeup_command')->[$i]);
	$i++;
	if( $prefs->client($client)->get('volumeup_count') > $i) {
		Slim::Utils::Timers::setTimer( $client,
			Time::HiRes::time() + $prefs->client($client)->get('volumeup_delay')->[$i],
			\&handleVolumeUpCallback,
			( $i));
	}
}

# ----------------------------------------------------------------------------
# IR Blaster: VolumeUpDown handler
# ----------------------------------------------------------------------------
sub handleVolumeDownCallback {
	my $client = shift;
	my $i = shift;
	
	# Block IR Repeater for about 1 second
	Slim::Utils::Timers::killTimers( $client, \&unblockIRRepeater);
	$iBlockIRRepeater{$client} = 1;
	Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + 1.0, \&unblockIRRepeater);

	Slim::Utils::Timers::killTimers( $client, \&handleVolumeDownCallback); 
	$classPlugin->IRBlastSend( $client,
		$prefs->client($client)->get('volumedown_remote')->[$i],
		$prefs->client($client)->get('volumedown_command')->[$i]);
	$i++;
	if( $prefs->client($client)->get('volumedown_count') > $i) {
		Slim::Utils::Timers::setTimer( $client,
			Time::HiRes::time() + $prefs->client($client)->get('volumedown_delay')->[$i],
			\&handleVolumeDownCallback,
			( $i));
	}
}

# ----------------------------------------------------------------------------
# IR Blaster: Check if any volume commands are defined for client
# ----------------------------------------------------------------------------
sub checkVolumeCommandAssigned {
	my $class = shift;
	my $client = shift;

	my $atLeastOneUpCommand = 0;
	for( my $i = 0; $i < $prefs->client($client)->get('volumeup_count'); $i++) {
		if( $prefs->client($client)->get('volumeup_remote')->[$i] ne "-1") {
			$atLeastOneUpCommand = 1;
			last;
		}
	}
	my $atLeastOneDownCommand = 0;
	for( my $i = 0; $i < $prefs->client($client)->get('volumedown_count'); $i++) {
		if( $prefs->client($client)->get('volumedown_remote')->[$i] ne "-1") {
			$atLeastOneDownCommand = 1;
			last;
		}
	}
	if( ( $atLeastOneUpCommand == 1) || ( $atLeastOneDownCommand == 1)) {
		return 1;
	}
	return 0;
}

# ----------------------------------------------------------------------------
# IR Repeater: turn on / off and ask player to send more codes
#
# This function needs to be called as class member function, i.e. first parameter is reference to class
# ----------------------------------------------------------------------------
sub switchIRRepeaterStatus {
	my $class = shift;
	my $client = shift;
	my $status = shift;
	
	if( $status eq "on") {
		# Check if function is available
		if( UNIVERSAL::can( "Slim::Networking::Slimproto","setCallbackRAWI")) {
			Slim::Networking::Slimproto::setCallbackRAWI( \&RAWICallbackIRRepeat);
		}
	}
	if( $status eq "off") {
		# Check if function is available
		if( UNIVERSAL::can( "Slim::Networking::Slimproto","clearCallbackRAWI")) {
			Slim::Networking::Slimproto::clearCallbackRAWI( \&RAWICallbackIRRepeat);
		}
	}
	if( ( $status eq "on") || ( $status eq "more")) {
		# Ask SB2/SB3 or Transporter to send 10 ir codes (containing x samples)
		my $num_codes = pack( 'C', 10);
		$client->sendFrame( 'ilrn', \$num_codes);
	}
}	

# ----------------------------------------------------------------------------
# IR Repeater: unblock
# ----------------------------------------------------------------------------
sub unblockIRRepeater {
	my $client = shift;

	$iBlockIRRepeater{$client} = 0;

	if( $prefs->client($client)->get( 'repeater') eq "on") {
		$classPlugin->switchIRRepeaterStatus( $client, "more");
	}
}

# ----------------------------------------------------------------------------
# IR Repeater: get codes and resend them
# ----------------------------------------------------------------------------
sub RAWICallbackIRRepeat {
	my $client = shift;
	my $data = shift;
	my $high = 0;
	my $low = 0;
	my $MODULATION = 1000000 / 38400;
	my $ircode = "";
	my $mask = "n";
	my $gap = 0;
	my $istooshort = 0;	# Bug 9611
	
	if( $iBlockIRRepeater{$client} eq 1) {
		return;
	}

	$log->debug( "*** IR-Repeater: \n");
	
	$classPlugin->switchIRRepeaterStatus( $client, "more");

	# Get first sample (gap), will be used as gap at the end
	$gap = unpack( $mask, $data);
	# Firmware divides values by 25 to fit into 16 bits
	# 25 is about the modulation used in IR blasting (1000000 / 38400 = 26.042)
	$gap = $gap * 25;			
	# Limit gap to 20000 (might be much longer if no button was pressed for a long time)
	if( $gap > 20000) {
		$gap = 20000;
	}
	# Shift mask by 2 bytes
	$mask = "xx" . $mask;

	for( my $i = 1; $i < (length($data)/2/2); $i++) {
		# Get high-time
		$high = unpack( $mask, $data);

		# Firmware divides values by 25 to fit into 16 bits
		# 25 is about the modulation used in IR blasting (1000000 / 38400 = 26.042)
		$high = $high * 25;

		# Bug 9611: ignore pulses with length < 50
		if( $high < 50) {
			$istooshort = 1;
		}

		$log->debug( "*** IR-Repeater: " . $high . "\n");

		# Shift mask by 2 bytes
		$mask = "xx" . $mask;

		# Get low-time
		$low = unpack( $mask, $data);
		# Firmware divides values by 25 to fit into 16 bits
		# 25 is about the modulation used in IR blasting (1000000 / 38400 = 26.042)
		$low = $low * 25;

		# Bug 9611: ignore pulses with length < 50
		if( $low < 50) {
			$istooshort = 1;
		}

		$log->debug( "*** IR-Repeater: " . $low . "\n");

		# Shift mask by 2 bytes
		$mask = "xx" . $mask;

		# Add pulse to command
		$ircode .= IRBlastPulse( $high, $low, $MODULATION);
	}
	# Get last high-time
	$high = unpack( $mask, $data);
	# Firmware divides values by 25 to fit into 16 bits
	# 25 is about the modulation used in IR blasting (1000000 / 38400 = 26.042)
	$high = $high * 25;

	# Bug 9611: ignore pulses with length < 50
	if( $high < 50) {
		$istooshort = 1;
	}

	$log->debug( "*** IR-Repeater: " . $gap . "\n");

	# Add gap to command
	$ircode .= IRBlastPulse( $high, $gap, $MODULATION);
	# Blast (repeat) command

# This route leads to overlapping, overtaking commands
#	Slim::Utils::Timers::setTimer( $client, Time::HiRes::time() + 0.1, \&IRBlastSendCallback, (\$ircode));

	# Bug 9611: ignore pulses with length < 50
	if( $istooshort == 1) {
		$log->debug( "*** IR-Repeater: Skipping burst with too short pulses\n");
	} else {
		&IRBlastSendCallback( $client, \$ircode);
	}
}

# ----------------------------------------------------------------------------
# IR Repeater:
#
# - Turn on IR Repeater functionality regularily. Player might have been reset or
#    SqueezeCenter might have been restarted.
# - Init IR Repeater blocking state
#
# IR Blaster:
#
# Get current power state (needed for internal tracking)
#
# -----------------------------------------------------------------------------
# If SqueezeCenter supports 'client new' and 'client reconnect' this polling function is
#  not needed anymore and the timer will be killed

my $repeatCheckInterval = 10;

# ----------------------------------------------------------------------------
sub repeatCheckConnectedPlayers {
	Slim::Utils::Timers::killTimers( 47114711, \&repeatCheckConnectedPlayers);
	
	my @playerItems = Slim::Player::Client::clients();

	foreach my $player (@playerItems) {

		$log->debug( "*** IR-Repeater: Player: " . $player->name() . "  Connected: " . $player->connected() . "\n");

		if( $player->connected() && $player->isa( "Slim::Player::Squeezebox2") ) {

			reInitializePlayer( $player);

		}
	}
		
	Slim::Utils::Timers::setTimer( 47114711, (Time::HiRes::time() + $repeatCheckInterval), \&repeatCheckConnectedPlayers);
}

# ----------------------------------------------------------------------------
# IR Repeater:
#
# - Turn on IR Repeater functionality if a player reconnects.
# - Init IR Repeater blocking state
#
# IR Blaster:
#
# - Get current power state (needed for internal tracking)
# ----------------------------------------------------------------------------
sub reInitializePlayer {
	my $client = shift;
	
	if( !defined( $client)) {
		return;
	}
	
	if( $prefs->client($client)->get( 'repeater') eq "on") {
		$classPlugin->switchIRRepeaterStatus( $client, "on");
	}
			
	# Get current power state (needed for internal tracking)
	if( !defined( $iOldPowerState{$client})) {
		$iOldPowerState{$client} = $client->power();
	}
	# Initialize IR Repeater blocking
	if( !defined( $iBlockIRRepeater{$client})) {
		$iBlockIRRepeater{$client} = 0;
	}
}

## ----------------------------------------------------------------------------
## IR Blaster:
## ----------------------------------------------------------------------------
#sub addGroup {
#	return 'PLUGINS';
#}

1;

__END__

