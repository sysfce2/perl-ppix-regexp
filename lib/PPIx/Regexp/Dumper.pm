=head1 NAME

PPIx::Regexp::Dumper - Dump the results of parsing regular expressions

=head1 SYNOPSIS

 use PPIx::Regexp::Dumper;
 PPIx::Regexp::Dumper->new( 'qr{foo}smx' )
     ->print();

=head1 INHERITANCE

C<PPIx::Regexp::Dumper> is a
L<PPIx::Regexp::Support|PPIx::Regexp::Support>.

C<PPIx::Regexp::Dumper> has no descendants.

=head1 DESCRIPTION

This class generates a formatted dump of a
L<PPIx::Regexp::Element|PPIx::Regexp::Element> object (or any subclass
thereof), a L<PPIx::Regexp::Tokenizer|PPIx::Regexp::Tokenizer>
object, or a string that can be made into one of these.

=head1 METHODS

This class provides the following public methods. Methods not documented
here are private, and unsupported in the sense that the author reserves
the right to change or remove them without notice.

=cut

package PPIx::Regexp::Dumper;

use strict;
use warnings;

use base qw{ PPIx::Regexp::Support };

use Carp;
use Scalar::Util qw{ blessed looks_like_number };

use PPIx::Regexp;
use PPIx::Regexp::Constant qw{
    ARRAY_REF
    INFINITY
    @CARP_NOT
};
use PPIx::Regexp::Tokenizer;
use PPIx::Regexp::Util qw{ __choose_tokenizer_class __instance };

our $VERSION = '0.090_02';

use constant LOCATION_WIDTH	=> 19;

=head2 new

 my $dumper = PPIx::Regexp::Dumper->new(
     '/foo/', ordinal => 1,
 );

This static method instantiates the dumper. It takes the string,
L<PPI::Element|PPI::Element>,
L<PPIx::Regexp::Element|PPIx::Regexp::Element>, or
L<PPIx::Regexp::Tokenizer|PPIx::Regexp::Tokenizer> to be dumped as the
first argument.  Optional further arguments may be passed as name/value
pairs.

The following options are recognized:

=over

=item default_modifiers array_reference

This argument is a reference to a list of default modifiers to be
applied to the statement being parsed. See L<PPIx::Regexp|PPIx::Regexp>
L<new()|PPIx::Regexp/new> for the details.

=item encoding name

This argument is the name of the encoding of the regular expression. If
specified, it is passed through to
L<< PPIx::Regexp->new()|PPIx::Regexp/new >>. It also causes an
C<Encode::encode> to be done on any parse content dumped.

=item explain Boolean

If true, this option causes the C<explain()> output of each object to be
dumped.

=item indent number

This argument is the number of additional spaces to indent each level of
the parse hierarchy. This is ignored if either the C<test> or C<tokens>
argument is true.

The default is 2.

=item margin number

This is the number of spaces to indent the top level of the parse
hierarchy. This is ignored if the C<test> argument is true.

The default is zero.

=item ordinal Boolean

If true, this option causes the C<ordinal> values of
L<PPIx::Regexp::Token::Literal|PPIx::Regexp::Token::Literal> objects to
be dumped.

=item perl_version Boolean

If true, this option causes the C<perl_version_introduced> and
C<perl_version_removed> values associated with each object dumped to be
displayed.

=item ppi Boolean

If true, any Perl code contained in the object will be dumped.

=item short Boolean

If true, leading C<'PPIx::Regexp::'> will be removed from the class
names in the output.

=item strict Boolean

This option is passed on to the parser, where it specifies whether the
parse should assume C<use re 'strict'> is in effect.

The C<'strict'> pragma was introduced in Perl 5.22, and its
documentation says that it is experimental, and that there is no
commitment to backward compatibility. The same applies to the
parse produced when this option is asserted.

The default is false.

=item significant Boolean

If true, this option causes only significant elements to be dumped.

The default is false.

=item test Boolean

If true, this option causes the output to be formatted as a regression
test rather than as a straight dump. The output produced by asserting
this option is explicitly undocumented, in the sense that the author
reserves the right to change the generated output without notice of any
kind.

The default is false.

=item tokens Boolean

If true, this option causes a dump of tokenizer output rather than of a
full parse of the regular expression. This is forced true if the dump is
of a L<PPIx::Regexp::Tokenizer|PPIx::Regexp::Tokenizer>.

The default is false.

=item trace number

If greater than zero, this option causes a trace of the parse. This
option is unsupported in the sense that the author reserves the right to
change it without notice.

The default is zero.

=item verbose number

If greater than zero, this option causes additional information to be
given about the elements found. This option is unsupported in the sense
that the author reserves the right to change it without notice.

The default is zero.

=item width Boolean

If true, this option causes a dump of the width of the object.

=back

If the thing to be dumped was a string, unrecognized arguments are
passed to C<< PPIx::Regexp::Tokenizer->new() >>. Otherwise they are
ignored.

=cut

{

    my %default = (
	explain	=> 0,
	indent	=> 2,
	locations	=> 0,
	margin	=> 0,
	ordinal	=> 0,
	perl_version => 0,
	ppi	=> 0,
	short	=> 0,
	significant => 0,
	test	=> 0,
	tokens	=> 0,
	verbose => 0,
	width	=> 0,
    );

    sub new {
	my ( $class, $re, %args ) = @_;
	ref $class and $class = ref $class;

	my $self = {
	    encoding => $args{encoding},
	    lister => undef,
	    object => undef,
	    source => $re,
	    strict => $args{strict},
	};

	foreach my $key ( qw{ default_modifiers parse } ) {
	    exists $args{$key}
		and $self->{$key} = $args{$key};
	}

	foreach my $key ( keys %default ) {
	    $self->{$key} = exists $args{$key} ?
		delete $args{$key} :
		$default{$key};
	}

	$self->{ordinal} ||= $self->{verbose};

	if ( __instance( $re, 'PPIx::Regexp::Tokenizer' ) ) {
	    $self->{object} = $re;
	    $self->{tokens} = 1;
	} elsif ( __instance( $re, 'PPIx::Regexp::Element' ) ) {
	    $self->{object} = $re;
	} elsif ( ARRAY_REF eq ref $re ) {
	    $self->{object} = $re;
	} elsif ( ref $re && ! __instance( $re, 'PPI::Element' ) ) {
	    croak "Do not know how to dump ", ref $re;
	} elsif ( $self->{tokens} ) {
	    my $tokenizer_class = __choose_tokenizer_class( $re, \%args )
		or croak 'Unsupported data type';
	    __instance( $re, 'PPI::Element' )
		or $args{location} = [ 1, 1, 1, 1, undef ];
	    $self->{object} =
		$tokenizer_class->new( $re, %args )
		    or Carp::croak( $tokenizer_class->errstr() );
	} else {
	    __instance( $re, 'PPI::Element' )
		or $args{location} = [ 1, 1, 1, 1, undef ];
	    $self->{object} =
		PPIx::Regexp->new( $re, %args )
		    or Carp::croak( PPIx::Regexp->errstr() );
	}

	bless $self, $class;

	return $self;

    }

}

=head2 list

 print map { "$_\n" } $dumper->list();

This method produces an array containing the dump output, one line per
element. The output has no left margin applied, and no newlines.

=cut

sub list {
    my ( $self ) = @_;
    my $lister = $self->{test} ? '__PPIX_DUMPER__test' : '__PPIX_DUMPER__dump';

    ARRAY_REF eq ref $self->{object}
	and return ( map { $_->$lister( $self ) } @{ $self->{object} } );

    return $self->{object}->$lister( $self );
}

=head2 print

 $dumper->print();

This method simply prints the result of L</string> to standard out.

=cut

sub print : method {	## no critic (ProhibitBuiltinHomonyms)
    my ( $self ) = @_;
    # Non-characters and Non-Unicode code points are explicitly allowed
    # as delimiters, at least as of 5.29.0, which is where unassigned
    # and combining code points became illegal. Unfortunately the
    # warnings below were not introduced until 5.14, so have to go for
    # the next-higher warning category.
    # no warnings qw{ nonchar non_unicode };	## no critic (ProhibitNoWarnings)
    no warnings qw{ utf8 };	## no critic (ProhibitNoWarnings)
    print $self->string();
    return;
}

=head2 string

 print $dumper->string();

This method adds left margin and newlines to the output of L</list>,
concatenates the result into a single string, and returns that string.

=cut

sub string {
    my ( $self ) = @_;
    my $margin = ' ' x $self->{margin};
    return join( '',
	map { $margin . $_ . "\n" } $self->list() );
}

# quote a string.
sub _safe {
    my ( $self, @args ) = @_;
    my @rslt;
    foreach my $item ( @args ) {
	if ( blessed( $item ) ) {
	    $item = $self->encode( $item->content() );
	}
	if ( ! defined $item ) {
	    push @rslt, 'undef';
	} elsif ( ARRAY_REF eq ref $item ) {
	    push @rslt, join( ' ', '[', $self->_safe( @{ $item } ), ']' );
	} elsif ( looks_like_number( $item ) ) {
	    push @rslt, $item;
	} else {
	    $item =~ s/ ( [\\'] ) /\\$1/smxg;
	    push @rslt, "'$item'";
	}
    }
    my $rslt = join( ', ', @rslt );
    return $rslt
}

sub _safe_version {
    my ( undef, $version ) = @_;	# Invocant unused
    return defined $version ? "'$version'" : 'undef';
}

sub __nav {
    my ( $self, @args ) = @_;
    my $rslt = $self->_safe( @args );
    $rslt =~ s/ ' (\w+) ' , /$1 =>/smxg;
    $rslt =~ s/ \[ \s+ \] /[]/smxg;
    $rslt =~ s/ \[ \s* ( [0-9]+ ) \s* \] /$1/smxg;
    return $rslt;
}

sub _perl_version {
    my ( undef, $elem ) = @_;		# Invocant unused

    return $elem->requirements_for_perl();
}

sub _ppi {
    my ( $self, $elem ) = @_;

    $self->{ppi}
	and $elem->can( 'ppi' )
	or return;

    require PPI::Dumper;

    # PPI::Dumper reports line_number(), but I want
    # logical_line_number(). There is no configuration for this, but the
    # interface is public, so I mung it to do what I want.
    my $locn = PPI::Element->can( 'location' );
    local *PPI::Element::location = sub {
	my $loc = $locn->( @_ );
	$loc->[0] = $loc->[3];
	return $loc;
    };

    my $dumper = PPI::Dumper->new( $elem->ppi(),
	map { $_ => $self->{$_} } qw{ indent locations },
    );

    return $dumper->list();
}

sub _content {
    my ( $self, $elem, $dflt ) = @_;
    defined $dflt or $dflt = '';

    defined $elem or return $dflt;
    if ( ARRAY_REF eq ref $elem ) {
	my $rslt = join '',
	    map { $self->_content( $_ ) }
	    grep { ! $self->{significant} || $_->significant() }
	    @{ $elem };
	return $rslt eq '' ? $dflt : $rslt;
    }
    blessed( $elem ) or return $dflt;
    return $self->encode( $elem->content() );
}

sub _tokens_dump {
    my ( $self, $elem, $depth ) = @_;

    not $self->{significant} or $elem->significant() or return;

    my @rslt;
    foreach my $token ( $elem->tokens() ) {
	not $self->{significant} or $token->significant() or next;
	push @rslt, $token->__PPIX_DUMPER__dump( $self, $depth );
    }
    return @rslt;
}

sub _format_default_modifiers {
    my ( $self, $subr, $elem ) = @_;
    my @arg = $self->_safe( $elem );
    foreach my $attr ( qw{ default_modifiers parse strict } ) {
	defined ( my $val = $self->{$attr} )
	    or next;
	ARRAY_REF eq ref $val
	    and not @{ $val }
	    and next;
	push @arg, "$attr => @{[ $self->_safe( $val ) ]}";
    }
    return sprintf '%-8s( %s );', $subr, join ', ', @arg;
}

sub _format_matcher_dump {
    my ( undef, $elem ) = @_;
    my $value = $elem->is_matcher();
    return sprintf 'is_matcher=%s',
	$value ? 'true' : defined $value ?  'false' : 'undef';
}

sub _format_modifiers_dump {
    my ( undef, $elem ) = @_;		# Invocant unused
    my %mods = $elem->modifiers();
    my @accum;
    $mods{match_semantics}
	and push @accum, 'match_semantics=' . delete
	    $mods{match_semantics};
    foreach my $modifier ( sort keys %mods ) {
	push @accum, $mods{$modifier} ? $modifier :
	"-$modifier";
    }
    @accum and return join ' ', @accum;
    return;
}

sub _format_width_dump {
    my @arg = @_;
    foreach ( @arg ) {
	if ( defined ) {
	    $_ == INFINITY
		and $_ = q<'Inf'>;
	} else {
	    $_ = 'undef';
	}
    }
    wantarray
	and return @arg;
    return join ', ', @arg;
}

sub _format_width_test {
    my @arg = @_;
    foreach ( @arg ) {
	if ( defined ) {
	    $_ == INFINITY
		and $_ = 'INFINITY';
	} else {
	    $_ = 'undef';
	}
    }
    wantarray
	and return @arg;
    return join ', ', @arg;
}

sub _tokens_test {
    my ( $self, $elem ) = @_;

    not $self->{significant} or $elem->significant() or return;

    my @tokens = $elem->tokens();

    my @rslt = (
	$self->_format_default_modifiers( tokenize => $elem ),
	sprintf( 'count   ( %d );', scalar @tokens ),
    );

    my $inx = 0;
    foreach my $token ( @tokens ) {
	not $self->{significant} or $token->significant() or next;
	push @rslt, $token->__PPIX_DUMPER__test( $self, $inx++ );
    }
    return @rslt;
}

sub PPIx::Regexp::Element::__PPIX_DUMPER__dump_explanation {
    my ( $self, undef, $line ) = @_;	# $dumper unused
    my @expl = $self->explain()
	or return $line;
    1 == @expl
	and return "$line\t$expl[0]";
    wantarray
	or return sprintf "%s\t%s", $line, join '; ', @expl;
    ( my $blank = $line ) =~ s/\S/ /smxg;
    my @rslt;
    foreach my $splain ( @expl ) {
	push @rslt, "$line\t$splain";
	$line = $blank;
    }
    return @rslt;
}

sub PPIx::Regexp::__PPIX_DUMPER__test {
    my ( $self, $dumper ) = @_;

    $dumper->{tokens}
	and return $dumper->_tokens_test( $self );

    not $dumper->{significant} or $self->significant() or return;

#   my $parse = 'parse   ( ' . $dumper->_safe( $self ) . ' );';
    my $parse = $dumper->_format_default_modifiers( parse => $self );
    my $fail =  'value   ( failures => [], ' . $self->failures() . ' );';

    # Note that we can not use SUPER in the following because SUPER goes
    # by the current package, not by the class of the object.
    my @rslt = PPIx::Regexp::Node::__PPIX_DUMPER__test( $self, $dumper );

    # Get rid of the empty choose();
    shift @rslt;

    return ( $parse, $fail, @rslt );
}

sub PPIx::Regexp::Node::__PPIX_DUMPER__dump {
    my ( $self, $dumper, $depth ) = @_;

    $depth ||= 0;

    $dumper->{tokens}
	and return $dumper->_tokens_dump( $self, $depth );

    not $dumper->{significant} or $self->significant() or return;

    my @rslt = ( ref $self );
    $dumper->{short}
	and $rslt[0] =~ s/ \A PPIx::Regexp:: //smx;
    $self->isa( 'PPIx::Regexp' )
	and $rslt[-1] .= $dumper->{verbose}
	    ? sprintf "\tfailures=%d\tmax_capture_number=%d",
		$self->failures(), $self->max_capture_number()
	    : sprintf "\tfailures=%d", $self->failures();

    substr $rslt[0], 0, 0, ' ' x ( $depth * $dumper->{indent} );

    $dumper->{locations}
	and substr $rslt[0], 0, 0, ' ' x LOCATION_WIDTH;

    if ( $dumper->{width} ) {
	my $width = _format_width_dump( $self->width() );
	$rslt[-1] .= "\t{ $width }";
    }

    $dumper->{perl_version}
	and $rslt[-1] .= "\t" . $dumper->_perl_version( $self );

    if ( defined ( my $err = $self->error() ) ) {
	$rslt[-1] .= "\t$err";
    } else {
	$dumper->{explain}
	    and push @rslt, $self->__PPIX_DUMPER__dump_explanation(
		$dumper, pop @rslt );
    }

    $depth++;
    foreach my $elem ( $self->children() ) {
	push @rslt, $elem->__PPIX_DUMPER__dump( $dumper, $depth );
    }
    return @rslt;
}

sub PPIx::Regexp::Node::__PPIX_DUMPER__test {
    my ( $self, $dumper ) = @_;

    not $dumper->{significant} or $self->significant() or return;

    my @rslt;
    @rslt = (
	'choose  ( ' . $dumper->__nav( $self->nav() ) . ' );',
	'klass   ( ' . $dumper->_safe( ref $self ) . ' );',
	'count   ( ' . scalar $self->children() . ' );',
    );

    if ( defined( my $err = $self->error() ) ) {

	push @rslt,
	    'error   ( ' . $dumper->_safe( $err ) . ' );';

    }

    if ( $dumper->{width} ) {
	my $raw = _format_width_test( $self->raw_width() );
	my $width = _format_width_test( $self->width() );
	push @rslt,
	    "raw_width( $raw );",
	    "width   ( $width );";
    }

    if ( $dumper->{perl_version} ) {
	foreach my $method ( qw{
	    perl_version_introduced
	    perl_version_removed
	} ) {
	    push @rslt, "value   ( $method => [], " .
		$dumper->_safe_version( $self->$method() ) . ' );';
	}
    }
    foreach my $elem ( $self->children() ) {
	push @rslt, $elem->__PPIX_DUMPER__test( $dumper );
    }
    return @rslt;
}

sub _format_value {
    my ( $val ) = @_;
    defined $val
	or return 'undef';
    $val =~ m/ \A [0-9]+ \z /smx
	and return $val;
    $val =~ s/ (?= [\\"] ) /\\/smxg;
    return qq{"$val"};
}

{

    my %dflt = (
	start => '???',
	type => '',
	finish => '???',
    );

    sub PPIx::Regexp::Structure::__PPIX_DUMPER__dump {
	my ( $self, $dumper, $depth ) = @_;

	$depth ||= 0;

	not $dumper->{significant} or $self->significant() or return;

	my @delim;
	foreach my $method ( qw{ start type finish } ) {
	    my @elem = $self->$method();
	    push @delim, @elem ? $dumper->_content( \@elem ) : $dflt{$method};
	}
	my @rslt = ( ref $self, "$delim[0]$delim[1] ... $delim[2]" );
	$dumper->{short}
	    and $rslt[0] =~ s/ \A PPIx::Regexp:: //smx;

	substr $rslt[0], 0, 0, ' ' x ( $depth * $dumper->{indent} );

	$dumper->{locations}
	    and substr $rslt[0], 0, 0, ' ' x LOCATION_WIDTH;

	$dumper->{perl_version}
	    and push @rslt, $dumper->_perl_version( $self );

	if ( $dumper->{width} ) {
	    my $width = _format_width_dump( $self->width() );
	    push @rslt, "{ $width }";
	}

	if ( $dumper->{verbose} ) {
	    foreach my $method ( qw{ number name max_capture_number } ) {
		$self->can( $method ) or next;
		push @rslt, sprintf '%s=%s', $method, _format_value(
		    $self->$method() );
	    }
	    foreach my $method ( qw{ can_be_quantified is_quantifier } ) {
##		is_case_sensitive
		$self->can( $method ) or next;
		$self->$method() and push @rslt, $method;
	    }
	    $self->isa( 'PPIx::Regexp::Structure::Modifier' )
		and push @rslt, $dumper->_format_modifiers_dump(
		$self->type( 0 ) );

	    push @rslt, $dumper->_format_matcher_dump( $self );
	}

	foreach my $method ( 'start', undef, 'finish' ) {
	    my $ele = defined $method ? $self->$method() : $self
		or next;
	    if ( defined ( my $err = $ele->error() ) ) {
		push @rslt, $err;
	    }
	}

	@rslt = ( join "\t", @rslt );

	$dumper->{explain}
	    and not defined $self->error()
	    and push @rslt, $self->__PPIX_DUMPER__dump_explanation(
		$dumper, pop @rslt );

	$depth++;
	foreach my $elem ( $self->children() ) {
	    push @rslt, $elem->__PPIX_DUMPER__dump( $dumper, $depth );
	}
	return @rslt;
    }

}

sub PPIx::Regexp::Structure::__PPIX_DUMPER__test {
    my ( $self, $dumper ) = @_;

    not $dumper->{significant} or $self->significant() or return;

    my @nav = $self->nav();
    my @rslt = (
	'choose  ( ' . $dumper->__nav( @nav ) . ' );',
	'klass   ( ' . $dumper->_safe( ref $self ) . ' );',
	'count   ( ' . scalar $self->children() . ' );',
    );
    if ( $dumper->{verbose} ) {
	foreach my $method ( qw{ number name } ) {
	    $self->can( $method ) or next;
	    push @rslt, 'value   ( ' . $method . ' => [], ' .
		$dumper->_safe( $self->$method() ) . ' );';
	}
    }

    if ( $dumper->{width} ) {
	my $raw = _format_width_test( $self->raw_width() );
	my $width = _format_width_test( $self->width() );
	push @rslt,
	    "raw_width( $raw );",
	    "width   ( $width );";
    }

    foreach my $method ( qw{ start type finish } ) {
	my @eles = $self->$method();
	push @rslt, 'choose  ( ' . $dumper->__nav(
	    @nav, $method, [] ) . ' );',
	    'count   ( ' . scalar @eles . ' );';
	foreach my $inx ( 0 .. $#eles ) {
	    my $elem = $eles[$inx];
	    push @rslt, 'choose  ( ' . $dumper->__nav(
		@nav, $method, $inx ) . ' );',
		'klass   ( ' . $dumper->_safe( ref $elem || $elem ) . ' );',
		'content ( ' . $dumper->_safe( $elem ) . ' );';
	}
    }
    foreach my $elem ( $self->children() ) {
	push @rslt, $elem->__PPIX_DUMPER__test( $dumper );
    }
    return @rslt;
}

sub PPIx::Regexp::Tokenizer::__PPIX_DUMPER__dump {
    my ( $self, $dumper, $depth ) = @_;

    $depth ||= 0;

    return $dumper->_tokens_dump( $self, $depth );

}

sub PPIx::Regexp::Tokenizer::__PPIX_DUMPER__test {
    my ( $self, $dumper ) = @_;

    return $dumper->_tokens_test( $self );
}

sub PPIx::Regexp::Token::__PPIX_DUMPER__dump {
    my ( $self, $dumper, $depth ) = @_;

    $depth ||= 0;

    not $dumper->{significant}
	or $self->significant()
	or return;

    my @rslt = ( ref $self, $dumper->_safe( $self ) );
    $dumper->{short}
	and $rslt[0] =~ s/ \A PPIx::Regexp:: //smx;

    substr $rslt[0], 0, 0, ' ' x ( $depth * $dumper->{indent} );

    $dumper->{locations}
	and substr $rslt[0], 0, 0,
		sprintf '[ % 4d, % 3d, % 3d ] ',
		    $self->logical_line_number(),
		    $self->column_number(),
		    $self->visual_column_number();

    my @ppi;
    @ppi = $dumper->_ppi( $self )
	and shift @ppi;	# Ignore PPI::Document
    foreach ( @ppi ) {
	if ( $dumper->{locations} ) {
	    s/ ( [0-9]+ \s+ \] ) /$1  /smxg
		or substr $_, 0, 0, '  ';
	} else {
	    substr $_, 0, 0, '  ';
	}
    }

    if ( $dumper->{width} ) {
	my $width = _format_width_dump( $self->width() );
	push @rslt, "{ $width }";
    }

    $dumper->{perl_version}
	and push @rslt, $dumper->_perl_version( $self );

    if ( defined( my $err = $self->error() ) ) {

	return join "\t", @rslt, $err;

    } else {

	if ( $dumper->{ordinal} && $self->can( 'ordinal' )
	    && defined ( my $ord = $self->ordinal() ) ) {
	    push @rslt, sprintf '0x%02x', $ord;
	}

	if ( $dumper->{verbose} ) {

	    if ( $self->isa( 'PPIx::Regexp::Token::Reference' ) ) {
		foreach my $method ( qw{ absolute name number } ) {
		    defined( my $val = $self->$method() ) or next;
		    push @rslt, "$method=$val";
		}
	    }

	    foreach my $method (
		qw{ significant can_be_quantified is_quantifier } ) {
##		is_case_sensitive
		$self->can( $method )
		    and $self->$method()
		    and push @rslt, $method;
	    }

	    $self->can( 'ppi' )
		and push @rslt, $self->ppi()->content();

	    if ( $self->isa( 'PPIx::Regexp::Token::Modifier' ) ||
		$self->isa( 'PPIx::Regexp::Token::GroupType::Modifier' )
	    ) {
		push @rslt, $dumper->_format_modifiers_dump( $self );
	    }

	    push @rslt, $dumper->_format_matcher_dump( $self );
	}

	@rslt = ( join "\t", @rslt );

	$dumper->{explain}
	    and push @rslt, $self->__PPIX_DUMPER__dump_explanation(
		$dumper, pop @rslt );

	push @rslt, @ppi;

	return @rslt;
    }
}

sub PPIx::Regexp::Token::__PPIX_DUMPER__test {
    my ( $self, $dumper, @nav ) = @_;

    not $dumper->{significant} or $self->significant() or return;

    @nav or @nav = $self->nav();
    my @rslt = (
	'choose  ( ' . join(', ', $dumper->__nav( @nav ) ) . ' );',
	'klass   ( ' . $dumper->_safe( ref $self ) . ' );',
	'content ( ' . $dumper->_safe( $self ) . ' );',
    );

    if ( defined( my $err = $self->error() ) ) {

	push @rslt,
	    'error   ( ' . $dumper->_safe( $err ) . ' );';

    } else {

	if ( $dumper->{perl_version} ) {
	    foreach my $method ( qw{
		perl_version_introduced
		perl_version_removed
	    } ) {
		push @rslt, "value   ( $method => [], " .
		    $dumper->_safe_version( $self->$method() ) . ' );';
	    }
	}

	if ( $dumper->{width} ) {
	    my $raw = _format_width_test( $self->raw_width() );
	    my $width = _format_width_test( $self->width() );
	    push @rslt,
		"raw_width( $raw );",
		"width   ( $width );";
	}

	if ( $dumper->{verbose} ) {

	    foreach my $method (
		qw{ significant can_be_quantified is_quantifier } ) {
##		is_case_sensitive
		$self->can( $method ) or next;
		push @rslt, $self->$method() ?
		    "true    ( $method => [] );" :
		    "false   ( $method => [] );";
	    }

	    $self->can( 'ppi' )
		and push @rslt, "value   ( ppi => [], " .
		    $dumper->_safe( $self->ppi() ) . ' );';

	}
    }

    return @rslt;
}

1;

__END__

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=PPIx-Regexp>,
L<https://github.com/trwyant/perl-PPIx-Regexp/issues>, or in
electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2023, 2025 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
