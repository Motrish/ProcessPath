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

    # Build a complete adjacency list for validation and completion detection.
    my ( %AllNodes, %Next, @AllEdges );
    $AllNodes{$Start} = 1 if $Start;
    for my $From ( sort keys %{$Paths} ) {
        $AllNodes{$From} = 1;
        next unless ref $Paths->{$From} eq 'HASH';
        for my $Transition ( sort keys %{ $Paths->{$From} } ) {
            my $Target = $Paths->{$From}{$Transition};
            next unless ref $Target eq 'HASH' && $Target->{ActivityEntityID};
            my $To = $Target->{ActivityEntityID};
            $AllNodes{$To} = 1;
            push @{ $Next{$From} }, $To;
            push @AllEdges, { From => $From, To => $To, Transition => $Transition };
        }
    }
    return unless $Current && $AllNodes{$Current};

    # Confirm that the current step belongs to a graph path from the start.
    # Orphaned process activities must not be mistaken for completion.
    my %FromStart;
    if ($Start && $AllNodes{$Start}) {
        my @ToCheck = ($Start);
        $FromStart{$Start} = 1;
        while (@ToCheck) {
            my $ID = shift @ToCheck;
            for my $To ( @{ $Next{$ID} || [] } ) {
                next if $FromStart{$To}++;
                push @ToCheck, $To;
            }
        }
    }
    my $Complete = !( @{ $Next{$Current} || [] } ) && $FromStart{$Current} ? 1 : 0;

    # History order is meaningful: show past activities as narrow, rotated text
    # tabs at the left. Each activity is shown only once, also after loops.
    my ( %Past, @PastIDs );
    for my $ID ( @{$History} ) {
        next unless defined $ID && $AllNodes{$ID};
        next if $ID eq $Current && !$Complete;
        next if $Past{$ID}++;
        push @PastIDs, $ID;
    }
    # At a terminal activity, the last/current activity is also complete.
    if ($Complete && !$Past{$Current}) {
        $Past{$Current} = 1;
        push @PastIDs, $Current;
    }
    my @PastNodes = map {
        { ID => $_, Name => $Names->{$_} || $_ }
    } @PastIDs;

    # Only display the current activity and future steps reachable without
    # passing through an already completed activity. Thus abandoned branches
    # disappear instead of consuming space. A return to an earlier activity
    # will make its still-available branches visible at that point.
    my ( %Level, @ToVisit );
    if (!$Complete) {
        $Level{$Current} = 0;
        @ToVisit = ($Current);
    }
    while (@ToVisit) {
        my $ID = shift @ToVisit;
        for my $To ( sort @{ $Next{$ID} || [] } ) {
            next if $Past{$To} || exists $Level{$To};
            $Level{$To} = $Level{$ID} + 1;
            push @ToVisit, $To;
        }
    }

    my %Columns;
    for my $ID ( keys %Level ) {
        push @{ $Columns{ $Level{$ID} } }, $ID;
    }
    my ($MaxRows, $MaxColumn) = (1, 0);
    for my $L ( keys %Columns ) {
        @{ $Columns{$L} } = sort {
            ( $Names->{$a} || $a ) cmp ( $Names->{$b} || $b ) || $a cmp $b
        } @{ $Columns{$L} };
        $MaxRows = @{ $Columns{$L} } if @{ $Columns{$L} } > $MaxRows;
        $MaxColumn = $L if $L > $MaxColumn;
    }

    my ( %WrappedNames, $MaxLines ) = ();
    $MaxLines = 1;
    for my $ID ( keys %Level ) {
        $WrappedNames{$ID} = _WrapName( $Names->{$ID} || $ID );
        my $Count = scalar @{ $WrappedNames{$ID} };
        $MaxLines = $Count if $Count > $MaxLines;
    }

    my $NodeW  = 144;
    my $NodeH  = 66;
    my $NeededNodeH = 20 + 16 * ( $MaxLines - 1 ) + 33;
    $NodeH = $NeededNodeH if $NodeH < $NeededNodeH;
    my $StepX = 170;
    my $StepY = $NodeH + 22;
    my $Pad   = 18;
    my $Width  = %Level ? $MaxColumn * $StepX + $NodeW + 2 * $Pad : 0;
    my $Height = %Level ? ($MaxRows - 1) * $StepY + $NodeH + 2 * $Pad : 0;

    my ( %Coords, @RenderedNodes );
    for my $L ( sort { $a <=> $b } keys %Columns ) {
        my $Rows = $Columns{$L};
        my $Offset = ( $MaxRows - @{$Rows} ) * $StepY / 2;
        for my $Index ( 0 .. $#{$Rows} ) {
            my $ID = $Rows->[$Index];
            my $X = $Pad + $L * $StepX;
            my $Y = $Pad + $Offset + $Index * $StepY;
            $Coords{$ID} = { X => $X, Y => $Y };
            push @RenderedNodes, {
                ID        => $ID,
                Name      => $Names->{$ID} || $ID,
                Lines     => $WrappedNames{$ID},
                X         => $X,
                Y         => $Y,
                W         => $NodeW,
                H         => $NodeH,
                TextX     => $NodeW / 2,
                State     => $ID eq $Current ? 'current' : 'pending',
                IsCurrent => $ID eq $Current ? 1 : 0,
            };
        }
    }

    my @RenderedEdges;
    for my $Edge (@AllEdges) {
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
            my $Bottom = $Height - 6;
            my $LX = $X1 + 12;
            my $RX = $X2 - 12;
            $Path = "M $X1 $Y1 L $LX $Y1 Q $LX $Bottom, $RX $Bottom Q $RX $Y2, $X2 $Y2";
        }
        push @RenderedEdges, { Path => $Path, Traversed => 0 };
    }

    return {
        Name         => $Process->{Name} || 'Process',
        PastNodes    => \@PastNodes,
        PastColumns  => @PastNodes > 6 ? 6 : scalar @PastNodes,
        Nodes        => \@RenderedNodes,
        Edges        => \@RenderedEdges,
        Width        => $Width,
        Height       => $Height,
        Completed    => $Complete,
        CurrentName  => $Names->{$Current} || $Current,
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
