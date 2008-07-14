package Plugins::I2C::PlayerSettings;

# Copyright 2008 Lars Immisch <lars@ibp.de>
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;
use base qw(Slim::Web::Settings);

use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Plugins::I2C::Plugin;

my $prefs = preferences('plugin.i2c');
my $log   = logger('plugin.i2c');

sub name {
	return 'PLUGIN_I2C_NAME';
}

sub needsClient {
	return 1;
}

sub page {
	return Slim::Web::HTTP::protectURI('plugins/I2C/settings/player.html');
}

sub handler {
	my ($class, $client, $params) = @_;
	
	if ( $client ) {
		my @command = Plugins::I2C::Plugin::readIOCommand($client);

		$log->debug("player: " . $client->id . " commands: @command");
	
		# Extract the long description
		my @desc = ();
		for my $i (0 .. $#Plugins::I2C::Plugin::Commands) {
			push(@desc, $Plugins::I2C::Plugin::Commands[$i][1]);
		}
		  
		$params->{prefs}->{command} = \@command;
		$params->{prefs}->{desc} = \@desc;
		  
		if ( $params->{saveSettings} ) {
			@command = ();
			for my $i (0 .. 7) {
				my $io = "io$i";
				push(@command, $params->{$io} || 0);
			}
			Plugins::I2C::Plugin::writeIOCommand($client, @command);
		}
	}
	
	return $class->SUPER::handler( $client, $params );
}

1;
