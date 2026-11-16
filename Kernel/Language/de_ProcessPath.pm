package Kernel::Language::de_ProcessPath;

use strict;
use warnings;
use utf8;

sub Data {
    my $Self = shift;
    $Self->{Translation}->{'All processes (*)'} = 'Alle Prozesse (*)';
    $Self->{Translation}->{q{Select the processes that display the ProcessPath widget in AgentTicketZoom. Remove 'All processes' to restrict the widget to the listed processes. An empty list disables ProcessPath for every process.}} = 'Legt fest, bei welchen Prozessen der Prozesspfad in AgentTicketZoom angezeigt wird. Entfernen Sie Alle Prozesse, um nur die ausgewählten Prozesse zuzulassen. Ohne Eintrag wird das Widget bei keinem Prozess angezeigt.';
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
