package IcyData::Heatmap;

# YANICK SAYS:
# The module can be used outside of `IcyData`, so I would suggest 
# to name it `GD::Heatmap`. Likewise, the repo itself should be 
# name perl-gd-heatmap or gd-heatmap 

# YANICK SAYS:
# The module must have documentation. At the minimum, it should look like: 

=head1 NAME

GD::Heatmap - generate a heatmap image off a dataset

=head1 SYNOPSIS

    use GD::Heatmap;

    my $heatmap = GD::Heatmap->new(
        data => \@dataset,
        gradient_file => './foo',
    );

    $heatmap->save( 'heatmap.png' );

=head1 DESCRIPTION 

This module does blah blah blah blah...

=cut


use File::Temp qw/ tempfile tempdir /;
use GD;
use Moo;
use Path::Tiny;
use namespace::clean;
use strictures 2;
use Data::Dump qw/dump/;

has radius => (
    is      => 'ro',
    default => 15
);

# YANICK SAYS: 
#   the usual convention in Perl is to 
#   use snake_case. So that would be `gradient_file`.
has gradientFile => (
    is       => 'ro',
    init_arg => undef,
    default  => 'gradient.png'
);

has points => (
    is       => 'ro',
    init_arg => undef,
    builder  => '_build_points'
);

has gradients => (
    is       => 'ro',
    init_arg => undef,
    builder  => '_build_gradients'
);

has gradientColors => (
    is      => 'ro',
    default => qw/ blue green yellow red white/
);

has backgroundImg => (
    is      => 'ro',
);

has width => (
    is      => 'ro',
    default => 100
);

has height => (
    is      => 'ro',
    default => 100
);

has quality => (
    is      => 'ro',
    default => 0
);

sub _build_gradient_image {
    my $self = shift;

    my $gradient = GD::Image->new(256, 1);
    my $white = $gradient->colorAllocate(255, 255, 255);
    $gradient->transparent($white);
    $gradient->alphaBlending(0);
    $gradient->saveAlpha(1);

    my %blue = ('red' => 0, 'green' => 0, 'blue' => 255);
    my %green = ('red' => 0, 'green' => 255, 'blue' => 0);
    my %yellow = ('red' => 255, 'green' => 255, 'blue' => 0);
    my %red = ('red' => 255, 'green' => 0, 'blue' => 0);
    my %white = ('red' => 255, 'green' => 255, 'blue' => 255);

    my @transitions = (
        {
            'start'       => 0,
            'end'         => 128,
            'startColour' => \%blue,
            'endColour'   => \%green,
        },
        {
            'start'       => 128,
            'end'         => 192,
            'startColour' => \%green,
            'endColour'   => \%yellow
        },
        {
            'start'       => 192,
            'end'         => 240,
            'startColour' => \%yellow,
            'endColour'   => \%red
        },
        {
            'start'       => 240,
            'end'         => 255,
            'startColour' => \%red,
            'endColour'   => \%white
        }
    );

    foreach my $transition (@transitions) {
        my $start     = $transition->{'start'};
        my $end       = $transition->{'end'};
        my $steps     = $end - $start;
        my $colourOne = $transition->{'startColour'};
        my $colourTwo = $transition->{'endColour'};

        for my $i (0 .. $steps) {
            my $t = $i / $steps;
            my $r = $colourTwo->{'red'} * $t + $colourOne->{'red'} * (1 - $t);
            my $g = $colourTwo->{'green'} * $t + $colourOne->{'green'} * (1 - $t);
            my $b = $colourTwo->{'blue'} * $t + $colourOne->{'blue'} * (1 - $t);
            my $a = 127 - (($i + $start) / 255 * 127);

            $gradient->setPixel($i + $start, 0, $gradient->colorAllocateAlpha($r, $g, $b, $a));

            push @{$self->gradients}, {
                'red'   => $r,
                'green' => $g,
                'blue'  => $b,
                'alpha' => $a
            };
        }
    }

    open my $fh, '>', $self->gradientFile;
    print $fh $gradient->png;
}

sub _build_points {
    my @points = ();
    return \@points;
}

sub _build_gradients {
    my @gradients = ();
    return \@gradients;
}

sub _build_alpha {
    my $self = shift;

    my $alpha = GD::Image->newTrueColor($self->width, $self->height);
    my $white = $alpha->colorAllocate(255, 255, 255);
    $alpha->filledRectangle(0, 0, $self->width - 1, $self->height - 1, $white);

    my $black = $alpha->colorAllocateAlpha(0, 0, 0, 127 * 0.92);

    foreach my $point (@{$self->points}) {
        for my $r (0 .. $self->radius - 1) {
            $alpha->filledEllipse($point->{'x'}, $point->{'y'}, $self->radius - $r, $self->radius - $r, $black);
        }
    }

    $alpha->gaussianBlur();
    return $alpha;
}

sub _build_heatmap {
    my ($self, $alpha) = @_;

    my $heatmap = GD::Image->newTrueColor(100, 100);
    my $white = $heatmap->colorAllocate(255, 255, 255);
    $heatmap->filledRectangle(0, 0, 99, 99, $white);

    my @gradients = @{$self->gradients};

    for my $x (0 .. $self->width - 1) {
        for my $y (0 .. $self->height - 1) {
            my $index = $alpha->getPixel($x, $y);
            my ($r, $g, $b) = $alpha->rgb($index);

            if ($r == 255 && $g == 255 && $b == 255) {
                next;
            }

            my $gradient = $gradients[255 - $r];

            my $colour = $heatmap->colorAllocateAlpha($gradient->{'red'}, $gradient->{'green'}, $gradient->{'blue'}, $gradient->{'alpha'});
            $heatmap->setPixel($x, $y, $colour);
        }
    }

    return $heatmap;
}

sub add_point {
    my ($self, %point) = @_;
    push @{ $self->points }, \%point;
}

sub save {
    my ($self, $file) = @_;

    $self->_build_gradient_image;
    my $alpha   = $self->_build_alpha;
    my $heatmap = $self->_build_heatmap($alpha);

    $file = path($file);
    $file->spew($heatmap->png($self->quality));
}

1;
