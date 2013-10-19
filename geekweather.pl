#!/usr/bin/perl -w

use strict;

use Config::Tiny;
use FindBin;
use Forecast::IO;
use POSIX qw( strftime );
use Tie::Hash::Indexed;

my $config = Config::Tiny->read( $ENV{HOME} . '/.geekweather.conf' );
my $key = $config->{_}->{apikey};
my $lat = $config->{_}->{latitude};
my $long = $config->{_}->{longitude};

my $weekday_times_re = qr/^\s*(?:(?:9|10|11)AM|(?:[678]PM))/;
my $weekend_times_re = qr/^\s*(?:9AM|1[01]AM|12PM|[123456789]PM)/;
my $weekend_re = qr/^(?:Sat|Sun)$/;
my $iconfile = 'current.png';
my $pad = ' ' x 15;

chdir $FindBin::RealBin;

my $forecast = Forecast::IO->new(
                key => $key,
                latitude => $lat,
                longitude => $long,
            );

my $conditions = {};
$conditions->{present} = $forecast->{currently}->{summary};
$conditions->{temperature} = $forecast->{currently}->{temperature};
$conditions->{icon} = $forecast->{currently}->{icon};
$conditions->{day} = $forecast->{hourly}->{summary};

foreach my $hour (@{ $forecast->{hourly}->{data} }) {
    if ($hour->{precipProbability} > 0.1) {
        my $t = $hour->{time};
        $conditions->{'day-rain'}->{$t} = $hour->{precipProbability};
    }
}

$conditions->{week} = $forecast->{daily}->{summary};

foreach my $day (@{ $forecast->{daily}->{data} }) {
    if ($day->{precipProbability} > 0) {
        my $t = $day->{time};
        $conditions->{'week-rain'}->{$t} = $day->{precipProbability};
    }
}

sub init_day {
    tie my %day, 'Tie::Hash::Indexed';
    %day = (
        ' 9AM' => [ '.', ' ' ],
        '10AM' => [ '.', ' ' ],
        '11AM' => [ '.', ' ' ],
        'NOON' => [ ' | ', '   ' ],
        '12PM' => [ '.', ' ' ],
        ' 1PM' => [ '.', ' ' ],
        ' 2PM' => [ '.', ' ' ],
        ' 3PM' => [ '.', ' ' ],
        ' 4PM' => [ '.', ' ' ],
        ' 5PM' => [ '.', ' ' ],
        ' 6PM' => [ '.', ' ' ],
        ' 7PM' => [ '.', ' ' ],
        ' 8PM' => [ '.', ' ' ],
        ' 9PM' => [ '.', ' ' ],
    );
    return \%day;
}

sub formatted_text($) {
    my $t = shift;
    $t =~ s/;\s+(.)/\n$pad\U$1/g;
    return $t;
}

my %has_rain = ();
tie my %rain, 'Tie::Hash::Indexed';
my $lastday = '';
foreach my $h (sort keys %{ $conditions->{'day-rain'} }) {
    my $day = strftime('%a', localtime($h));
    if ($day ne $lastday) {
        # Initialise table
        $rain{$day} = init_day;
        $lastday = $day;
    }
    my $hour = strftime('%l%p', localtime($h));
    my $filter = ($day =~ $weekend_re ? $weekend_times_re : $weekday_times_re);
    if ($hour =~ $filter) {
        my $perc = $conditions->{'day-rain'}->{$h} * 100;
        my $hstr = sprintf("% 5s ", $hour);
        $perc = sprintf("% 4s%% ", $perc);
        $rain{$day}->{$hour} = [ $hstr, $perc ];
        $has_rain{$day} = 1;
    }
}

my $time_now = time;
my @localtime_now = localtime(time);
my $day = strftime('%a', @localtime_now);
my $tnum_now = strftime('%k%M', @localtime_now);
if ($tnum_now > 2100) {
    $day = strftime('%a', localtime($time_now + (24 * 60 * 60)));
}

my $rightnow = formatted_text($conditions->{present} . ', '
                    . int($conditions->{temperature} + 0.5)) . "\x{B0}";
print "Right Now    : $rightnow\n";
print "Next 24 Hours: ", formatted_text($conditions->{day}), "\n";

if ($has_rain{$day}) {
    print $pad, join('', map { $rain{$day}->{$_}->[0] } keys %{ $rain{$day} }), "\n";
    print $pad, join('', map { $rain{$day}->{$_}->[1] } keys %{ $rain{$day} }), "\n";
}

print "Next 7 Days  : ", formatted_text($conditions->{week}), "\n";

my $icon = $conditions->{icon};
unlink $iconfile;
symlink("icons/${icon}.png", $iconfile);
