package Slim::Plugin::I2C::PlayerSettings;

# Copyright 2008 Lars Immisch <lars@ibp.de>
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;
use Slim::Plugin::I2C::Plugin qw(readIODirection);
use Slim::Plugin::I2C::Plugin qw(writeIODirection);
use Slim::Plugin::I2C::Plugin qw(setupdesc);
use base qw(Slim::Web::Settings);

use Slim::Utils::Log;
use Slim::Utils::Prefs;

my $prefs = preferences('plugin.i2c');
my $log   = logger('plugin.i2c');

my @arrDirection;

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
		readIODirection($client);

		# Extract the long description
		@desc = ();
		for my $i (0 .. $#setupdesc) {
			push(@desc, $setupdesc[$i][1]);
		}

		$params->{prefs}->{direction} = @arrDirection;
		$params->{prefs}->{desc} = @desc;
		
		if ( $params->{saveSettings} ) {
			witeIODirection($client);
		}
	}
	
	return $class->SUPER::handler( $client, $params );
}

1;
