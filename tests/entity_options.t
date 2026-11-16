use strict;
use warnings;
use utf8;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/..";

BEGIN {
    $INC{'Kernel/System/SysConfig/ValueType/Entity.pm'} = 1;
    package Kernel::System::SysConfig::ValueType::Entity;
    sub new { return bless {}, shift; }
}

{
    package ProcessPathTest::OM;
    sub Get {
        my ( $Self, $Name ) = @_;
        return bless {}, 'ProcessPathTest::Processes'
            if $Name eq 'Kernel::System::ProcessManagement::Process';
        return bless {}, 'ProcessPathTest::Config'
            if $Name eq 'Kernel::Config';
        die "Unexpected object: $Name";
    }

    package ProcessPathTest::Processes;
    sub ProcessList {
        my ( $Self, %Param ) = @_;
        die 'Inactive processes omitted'
            unless grep { $_ eq 'Inactive' } @{ $Param{ProcessState} };
        return {
            'Process-123' => 'Notebookausgabe',
            'Process-456' => 'Gerätebereitstellung',
        };
    }

    package ProcessPathTest::Config;
    sub Get {
        my ( $Self, $Key ) = @_;
        return [ 'All processes (*)', 'Alter Prozessname [Process-456]' ]
            if $Key eq 'ProcessPath::VisibleProcesses';
        return;
    }
}

$Kernel::OM = bless {}, 'ProcessPathTest::OM';
require Kernel::System::SysConfig::ValueType::Entity::ProcessPathProcess;
my $Selector = Kernel::System::SysConfig::ValueType::Entity::ProcessPathProcess->new();
my @Values = $Selector->EntityValueList();
ok( grep( { $_ eq 'All processes (*)' } @Values ), 'Default option is selectable' );
ok( grep( { $_ eq 'Notebookausgabe [Process-123]' } @Values ), 'Active process offered by name and stable ID' );
ok( grep( { $_ eq 'Gerätebereitstellung [Process-456]' } @Values ), 'Other configured process offered' );
ok( grep( { $_ eq 'Alter Prozessname [Process-456]' } @Values ), 'Old saved option preserved after rename' );
is( scalar(grep { $_ eq 'All processes (*)' } @Values), 1, 'Existing default is not duplicated' );
is( scalar @Values, 4, 'All configured and saved choices enumerated' );

done_testing();
