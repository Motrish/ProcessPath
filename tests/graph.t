use strict;
use warnings;
use utf8;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../Kernel/System/ProcessPath/../../..";
use Kernel::System::ProcessPath::Graph;

my $Graph = 'Kernel::System::ProcessPath::Graph';
my $Process = {
    Name => 'Notebook',
    StartActivity => 'A1',
    Path => {
        A1 => { T1 => { ActivityEntityID => 'A2' } },
        A2 => { T2 => { ActivityEntityID => 'A3' }, T3 => { ActivityEntityID => 'A4' } },
        A3 => { T4 => { ActivityEntityID => 'A5' }, T5 => { ActivityEntityID => 'A2' } },
        A4 => { T6 => { ActivityEntityID => 'A5' } },
    },
};
my %Names = map { $_ => "Activity $_" } qw(A1 A2 A3 A4 A5);
my $History = [
    { HistoryType => 'TicketDynamicFieldUpdate', Name => '%%FieldName%%ProcessManagementProcessID%%Value%%P1%%OldValue%%' },
    { HistoryType => 'TicketDynamicFieldUpdate', Name => '%%FieldName%%ProcessManagementActivityID%%Value%%A1%%OldValue%%' },
    { HistoryType => 'TicketDynamicFieldUpdate', Name => '%%FieldName%%ProcessManagementActivityID%%Value%%A2%%OldValue%%A1' },
    { HistoryType => 'TicketDynamicFieldUpdate', Name => '%%FieldName%%ProcessManagementActivityID%%Value%%A3%%OldValue%%A2' },
];
my %Arg = (History=>$History, ProcessField=>'ProcessManagementProcessID', ActivityField=>'ProcessManagementActivityID', ProcessID=>'P1');
my $Steps = $Graph->HistorySteps(%Arg, ActivityID => 'A3');
is_deeply($Steps, [qw(A1 A2 A3)], 'Correct history sequence');
my $Layout = $Graph->Build(Process=>$Process,Names=>\%Names,ActivityID=>'A3',HistorySteps=>$Steps);
ok($Layout, 'Graph generated');
is(scalar @{ $Layout->{Nodes} },5,'All branch and merge nodes are shown');
is(scalar @{ $Layout->{Edges} },6,'All graph edges including cycle are included');
ok(!$Layout->{Completed},'Active step with outgoing transitions is not complete');
my %States = map { $_->{ID} => $_->{State} } @{ $Layout->{Nodes} };
is($States{A1},'completed','Past A1 completed');
is($States{A2},'completed','Past A2 completed');
is($States{A3},'current','A3 highlighted current');
is($States{A4},'pending','Other branch pending');
is($States{A5},'pending','Terminal step not yet visited');
is(scalar(grep { $_->{Traversed} } @{ $Layout->{Edges} }),2,'Only observed edges are green');
my $Final = $Graph->Build(Process=>$Process, Names=>\%Names, ActivityID=>'A5',HistorySteps=>[qw(A1 A2 A3 A5)]);
ok($Final->{Completed},'Terminal activity closes process path');
my %FinalStates = map { $_->{ID} => $_->{State} } @{ $Final->{Nodes} };
is($FinalStates{A5},'completed','Final activity gets green check');
is($FinalStates{A4},'pending','Alternative branch still pending');
my $Cycle = $Graph->Build(Process=>$Process,Names=>\%Names,ActivityID=>'A2',HistorySteps=>[qw(A1 A2 A3 A2)]);
is(scalar @{ $Cycle->{Nodes} },5,'Cycle does not duplicate nodes');
is(scalar(grep { $_->{Traversed} } @{ $Cycle->{Edges} }),3,'Cycle transitions correctly highlighted');
my $NewHistory = [
    @{$History},
    { HistoryType=>'TicketDynamicFieldUpdate',Name=>'%%FieldName%%ProcessManagementProcessID%%Value%%P2%%OldValue%%P1' },
    { HistoryType=>'TicketDynamicFieldUpdate',Name=>'%%FieldName%%ProcessManagementActivityID%%Value%%B1%%OldValue%%A3' },
    { HistoryType=>'TicketDynamicFieldUpdate',Name=>'%%FieldName%%ProcessManagementProcessID%%Value%%P1%%OldValue%%P2' },
    { HistoryType=>'TicketDynamicFieldUpdate',Name=>'%%FieldName%%ProcessManagementActivityID%%Value%%A2%%OldValue%%B1' },
];
is_deeply($Graph->HistorySteps(%Arg,History=>$NewHistory,ActivityID=>'A2'),['A2'],'Old process runs are not green after new assignment');
is_deeply($Graph->HistorySteps(%Arg,History=>[],ActivityID=>'A2'),['A2'],'Current activity alone is enough to render');
my $Empty = $Graph->Build(Process=>$Process,Names=>\%Names,ActivityID=>'Bad',HistorySteps=>[]);
ok(!defined $Empty,'Invalid current activity yields no graph');

my $OrphanProcess = { StartActivity=>'A1', Path=>{ A1=>{T1=>{ActivityEntityID=>'A2'}}, A9=>{} } };
my $Orphan = $Graph->Build(Process=>$OrphanProcess,Names=>\%Names,ActivityID=>'A9',HistorySteps=>['A9']);
ok(!$Orphan->{Completed},'Unreachable orphan activity not treated as completed');


# Full labels must wrap without ellipses; height grows for more than two lines.
my %LongNames = %Names;
$LongNames{A2} = 'Freigabe der Notebookausgabe';
$LongNames{A3} = 'Pruefung und Dokumentation der Ausgabe und Rueckgabe';
$LongNames{A4} = 'AussergewoehnlichLangesEinzelwortOhneLeerzeichen';
my $LongGraph = $Graph->Build(Process=>$Process,Names=>\%LongNames,ActivityID=>'A3',HistorySteps=>[qw(A1 A2 A3)]);
my %LongNode = map { $_->{ID} => $_ } @{ $LongGraph->{Nodes} };
is(scalar @{ $LongNode{A2}->{Lines} }, 2, 'Two-line activity title is fully wrapped');
is(join(' ', @{ $LongNode{A2}->{Lines} }), $LongNames{A2}, 'Two lines preserve whole activity title');
ok(scalar @{ $LongNode{A3}->{Lines} } > 2, 'Titles beyond two lines remain visible');
is(join(' ', @{ $LongNode{A3}->{Lines} }), $LongNames{A3}, 'Long title preserved without truncation');
is(join('', @{ $LongNode{A4}->{Lines} }), $LongNames{A4}, 'Single very long word is not truncated');
like(join('', map { join('', @{ $_->{Lines} }) } @{ $LongGraph->{Nodes} }), qr/EinzelwortOhneLeerzeichen/, 'No ellipsis hides long words');
ok($LongNode{A3}->{H} > 82, 'Node grows vertically when additional lines are needed');
my $BottomNameLine = 25 + 16 * (scalar @{ $LongNode{A3}->{Lines} } - 1);
ok($BottomNameLine < $LongNode{A3}->{H} - 18, 'Last label line does not overlap status marker');

done_testing();
