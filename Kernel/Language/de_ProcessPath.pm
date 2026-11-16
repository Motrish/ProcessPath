package Kernel::Language::de_ProcessPath;

use strict;
use warnings;
use utf8;

sub Data {
    my $Self = shift;
    $Self->{Translation}->{'Process path'}      = 'Prozessverlauf';
    $Self->{Translation}->{'Process graph'}     = 'Prozessdiagramm';
    $Self->{Translation}->{'Process completed'} = 'Prozess abgeschlossen';
    $Self->{Translation}->{'Current activity'}  = 'Aktuelle Aktivität';
    $Self->{Translation}->{'Current'}           = 'Aktuell';
    $Self->{Translation}->{'Visited'}           = 'Durchlaufen';
    $Self->{Translation}->{'Not visited'}       = 'Nicht durchlaufen';
    return 1;
}

1;
