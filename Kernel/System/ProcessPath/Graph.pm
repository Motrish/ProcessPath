package Kernel::System::ProcessPath::Graph;

use strict;
use warnings;
use utf8;

# Pure graph/layout helpers; no database, no OTOBO services.

sub HistorySteps {
    my ( $Self, %Param ) = @_;

    my $Lines            = $Param{History} || [];
    my $ProcessField     = $Param{ProcessField}  || '';
    my $ActivityField    = $Param{ActivityField} || '';
    my $CurrentProcessID = $Param{ProcessID}     || '';
    my $CurrentActivity  = $Param{ActivityID}    || '';

    my $StartIndex = 0;
    for my $Index ( 0 .. $#{$Lines} ) {
        my $Entry = _HistoryField( $Lines->[$Index] );
        next if !$Entry || $Entry->{Field} ne $ProcessField;
        # Start a new lifecycle whenever a process is assigned/reassigned.
        if ( $Entry->{Value} eq $CurrentProcessID && $Entry->{OldValue} ne $CurrentProcessID ) {
            $StartIndex = $Index + 1;
        }
    }

    my @Steps;
    for my $Index ( $StartIndex .. $#{$Lines} ) {
        my $Entry = _HistoryField( $Lines->[$Index] );
        next if !$Entry || $Entry->{Field} ne $ActivityField;
        next if !$Entry->{Value};
        push @Steps, $Entry->{Value} if !@Steps || $Steps[-1] ne $Entry->{Value};
    }

    push @Steps, $CurrentActivity if $CurrentActivity && ( !@Steps || $Steps[-1] ne $CurrentActivity );
    return \@Steps;
}

sub _HistoryField {
    my ($Line) = @_;
    return if ref $Line ne 'HASH' || ( $Line->{HistoryType} || '' ) ne 'TicketDynamicFieldUpdate';
    my $Raw = $Line->{Name} // '';
    # OTOBO 11: %%FieldName%%NAME%%Value%%NEW%%OldValue%%OLD
    my @Tokens = split /%%/, $Raw, -1;
    return unless @Tokens >= 7 && $Tokens[1] eq 'FieldName' && $Tokens[3] eq 'Value' && $Tokens[5] eq 'OldValue';
    return { Field => $Tokens[2], Value => $Tokens[4], OldValue => $Tokens[6] };
}

sub Build {
    my ( $Self, %Param ) = @_;
    my $Process = $Param{Process} || {};
    my $Paths   = ref $Process->{Path} eq 'HASH' ? $Process->{Path} : {};
    my $Names   = $Param{Names} || {};
    my $Start   = $Process->{StartActivity} // '';
    my $Current = $Param{ActivityID} // '';
    my $History = $Param{HistorySteps} || [];

    my (%Nodes, %Next, @Edges);
    $Nodes{$Start} = 1 if $Start;
    for my $From ( sort keys %{$Paths} ) {
        $Nodes{$From} = 1;
        next unless ref $Paths->{$From} eq 'HASH';
        for my $Transition ( sort keys %{ $Paths->{$From} } ) {
            my $DestData = $Paths->{$From}{$Transition};
            next if ref $DestData ne 'HASH';
            my $To = $DestData->{ActivityEntityID};
            next if !$To;
            $Nodes{$To} = 1;
            push @{ $Next{$From} }, $To;
            push @Edges, { From => $From, To => $To, Transition => $Transition };
        }
    }
    return unless %Nodes && $Current && $Nodes{$Current};

    # BFS: shortest distance from the initial activity. Cycles do not recur forever.
    my %Level;
    my @Queue = $Start && $Nodes{$Start} ? ($Start) : ();
    $Level{$Start} = 0 if @Queue;
    while (@Queue) {
        my $From = shift @Queue;
        for my $To ( sort @{ $Next{$From} || [] } ) {
            next if exists $Level{$To};
            $Level{$To} = $Level{$From} + 1;
            push @Queue, $To;
        }
    }
    my %Reachable = %Level;
    # Orphaned graph components still appear so no path is silently hidden.
    my $Last = 0;
    for my $Value ( values %Level ) { $Last = $Value if $Value > $Last; }
    for my $ID ( sort keys %Nodes ) {
        next if exists $Level{$ID};
        $Level{$ID} = ++$Last;
    }

    my (%Columns, %Past, %Traversed);
    for my $Index ( 0 .. $#{$History} ) {
        my $ID = $History->[$Index];
        next unless $Nodes{$ID};
        $Past{$ID} = 1 if $Index < $#{$History};
        if ($Index) {
            my $Prev = $History->[$Index - 1];
            $Traversed{"$Prev\0$ID"} = 1 if defined $Prev;
        }
    }
    for my $ID ( keys %Nodes ) {
        push @{ $Columns{ $Level{$ID} } }, $ID;
    }
    my $ColCount = 0;
    my $MaxRows  = 1;
    for my $L ( keys %Columns ) {
        $ColCount = $L + 1 if $L + 1 > $ColCount;
        my $Count = @{ $Columns{$L} };
        $MaxRows = $Count if $Count > $MaxRows;
        @{ $Columns{$L} } = sort {
            ( $Names->{$a} || $a ) cmp ( $Names->{$b} || $b ) || $a cmp $b
        } @{ $Columns{$L} };
    }

    # Keep complete activity titles. Extend tile height if titles need more than
    # the usual two lines; row spacing follows the tallest tile in this graph.
    my (%WrappedNames, $MaxLines);
    $MaxLines = 1;
    for my $ID ( keys %Nodes ) {
        $WrappedNames{$ID} = _WrapName( $Names->{$ID} || $ID );
        my $Count = scalar @{ $WrappedNames{$ID} };
        $MaxLines = $Count if $Count > $MaxLines;
    }

    my $NodeW  = 156;
    my $NodeH  = 82;
    my $NeededNodeH = 25 + 16 * ( $MaxLines - 1 ) + 35;
    $NodeH = $NeededNodeH if $NeededNodeH > $NodeH;
    my $StepX  = 215;
    my $StepY  = $NodeH + 28;
    my $Pad    = 32;
    my $Width  = ( $ColCount - 1 ) * $StepX + $NodeW + 2 * $Pad;
    my $Height = ( $MaxRows - 1 ) * $StepY + $NodeH + 2 * $Pad;
    my (%Coords, @RenderedNodes);

    my $Terminal = !( @{ $Next{$Current} || [] } );
    # An end activity has no outgoing transitions. Closed ticket state alone does not count.
    my $IsComplete = $Terminal && exists $Reachable{$Current} ? 1 : 0;

    for my $L ( sort { $a <=> $b } keys %Columns ) {
        my $Rows = $Columns{$L};
        my $Offset = ( $MaxRows - scalar @{$Rows} ) * $StepY / 2;
        for my $Index ( 0 .. $#{$Rows} ) {
            my $ID = $Rows->[$Index];
            my $X  = $Pad + $L * $StepX;
            my $Y  = $Pad + $Offset + $Index * $StepY;
            $Coords{$ID} = { X => $X, Y => $Y };
            my $State = $ID eq $Current ? ( $IsComplete ? 'completed' : 'current' )
                : $Past{$ID} ? 'completed' : 'pending';
            my $FullName = $Names->{$ID} || $ID;
            push @RenderedNodes, {
                ID    => $ID,
                Name  => $FullName,
                Lines => $WrappedNames{$ID},
                X     => $X,
                Y     => $Y,
                W     => $NodeW,
                H     => $NodeH,
                State => $State,
                IsCurrent => $ID eq $Current ? 1 : 0,
            };
        }
    }

    my @RenderedEdges;
    for my $Edge (@Edges) {
        my ( $From, $To ) = @Coords{ $Edge->{From}, $Edge->{To} };
        next if !$From || !$To;
        my ( $X1, $Y1 ) = ( $From->{X} + $NodeW, $From->{Y} + $NodeH / 2 );
        my ( $X2, $Y2 ) = ( $To->{X}, $To->{Y} + $NodeH / 2 );
        my $Path;
        if ( $X2 > $X1 ) {
            my $Mid = ( $X1 + $X2 ) / 2;
            $Path = "M $X1 $Y1 C $Mid $Y1, $Mid $Y2, $X2 $Y2";
        }
        else {
            # Backward edges / loops: bend below the nodes.
            my $Bottom = $Height - 8;
            my $LX = $X1 + 18;
            my $RX = $X2 - 18;
            $Path = "M $X1 $Y1 L $LX $Y1 Q $LX $Bottom, $RX $Bottom Q $RX $Y2, $X2 $Y2";
        }
        push @RenderedEdges, {
            Path      => $Path,
            Traversed => $Traversed{"$Edge->{From}\0$Edge->{To}"} ? 1 : 0,
        };
    }

    return {
        Name       => $Process->{Name} || 'Process',
        Nodes      => \@RenderedNodes,
        Edges      => \@RenderedEdges,
        Width      => $Width,
        Height     => $Height,
        Completed  => $IsComplete,
        CurrentName => $Names->{$Current} || $Current,
    };
}

sub _WrapName {
    my ($Name) = @_;
    $Name //= '';
    $Name =~ s/^\s+|\s+$//g;

    # Wrap at word boundaries when possible. Never shorten labels or append
    # an ellipsis. Split individual very long words so they stay inside tiles.
    my $MaxChars = 20;
    my @Lines;
    my $Line = '';
    for my $Word ( split /\s+/, $Name ) {
        next if !$Word;

        while ( length($Word) > $MaxChars ) {
            if ( length($Line) ) {
                push @Lines, $Line;
                $Line = '';
            }
            push @Lines, substr( $Word, 0, $MaxChars, '' );
        }
        next if !$Word;

        if ( length($Line) && length($Line) + 1 + length($Word) > $MaxChars ) {
            push @Lines, $Line;
            $Line = '';
        }
        $Line .= ( $Line ? ' ' : '' ) . $Word;
    }
    push @Lines, $Line if $Line ne '';
    @Lines = ('') if !@Lines;
    return \@Lines;
}

1;
