package Kernel::Output::HTML::TicketZoom::ProcessPath;

use strict;
use warnings;
use utf8;

use parent 'Kernel::Output::HTML::Base';
use Kernel::System::ProcessPath::Graph;
use Kernel::System::ProcessPath::Visibility;

our $ObjectManagerDisabled = 1;

sub Run {
    my ( $Self, %Param ) = @_;

    my $Ticket = $Param{Ticket};
    return if ref $Ticket ne 'HASH' || !$Ticket->{TicketID};

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $ProcessField = $ConfigObject->Get('Process::DynamicFieldProcessManagementProcessID');
    my $ActivityField = $ConfigObject->Get('Process::DynamicFieldProcessManagementActivityID');
    return if !$ProcessField || !$ActivityField;

    my $ProcessID  = $Ticket->{ 'DynamicField_' . $ProcessField }  // '';
    my $ActivityID = $Ticket->{ 'DynamicField_' . $ActivityField } // '';

    # The TicketZoom data usually has the dynamic fields. Provide an explicit fallback.
    if ( !$ProcessID || !$ActivityID ) {
        my %FullTicket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
            TicketID      => $Ticket->{TicketID},
            DynamicFields => 1,
            UserID        => $Self->{UserID},
        );
        $ProcessID  = $FullTicket{ 'DynamicField_' . $ProcessField }  // '';
        $ActivityID = $FullTicket{ 'DynamicField_' . $ActivityField } // '';
    }
    return if !$ProcessID || !$ActivityID;

    # Check scope before loading process definitions and complete ticket history.
    return if !Kernel::System::ProcessPath::Visibility->IsAllowed(
        ProcessID        => $ProcessID,
        VisibleProcesses => $ConfigObject->Get('ProcessPath::VisibleProcesses'),
    );

    my $Graph = eval {
        my $ProcessObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::Process');
        my $Process = $ProcessObject->ProcessGet( ProcessEntityID => $ProcessID );
        die "Missing process definition for $ProcessID" if ref $Process ne 'HASH';

        my %IDs;
        $IDs{ $Process->{StartActivity} } = 1 if $Process->{StartActivity};
        my $Paths = $Process->{Path} || {};
        if ( ref $Paths eq 'HASH' ) {
            for my $From ( keys %{$Paths} ) {
                $IDs{$From} = 1;
                next if ref $Paths->{$From} ne 'HASH';
                for my $Transition ( values %{ $Paths->{$From} } ) {
                    next if ref $Transition ne 'HASH' || !$Transition->{ActivityEntityID};
                    $IDs{ $Transition->{ActivityEntityID} } = 1;
                }
            }
        }

        my $ActivityObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::Activity');
        my %Names;
        for my $ID ( sort keys %IDs ) {
            my $Activity = $ActivityObject->ActivityGet(
                ActivityEntityID => $ID,
                Interface        => 'all',
            );
            $Names{$ID} = ref $Activity eq 'HASH' ? ( $Activity->{Name} || $ID ) : $ID;
        }

        my @History = $Kernel::OM->Get('Kernel::System::Ticket')->HistoryGet(
            TicketID => $Ticket->{TicketID},
            UserID   => $Self->{UserID},
        );
        my $Steps = Kernel::System::ProcessPath::Graph->HistorySteps(
            History       => \@History,
            ProcessField  => $ProcessField,
            ActivityField => $ActivityField,
            ProcessID     => $ProcessID,
            ActivityID    => $ActivityID,
        );

        Kernel::System::ProcessPath::Graph->Build(
            Process      => $Process,
            Names        => \%Names,
            ActivityID   => $ActivityID,
            HistorySteps => $Steps,
        );
    };

    if ($@) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "ProcessPath widget failed for TicketID $Ticket->{TicketID}: $@",
        );
        return;
    }
    return if !$Graph;

    my $Output = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->Output(
        TemplateFile => 'AgentTicketZoom/ProcessPath',
        Data         => $Graph,
    );
    return if !$Output;

    return {
        Location => 'Main',
        Output   => $Output,
        Rank     => '0050',
    };
}

1;
