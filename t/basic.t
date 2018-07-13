use strict;
use warnings;

use Test::More;

use IcyData::Heatmap;

subtest "checking default values" => sub {
    my $map = IcyData::Heatmap->new;

    is $map->$_ => 100, $_ for qw/ width height /;

    is $map->quality => 0, "default quality is no quality at all ^.^";
};

done_testing;
