package Kernel::System::SysConfig::ValueType::Entity::ProcessPathProcess;

use strict;
use warnings;
use utf8;

use parent 'Kernel::System::SysConfig::ValueType::Entity';

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::ProcessManagement::Process',
);

sub new {
    my ($Type) = @_;
    return bless {}, $Type;
}

sub EntityValueList {
    my ($Self, %Param) = @_;

    my $Processes = $Kernel::OM->Get('Kernel::System::ProcessManagement::Process')->ProcessList(
        ProcessState => [ 'Active', 'FadeAway', 'Inactive' ],
        Interface    => 'all',
        Silent       => 1,
    ) || {};

    my @Options = ('All processes (*)');
    if ( ref $Processes eq 'HASH' ) {
        for my $ID (
            sort {
                lc( $Processes->{$a} || $a ) cmp lc( $Processes->{$b} || $b )
                    || $a cmp $b
            } keys %{$Processes}
            )
        {
            my $Name = $Processes->{$ID} || $ID;
            push @Options, "$Name [$ID]";
        }
    }

    # Keep previous selections selectable after a process is renamed or removed
    # from the current process configuration. The ProcessEntityID is stable.
    my $Configured = $Kernel::OM->Get('Kernel::Config')->Get('ProcessPath::VisibleProcesses');
    if ( ref $Configured eq 'ARRAY' ) {
        my %Existing = map { $_ => 1 } @Options;
        for my $OldOption ( @{$Configured} ) {
            next unless defined $OldOption && !ref $OldOption && length $OldOption;
            next if $Existing{$OldOption}++;
            push @Options, $OldOption;
        }
    }

    return @Options;
}

1;
