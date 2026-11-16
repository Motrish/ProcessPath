package Kernel::System::ProcessPath::Visibility;

use strict;
use warnings;

# A pure helper so the widget can check the allowlist before fetching any
# process definition, activity names, or ticket history.
sub IsAllowed {
    my ( $Self, %Param ) = @_;

    my $ProcessID = $Param{ProcessID} // '';
    my $Choices   = $Param{VisibleProcesses};

    return 0 if !$ProcessID;
    return 0 if ref $Choices ne 'ARRAY';

    for my $Option ( @{$Choices} ) {
        next if !defined $Option || ref $Option;

        # Default setting: do not change existing installed behaviour.
        return 1 if $Option eq 'All processes (*)';

        # Accept either the direct stable entity ID (manual configs) or the
        # standard SysConfig dropdown label 'Process Name [Process-ID]'.
        return 1 if $Option eq $ProcessID;
        if ( $Option =~ / \[([^\[\]]+)\]\z/ ) {
            return 1 if $1 eq $ProcessID;
        }
    }

    return 0;
}

1;
