package Plugins::CapriceRadio::Settings;

# Plugin to stream audio from Caprice Radio channels
#
# Released under the MIT Licence
# Written by Daniel Vijge
# See file LICENSE for full licence details

use strict;
use base qw(Slim::Web::Settings);

use Slim::Utils::Strings qw(string);
use Slim::Utils::Prefs;
use Slim::Utils::Log;

my $log   = logger('plugin.capriceradio');
my $prefs = preferences('plugin.capriceradio');
$prefs->init({ menuLocation => 'radio', orderBy => 'popular', groupByGenre => 0, streamingQuality => 'highest:aac', descriptionInTitle => 0, secondLineText => 'description' });

# Returns the name of the plugin. The real 
# string is specified in the strings.txt file.
sub name {
    return 'PLUGIN_CAPRICERADIO';
}

sub page {
    return 'plugins/CapriceRadio/settings/basic.html';
}

sub prefs {
    return (preferences('plugin.capriceradio'), qw(menuLocation orderBy groupByGenre streamingQuality descriptionInTitle secondLineText));
}

# Always end with a 1 to make Perl happy
1;
