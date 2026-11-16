use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use File::Spec;
my $base = File::Spec->catdir($Bin, '..');
sub read_file {
    my ($path) = @_;
    open my $fh, '<:encoding(UTF-8)', File::Spec->catfile($base, split '/', $path) or die $!;
    local $/; return <$fh>;
}
my $css = read_file('var/httpd/htdocs/skins/Agent/default/css/ProcessPath.css');
my $tt  = read_file('Kernel/Output/HTML/Templates/Standard/AgentTicketZoom/ProcessPath.tt');
like($css, qr/\.pp-past\s*\{[^}]*display:\s*flex;/s, 'Uses horizontal flex');
like($css, qr/\.pp-past\s*\{[^}]*flex-wrap:\s*nowrap;/s, 'Never wraps');
like($css, qr/\.pp-past\s*\{[^}]*overflow-x:\s*auto;/s, 'Scrollable rail');
unlike($css, qr/grid-template-columns|grid-auto-flow:\s*row/, 'No rows/column cap');
like($tt, qr/class="pp-past" tabindex="0"/, 'Keyboard scrolling');
unlike($tt, qr/pp-past-columns/, 'No fixed column variable');
like($css, qr/\.pp-flow-with-graph \.pp-past\s*\{[^}]*max-width:/s, 'Current process keeps room for graph');
done_testing();
