use strict;
use warnings;
use utf8;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/..";
use Kernel::System::ProcessPath::Graph;

my $G = 'Kernel::System::ProcessPath::Graph';
my $P = { StartActivity => 'A1', Path => {
    A1 => { T1 => { ActivityEntityID => 'A2' } },
    A2 => { T2 => { ActivityEntityID => 'A3' }, T3 => { ActivityEntityID => 'A4' } },
    A3 => { T4 => { ActivityEntityID => 'A5' }, T5 => { ActivityEntityID => 'A2' } },
    A4 => { T6 => { ActivityEntityID => 'A5' } },
}};
my %N = map { $_ => "Activity $_" } qw(A1 A2 A3 A4 A5);
my $L = $G->Build(Process=>$P,Names=>\%N,ActivityID=>'A3',HistorySteps=>[qw(A1 A2 A3)]);
ok($L,'Graph created');
ok(!$L->{Completed},'Active process');
is_deeply([map { $_->{ID} } @{$L->{PastNodes}}],[qw(A1 A2)],'Completed steps in left rail');
is($L->{PastColumns},2,'Two compact rail columns');
is_deeply([sort map { $_->{ID} } @{$L->{Nodes}}],[qw(A3 A5)],'Abandoned branch hidden');
is(scalar @{$L->{Edges}},1,'Only available edge shown');
my %State = map { $_->{ID} => $_->{State} } @{$L->{Nodes}};
is($State{A3},'current','Current blue');
is($State{A5},'pending','Future neutral');
my $Initial = $G->Build(Process=>$P,ActivityID=>'A1',HistorySteps=>['A1']);
is(scalar @{$Initial->{PastNodes}},0,'No completed steps initially');
is(scalar @{$Initial->{Nodes}},5,'All possibilities initially visible');
is(scalar @{$Initial->{Edges}},6,'All initial paths visible');
my $End = $G->Build(Process=>$P,ActivityID=>'A5',HistorySteps=>[qw(A1 A2 A3 A5)]);
ok($End->{Completed},'Terminal step is complete');
is_deeply([map { $_->{ID} } @{$End->{PastNodes}}],[qw(A1 A2 A3 A5)],'Only traversed steps after completion');
is(scalar @{$End->{Nodes}},0,'No future activities after completion');
is($End->{Width},0,'End graph has zero SVG width');
my $Loop = $G->Build(Process=>$P,ActivityID=>'A2',HistorySteps=>[qw(A1 A2 A3 A2)]);
is_deeply([map { $_->{ID} } @{$Loop->{PastNodes}}],[qw(A1 A3)],'Return loop has no duplicate current');
is_deeply([sort map { $_->{ID} } @{$Loop->{Nodes}}],[qw(A2 A4 A5)],'Available branch shown after return');
my %Long = %N;
$Long{A2} = 'Freigabe der Notebookausgabe';
$Long{A3} = 'Pruefung und Dokumentation der Ausgabe und Rueckgabe';
$Long{A5} = 'AussergewoehnlichLangesEinzelwortOhneLeerzeichen';
my $Names = $G->Build(Process=>$P,Names=>\%Long,ActivityID=>'A3',HistorySteps=>[qw(A1 A2 A3)]);
is($Names->{PastNodes}[1]{Name},$Long{A2},'Rotated full label retained');
my %Nodes = map { $_->{ID} => $_ } @{$Names->{Nodes}};
ok(scalar @{$Nodes{A3}{Lines}} > 2,'Long current label wraps');
is(join(' ',@{$Nodes{A3}{Lines}}),$Long{A3},'No word truncation');
is(join('',@{$Nodes{A5}{Lines}}),$Long{A5},'Long single word preserved');
ok($Nodes{A3}{H} > 66,'Future tile height grows');
my $Twenty = {StartActivity=>'A1',Path=>{}};
my @Many = map { 'A'.$_ } (1..20);
for my $i (0..18) { $Twenty->{Path}{$Many[$i]}{'T'.$i} = {ActivityEntityID=>$Many[$i+1]}; }
my $LongGraph = $G->Build(Process=>$Twenty,ActivityID=>'A20',HistorySteps=>\@Many);
is(scalar @{$LongGraph->{PastNodes}},20,'Twenty visited steps retained');
is($LongGraph->{PastColumns},6,'Completed rail limited to six columns');
is($LongGraph->{Width},0,'Long completed graph not wide');
my $Fork = {StartActivity=>'S',Path=>{
    S=>{T1=>{ActivityEntityID=>'Left'},T2=>{ActivityEntityID=>'Right'}},
    Left=>{T3=>{ActivityEntityID=>'End'}},
    Right=>{T4=>{ActivityEntityID=>'End'}},
}};
my $Before = $G->Build(Process=>$Fork,ActivityID=>'S',HistorySteps=>['S']);
is_deeply([sort map { $_->{ID} } @{$Before->{Nodes}}],[qw(End Left Right S)],'All branches before decision');
my $After = $G->Build(Process=>$Fork,ActivityID=>'Left',HistorySteps=>[qw(S Left)]);
is_deeply([sort map { $_->{ID} } @{$After->{Nodes}}],[qw(End Left)],'Skip alternative after decision');
my $Events = [
    {HistoryType=>'TicketDynamicFieldUpdate',Name=>'%%FieldName%%ProcessManagementProcessID%%Value%%P1%%OldValue%%'},
    {HistoryType=>'TicketDynamicFieldUpdate',Name=>'%%FieldName%%ProcessManagementActivityID%%Value%%A1%%OldValue%%'},
    {HistoryType=>'TicketDynamicFieldUpdate',Name=>'%%FieldName%%ProcessManagementActivityID%%Value%%A2%%OldValue%%A1'},
];
is_deeply($G->HistorySteps(History=>$Events,ProcessField=>'ProcessManagementProcessID',ActivityField=>'ProcessManagementActivityID',ProcessID=>'P1',ActivityID=>'A3'),[qw(A1 A2 A3)],'History tracks actual steps');
my $Orphan = $G->Build(Process=>{StartActivity=>'A1',Path=>{A1=>{T1=>{ActivityEntityID=>'A2'}},A9=>{}}},ActivityID=>'A9',HistorySteps=>['A9']);
ok(!$Orphan->{Completed},'Orphan terminal not counted complete');
ok(!defined($G->Build(Process=>$P,ActivityID=>'Missing',HistorySteps=>[])),'Invalid activity rejected');
done_testing();
