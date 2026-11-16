use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/..";
use Kernel::System::ProcessPath::Visibility;

my $Module = 'Kernel::System::ProcessPath::Visibility';
my $Allowed = sub { $Module->IsAllowed( ProcessID => $_[0], VisibleProcesses => $_[1] ) };

ok($Allowed->('Process-123', ['All processes (*)']), 'Existing default keeps all processes visible');
ok($Allowed->('Process-456', ['All processes (*)']), 'Wildcard accepts any process');
ok(!$Allowed->('Process-123', []), 'Empty selection disables all process paths');
ok(!$Allowed->('Process-123', undef), 'Missing config disables visibility');
ok(!$Allowed->('', ['All processes (*)']), 'Tickets without a process never show ProcessPath');
ok($Allowed->('Process-123', ['Gerätebereitstellung [Process-123]']), 'Selected process is visible');
ok(!$Allowed->('Process-999', ['Gerätebereitstellung [Process-123]']), 'Unselected process is hidden');
ok($Allowed->('Process-123', ['Geänderter Name [Process-123]']), 'Process rename preserves allowlist match');
ok($Allowed->('Process-123', ['Process-123']), 'Direct entity ID is supported for scripted configs');
ok(!$Allowed->('Process-12', ['Gerätebereitstellung [Process-123]']), 'Prefix collisions cannot enable other processes');
ok(!$Allowed->('Process-123', ['Andere Prozess-ID [Process-999]']), 'Only exact IDs are accepted');
ok(!$Allowed->('Process-123', ['Something [Process-123] extra']), 'No trailing text injection');
ok(!$Allowed->('Process-123', ['[Process-123]']), 'Labels must include nonempty name');
ok(!$Allowed->('Process-123', ['*']), 'No implicit wildcard');
ok(!$Allowed->('Process-123', [{}]), 'Invalid reference entries are ignored');
ok($Allowed->('Process-123', ['Andere [Process-999]', 'Richtig [Process-123]']), 'Multiple choices supported');
ok(!$Allowed->('Process-123', 'Gerätebereitstellung [Process-123]'), 'Scalar config is rejected');
ok($Allowed->('Process-123', ['All processes (*)', 'Richtig [Process-123]']), 'Wildcard and specific selections can coexist');
ok(!$Allowed->('Process-123', ['False [Process-1234]']), 'Longer ID not equal shorter ID');

done_testing();
