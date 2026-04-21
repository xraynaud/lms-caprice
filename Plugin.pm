package Plugins::Caprice::Plugin;

# Plugin to stream audio from Caprice channels
#
# Released under the MIT Licence
# Written by Daniel Vijge
# See file LICENSE for full licence details

use strict;
use utf8;
use vars qw(@ISA);
use base qw(Slim::Plugin::OPMLBased);
use feature qw(fc);

use JSON::XS::VersionOneAndTwo;

use Slim::Utils::Strings qw(string cstring);
use Slim::Utils::Prefs;
use Slim::Utils::Log;
use Slim::Utils::PluginManager;

my $log;

# Get the data related to this plugin and preset certain variables with 
# default values in case they are not set
my $prefs = preferences('plugin.caprice');
$prefs->init({ menuLocation => 'radio', orderBy => 'title', groupByGenre => 1});

# This is the entry point in the script
BEGIN {
    # Initialize the logging
    $log = Slim::Utils::Log->addLogCategory({
        'category'     => 'plugin.caprice',
        'defaultLevel' => 'ERROR',
        'description'  => string('PLUGIN_CAPRICE'),
    });
}

# This is called when squeezebox server loads the plugin.
# It is used to initialize variables and the like.
sub initPlugin {
    my $class = shift;

    # Initialize the plugin with the given values. The 'feed' is the first
    # method called. The available menu entries will be shown in the new 
    # menu entry 'caprice'.
    $class->SUPER::initPlugin(
        feed   => \&_feedHandler,
        tag    => 'caprice',
        menu   => 'radios',
        is_app => $class->can('nonSNApps') && ($prefs->get('menuLocation') eq 'apps') ? 1 : undef,
        weight => 10,
    );

    if (!$::noweb) {
        require Plugins::Caprice::Settings;
        Plugins::Caprice::Settings->new;
    }
}

# Called when the plugin is stopped
sub shutdownPlugin {
    my $class = shift;
}

# Returns the name to display on the squeezebox
sub getDisplayName { 'PLUGIN_CAPRICE' }

sub playerMenu { undef }

sub _feedHandler {
    my ($client, $callback, $args, $passDict) = @_;

    my $pluginName = 'Caprice';
    my $pluginPath = Slim::Utils::PluginManager->allPlugins->{$pluginName}->{basedir};

    my $filePath = File::Spec->catfile($pluginPath,"capricechannels.json");

    my $menu = [];
    my $fetch;

    $fetch = sub {
        $log->debug("Lecture du fichier $filePath");

        # Read JSON
        open(my $fh, '<', $filePath) or do {
            $log->error("Cannot open file $filePath : $!");
            $callback->([{ name => "Error: Cannot open file $filePath", type => 'text' }]);
            return;
        };

        local $/;  # Mode "slurp" pour lire tout le fichier
        my $json_content = <$fh>;
        close($fh);

        # Décode le JSON
        my $json;
        eval {
            $json = from_json($json_content);
        };

        if ($@) {
            $log->error("Erreur de parsing JSON : $@");
            $callback->([{ name => "Erreur : Format JSON invalide", type => 'text' }]);
            return;
        }

        # Traite les données comme avant
        if ($prefs->get('groupByGenre')) {
            _parseChannelsWithGroupByGenre($client, $json->{'channels'}, $menu);
        }
        else {
            _parseChannels($client, _sortChannels($json->{'channels'}), $menu);
        }

        $callback->({
            items => $menu
        });
    };

    $fetch->();
}

sub _parseChannels {
    my ($client, $channels, $menu) = @_;
    
    for my $channel (@$channels) {
        push @$menu, _parseChannel($channel);
    }

    if (!$prefs->get('groupByGenre')) {
        push @$menu, {
            name => cstring($client, 'PLUGIN_CAPRICE_BY_GENRE'),
            type => 'menu',
            image => 'html/images/genres.png',
            items => [_parseChannelsWithGroupByGenre($client, $channels)]
        };
    }
}

sub _parseChannelsWithGroupByGenre {
    my ($client, $channels, $menu) = @_;

    my %menu_items;

    # Create submenus for each genre.
    # First check if the genre menu doesn't exist yet. If if doesn't,
    # create the menu item and let `items` reference to a (yet) empty
    # array. Then for each genre, parse the channel and add it to the
    # array. As this works by reference it can all be done in one loop.

    for my $channel (@$channels) {
        for my $genre (split('\|', $channel->{'genre'})) {
            if (!exists($menu_items{$genre})) {
                $menu_items{ $genre } = ();
                push @$menu, {
                    name => ucfirst($genre),
                    items => \@{$menu_items{$genre}}
                };
            }
            push @{ $menu_items{ $genre } }, _parseChannel($channel);
        }
    }

    # Sort items within the submenus
    foreach ( @$menu ) {
        $_->{'items'} = _sortChannels($_->{'items'}); 
    }

    # Sort the genres themselves alphabetically
    @$menu = sort { $a->{name} cmp $b->{name} } @$menu;
}

sub _parseChannel {
    my ($channel) = @_;

    return {
        name => _getFirstLineText($channel, 0),
        genre => (join ', ', map ucfirst, split '\|', $channel->{'genre'}), # split genre and capitalise the first letter, so 'ambient|electronic' becomes 'Ambient, Electronic'
        line1 => _getFirstLineText($channel, 1),
        type => 'audio',
        url => _getStream($channel),
        image => $channel->{'image'}
    };
}

sub _getStream {
    my ($channel) = shift;
    my $playlists = $channel->{'playlists'};
    return $playlists->[0]->{'url'};
}

sub _sortChannels {
    my ($channels) = shift;

    my @sorted_channels;
    my $orderBy = $prefs->get('orderBy');

    if ($orderBy eq 'title') {
        # sort alphabetically but case-insensitive
        @sorted_channels = sort { fc($a->{title}) cmp fc($b->{title}) } @$channels;
    }
    else {
        # do not sort, use order as provided in channel feed
        @sorted_channels = @$channels;
    }
    $log->warn("Order by is set to $orderBy");

    return \@sorted_channels;
}

sub _getFirstLineText {
    my ($channel, $isFirstLine) = @_;

    return $channel->{'title'};

}

# Always end with a 1 to make Perl happy
1;
