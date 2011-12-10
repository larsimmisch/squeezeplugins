# IRBlaster::LearningXML.pm
package Plugins::IRBlaster::LearningXML;

# SqueezeCenter Copyright (c) 2001-2008 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License, 
# version 2.

use strict;
use base qw(Slim::Web::Settings);

use Slim::Utils::Strings qw(string);
use Slim::Utils::Log;

# ----------------------------------------------------------------------------
# References to other classes
my $classPlugin = undef;
my $classLearning = undef;

# ----------------------------------------------------------------------------
my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.irblaster',
	'defaultLevel' => 'OFF',
	'description'  => 'PLUGIN_IRBLASTER_MODULE_NAME',
});

# ----------------------------------------------------------------------------
# Define own constructor
# - to save references to Plugin.pm and Learning.pm
# - to prevent entry in settings dropdown
# ----------------------------------------------------------------------------
sub new {
	my $class = shift;

	$classPlugin = shift;
	$classLearning = shift;

	$log->debug( "*** IRBlaster::LearningXML::new() " . $classPlugin . "\n");
	$log->debug( "*** IRBlaster::LearningXML::new() " . $classLearning . "\n");

	if ($class->can('page') && $class->can('handler')) {
		Slim::Web::Pages->addPageFunction($class->page, $class);

	}

	# Do not call parent class to prevent entry in settings dropdown
	#$class->SUPER::new();

	return $class;
}

# ----------------------------------------------------------------------------
# Webpage served for ajax callback
# ----------------------------------------------------------------------------
sub page {
	return 'plugins/IRBlaster/learncode.xml';
}

# ----------------------------------------------------------------------------
# IR Learning: wave-form
# ----------------------------------------------------------------------------
sub handler {
	my ($class, $client, $params) = @_;
	
#	my $learnCode = Plugins::IRBlaster::Learning::getLearnCode();
	my $learnCode = $classLearning->getLearnCode();
	
	# IE cannot handle empty xml values
	if( $learnCode eq "") {
		$params->{'learncode'} = ".\n";
	} else {
		$params->{'learncode'} = $learnCode;
	}

	return $class->SUPER::handler($client, $params);
}


1;

__END__

