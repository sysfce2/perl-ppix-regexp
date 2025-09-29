=head1 NAME

PPIx::Regexp::Element - Base of the PPIx::Regexp hierarchy.

=head1 SYNOPSIS

No user-serviceable parts inside.

=head1 INHERITANCE

C<PPIx::Regexp::Element> is not descended from any other class.

C<PPIx::Regexp::Element> is the parent of
L<PPIx::Regexp::Node|PPIx::Regexp::Node> and
L<PPIx::Regexp::Token|PPIx::Regexp::Token>.

=head1 DESCRIPTION

This class is the base of the L<PPIx::Regexp|PPIx::Regexp>
object hierarchy. It provides the same kind of navigational
functionality that is provided by L<PPI::Element|PPI::Element>.

=head1 METHODS

This class provides the following public methods. Methods not documented
here are private, and unsupported in the sense that the author reserves
the right to change or remove them without notice.

=cut

package PPIx::Regexp::Element;

use strict;
use warnings;

use 5.006;

use Carp;
use List::Util qw{ first max min };
use PPIx::Regexp::Util qw{ __instance };
use Scalar::Util qw{ refaddr weaken };

use PPIx::Regexp::Constant qw{
    FALSE
    LITERAL_LEFT_CURLY_REMOVED_PHASE_1
    LOCATION_LINE
    LOCATION_CHARACTER
    LOCATION_COLUMN
    LOCATION_LOGICAL_LINE
    LOCATION_LOGICAL_FILE
    MINIMUM_PERL
    TOKEN_UNKNOWN
    TRUE
    @CARP_NOT
};

our $VERSION = '0.090_02';

=head2 accepts_perl

 $token->accepts_perl( '5.020' )
     and say 'This works under Perl 5.20';

This method returns a true value if the token is acceptable under the
specified version of Perl, and a false value otherwise. Unless the token
(or its contents) have been equivocated on, the result is simply what
you would expect based on testing the results of
L<perl_version_introduced()|/perl_version_introduced> and
L<perl_version_removed()|/perl_version_removed> versus the given Perl
version number.

This method was added in version 0.051_01.

=cut

sub accepts_perl {
    my ( $self, $version ) = @_;
    foreach my $check ( $self->__perl_requirements() ) {
	$version < $check->{introduced}
	    and next;
	defined $check->{removed}
	    and $version >= $check->{removed}
	    and next;
	return TRUE;
    }
    return FALSE;
}

# Return the Perl requirements, constructing if necessary. The
# requirements are simply an array of hashes containing keys:
#   {introduced} - The Perl version introduced;
#   {removed} - The Perl version removed (or undef)
# The requirements are evaluated by iterating through the array,
# returning a true value if the version of Perl being tested falls
# inside any of the half-open (on the right) intervals.
sub __perl_requirements {
    my ( $self ) = @_;
    return @{ $self->{perl_requirements} ||=
	[ $self->__perl_requirements_setup() ] };
}

# Construct the array returned by __perl_requirements().
sub __perl_requirements_setup {
    my ( $self ) = @_;
    return {
	introduced	=> $self->perl_version_introduced(),
	removed		=> $self->perl_version_removed(),
    };
}

=head2 ancestor_of

This method returns true if the object is an ancestor of the argument,
and false otherwise. By the definition of this method, C<$self> is its
own ancestor.

=cut

sub ancestor_of {
    my ( $self, $elem ) = @_;
    __instance( $elem, __PACKAGE__ ) or return;
    my $addr = refaddr( $self );
    while ( $addr != refaddr( $elem ) ) {
	$elem = $elem->_parent() or return;
    }
    return 1;
}

=head2 can_be_quantified

 $token->can_be_quantified()
     and print "This element can be quantified.\n";

This method returns true if the element can be quantified.

=cut

sub can_be_quantified { return 1; }

=head2 class

This method returns the class name of the element. It is the same as
C<ref $self>.

=cut

sub class : method {	## no critic (ProhibitBuiltinHomonyms)
    my ( $self ) = @_;
    return ref $self;
}

=head2 column_number

This method returns the column number of the first character in the
element, or C<undef> if that can not be determined.

=cut

sub column_number {
    my ( $self ) = @_;
    return ( $self->location() || [] )->[LOCATION_CHARACTER];
}

=head2 comment

This method returns true if the element is a comment and false
otherwise.

=cut

sub comment {
    return;
}

=head2 content

This method returns the content of the element.

=cut

sub content {
    return;
}

=head2 descendant_of

This method returns true if the object is a descendant of the argument,
and false otherwise. By the definition of this method, C<$self> is its
own descendant.

=cut

sub descendant_of {
    my ( $self, $node ) = @_;
    __instance( $node, __PACKAGE__ ) or return;
    return $node->ancestor_of( $self );
}

=head2 explain

This method returns a brief explanation of what the element does. The
return will be either a string or C<undef> in scalar context, but may be
multiple values or an empty array in list context.

This method should be considered experimental. What it returns may
change without notice as my understanding of what all the pieces/parts
of a Perl regular expression evolves. The worst case is that it will
prove entirely infeasible to implement satisfactorily, in which case it
will be put through a deprecation cycle and retracted.

=cut

sub explain {
    my ( $self ) = @_;
    defined $self->{explanation}
	and return $self->{explanation};
    my $explanation = $self->__explanation();
    my $content = $self->content();
    if ( my $main = $self->main_structure() ) {
	my $delim = $main->delimiters();
	$delim = qr{ \\ (?= [\Q$delim\E] ) }smx;
	$content =~ s/$delim//smxg;
    }
    if ( defined( my $splain = $explanation->{$content} ) ) {
	return $splain;
    }
    return $self->__no_explanation();
}

# Return explanation hash
sub __explanation {
    $PPIx::Regexp::NO_EXPLANATION_FATAL
	and confess 'Neither explain() nor __explanation() overridden';
    return {};
}

# Called if no explanation available
sub __no_explanation {
##  my ( $self ) = @_;		# Invocant unused
    my $msg = sprintf q<No explanation>;
    $PPIx::Regexp::NO_EXPLANATION_FATAL
	and confess $msg;
    return $msg;
}

=head2 error

 say $token->error();

If an element is one of the classes that represents a parse error, this
method B<may> return a brief message saying why. Otherwise it will
return C<undef>.

=cut

sub error {
    my ( $self ) = @_;
    return $self->{error};
}

=begin comment

=head2 first_element

This method throws an exception saying that it must be overridden.

=end comment

=cut

sub first_element {
    confess 'Bug - first_element must be overridden';
}

=begin comment

=head2 first_token

This method throws an exception saying that it must be overridden.

=end comment

=cut

sub first_token {
    confess 'Bug - first_token must be overridden';
}

=head2 is_matcher

This method reports on whether the element potentially matches
something. Possible returns are a true value if it does, a false (but
defined) value if it does not, or C<undef> if this can not be
determined.

The idea is to classify elements based on whether they potentially match
something in the target string.

This method is overridden to return C<undef> in
L<PPIx::Regexp::Token::Code|PPIx::Regexp::Token::Code/is_matcher>,
L<PPIx::Regexp::Token::Interpolation|PPIx::Regexp::Token::Interpolation/is_matcher>, and
L<PPIx::Regexp::Token::Unknown|PPIx::Regexp::Token::Unknown/is_matcher>.

This method is overridden to return a true value in
L<PPIx::Regexp::Token::Assertion|PPIx::Regexp::Token::Assertion/is_matcher>,
L<PPIx::Regexp::Token::CharClass|PPIx::Regexp::Token::CharClass/is_matcher>,
L<PPIx::Regexp::Token::Literal|PPIx::Regexp::Token::Literal/is_matcher>,
and
L<PPIx::Regexp::Token::Reference|PPIx::Regexp::Token::Reference/is_matcher>.

For L<PPIx::Regexp::Node|PPIx::Regexp::Node/is_matcher>, this method is
overridden to return a value computed from the node's children.

For anything else this method returns a false (but defined) value.

=cut

sub is_matcher { return 0; }

# NOTE retracted this as a public method until I can investigate whether
# the tokenizer can actually produce nested assertions.

#=head2 in_assertion
#
#This method returns an array of assertions that contain the element,
#most-local first. For the purpose of this method, a look-around
#structure does not contain itself. If called in scalar context you get
#the size of the array.
#
#This method was added in version 0.075_01.
#
#=cut

sub __in_assertion {
    my ( $self ) = @_;
    my $elem = $self;
    my @assertions;
    while ( $elem = $elem->parent() ) {
	$elem->isa( 'PPIx::Regexp::Structure::Assertion' )
	    and push @assertions, $elem;
    }
    return @assertions;
}

# Convenience method that returns the number of look-behind
# assertions that contain the current element. This is really only
# here so it can be shared between PPIx::Regexp::Token::Quantifier
# and PPIx::Regexp::Structure::Quantifier

sub __in_look_behind {
    my ( $self ) = @_;
    my @look_behind;
    foreach my $assertion ( $self->__in_assertion() ) {
	$assertion->is_look_ahead()
	    and next;
	push @look_behind, $assertion;
    }
    return @look_behind;
}

=head2 in_regex_set

This method returns a true value if the invocant is contained in an
extended bracketed character class (also known as a regex set), and a
false value otherwise. This method returns true if the invocant is a
L<PPIx::Regexp::Structure::RegexSet|PPIx::Regexp::Structure::RegexSet>.

=cut

sub in_regex_set {
    my ( $self ) = @_;
    my $ele = $self;
    while ( 1 ) {
	$ele->isa( 'PPIx::Regexp::Structure::RegexSet' )
	    and return 1;
	$ele = $ele->parent()
	    or last;
    }
    return 0;
}

=head2 is_quantifier

 $token->is_quantifier()
     and print "This element is a quantifier.\n";

This method returns true if the element is a quantifier. You can not
tell this from the element's class, because a right curly bracket may
represent a quantifier for the purposes of figuring out whether a
greediness token is possible.

=cut

sub is_quantifier { return; }

=begin comment

=head2 last_element

This method throws an exception saying that it must be overridden.

=end comment

=cut

sub last_element {
    confess 'Bug - last_element must be overridden';
}

=begin comment

=head2 last_token

This method throws an exception saying that it must be overridden.

=end comment

=cut

sub last_token {
    confess 'Bug - last_token must be overridden';
}

=head2 line_number

This method returns the line number of the first character in the
element, or C<undef> if that can not be determined.

=cut

sub line_number {
    my ( $self ) = @_;
    return ( $self->location() || [] )->[LOCATION_LINE];
}

=head2 location

This method returns a reference to an array describing the position of
the element in the regular expression, or C<undef> if locations were not
indexed.

The array is compatible with the corresponding
L<PPI::Element|PPI::Element> method.

=cut

sub location {
    my ( $self ) = @_;
    return $self->{location} ? [ @{ $self->{location} } ] : undef;
}

=pod

=head2 logical_filename

This method returns the logical file name (taking C<#line> directives
into account) of the file containing first character in the element, or
C<undef> if that can not be determined.

=cut

sub logical_filename {
    my ( $self ) = @_;
    return ( $self->location() || [] )->[LOCATION_LOGICAL_FILE];
}

=head2 logical_line_number

This method returns the logical line number (taking C<#line> directives
into account) of the first character in the element, or C<undef> if that
can not be determined.

=cut

sub logical_line_number {
    my ( $self ) = @_;
    return ( $self->location() || [] )->[LOCATION_LOGICAL_LINE];
}

=head2 main_structure

This method returns the
L<PPIx::Regexp::Structure::Main|PPIx::Regexp::Structure::Main> that
contains the element. In practice this will be a
L<PPIx::Regexp::Structure::Regexp|PPIx::Regexp::Structure::Regexp> or a
L<PPIx::Regexp::Structure::Replacement|PPIx::Regexp::Structure::Replacement>,

If the element is not contained in any such structure, C<undef> is
returned. This will happen if the element is a
L<PPIx::Regexp|PPIx::Regexp> or one of its immediate children.

=cut

sub main_structure {
    my ( $self ) = @_;
    while ( $self = $self->parent()
	    and not $self->isa( 'PPIx::Regexp::Structure::Main' ) ) {
    }
    return $self;
}

=head2 modifier_asserted

 $token->modifier_asserted( 'i' )
     and print "Matched without regard to case.\n";

This method returns true if the given modifier is in effect for the
element, and false otherwise.

What it does is to walk backwards from the element until it finds a
modifier object that specifies the modifier, whether asserted or
negated. and returns the specified value. If nobody specifies the
modifier, it returns C<undef>.

This method will not work reliably if called on tokenizer output.

=cut

sub modifier_asserted {
    my ( $self, $modifier ) = @_;

    defined $modifier
	or croak 'Modifier must be defined';

    my $elem = $self;

    while ( $elem ) {
	if ( $elem->can( '__ducktype_modifier_asserted' ) ) {
	    my $val;
	    defined( $val = $elem->__ducktype_modifier_asserted( $modifier ) )
		and return $val;
	}
	if ( my $prev = $elem->sprevious_sibling() ) {
	    $elem = $prev;
	} else {
	    $elem = $elem->parent();
	}
    }

    return;
}

=head2 next_element

This method returns the next element, or nothing if there is none.

Unlike L<next_sibling()|/next_sibling>, this will cross from the content
of a structure into the elements that define the structure, or vice
versa.

=cut

sub next_element {
    my ( $self ) = @_;
    my $parent = $self->_parent()
	or return;
    my $inx = $self->__my_inx();
    return ( $parent->elements() )[ $inx + 1 ];
}

=head2 next_sibling

This method returns the element's next sibling, or nothing if there is
none.

=cut

sub next_sibling {
    my ( $self ) = @_;
    my ( $method, $inx ) = $self->__my_nav()
	or return;
    return $self->_parent()->$method( $inx + 1 );
}

=head2 next_token

This method returns the next token, or nothing if there is none.

Unlike L<next_element()|/next_element>, this will walk the parse tree.

=cut

sub next_token {
    my ( $self ) = @_;
    if ( my $next = $self->next_element() ) {
	return $next->first_token();
    } elsif ( my $parent = $self->parent() ) {
	return $parent->next_token();
    } else {
	return;
    }
}

=head2 parent

This method returns the parent of the element, or undef if there is
none.

=cut

sub parent {
    my ( $self ) = @_;
    return $self->_parent();
}

=head2 perl_version_introduced

This method returns the version of Perl in which the element was
introduced. This will be at least 5.000. Before 5.006 I am relying on
the F<perldelta>, F<perlre>, and F<perlop> documentation, since I have
been unable to build earlier Perls. Since I have found no documentation
before 5.003, I assume that anything found in 5.003 is also in 5.000.

Since this all depends on my ability to read and understand masses of
documentation, the results of this method should be viewed with caution,
if not downright skepticism.

There are also cases which are ambiguous in various ways. For those see
the L<PPIx::Regexp|PPIx::Regexp> documentation, particularly
L<Changes in Syntax|PPIx::Regexp/Changes in Syntax>.

Very occasionally, a construct will be removed and then added back. If
this happens, this method will return the B<lowest> version in which the
construct appeared. For the known instances of this, see
the L<PPIx::Regexp|PPIx::Regexp> documentation, particularly
L<Equivocation|PPIx::Regexp/Equivocation>.

=cut

sub perl_version_introduced {
    return MINIMUM_PERL;
}

=head2 perl_version_removed

This method returns the version of Perl in which the element was
removed. If the element is still valid the return is C<undef>.

All the I<caveats> to
L<perl_version_introduced()|/perl_version_introduced> apply here also,
though perhaps less severely since although many features have been
introduced since 5.0, few have been removed.

Very occasionally, a construct will be removed and then added back. If
this happens, this method will return the C<undef> if the construct is
present in the highest-numbered version of Perl (whether production or
development), or the version after the highest-numbered version in which
it appeared otherwise. For the known instances of this, see the
L<PPIx::Regexp|PPIx::Regexp> documentation, particularly
L<Equivocation|PPIx::Regexp/Equivocation>.

=cut

sub perl_version_removed {
    return undef;	## no critic (ProhibitExplicitReturnUndef)
}

=head2 previous_element

This method returns the previous element, or nothing if there is none.

Unlike L<previous_sibling()|/previous_sibling>, this will cross from
the content of a structure into the elements that define the structure,
or vice versa.

=cut

sub previous_element {
    my ( $self ) = @_;
    my $parent = $self->_parent()
	or return;
    my $inx = $self->__my_inx()
	or return;
    return ( $parent->elements() )[ $inx - 1 ];
}

=head2 previous_sibling

This method returns the element's previous sibling, or nothing if there
is none.

This method is analogous to the same-named L<PPI::Element|PPI::Element>
method, in that it will not cross from the content of a structure into
the elements that define the structure.

=cut

sub previous_sibling {
    my ( $self ) = @_;
    my ( $method, $inx ) = $self->__my_nav()
	or return;
    $inx or return;
    return $self->_parent()->$method( $inx - 1 );
}

=head2 previous_token

This method returns the previous token, or nothing if there is none.

Unlike L<previous_element()|/previous_element>, this will walk the parse tree.

=cut

sub previous_token {
    my ( $self ) = @_;
    if ( my $previous = $self->previous_element() ) {
	return $previous->last_token();
    } elsif ( my $parent = $self->parent() ) {
	return $parent->previous_token();
    } else {
	return;
    }
}

=head2 raw_width

 my ( $raw_min, $raw_max ) = $self->raw_width();

This public method returns the minimum and maximum width matched by the
element before taking into account such details as what the element
actually is and how it is quantified. Either or both elements can be
C<undef> if the width can not be determined, and the maximum can be
C<Inf>.

This method was added in version 0.085_01.

=cut

# This implementation is appropriate to a structural element -- i.e. it
# returns C<( 0, 0 )>.

sub raw_width {
    return ( 0, 0 );
}

=head2 remove_insignificant

This method returns a new object manufactured from the invocant, but
containing only elements for which C<< $elem->significant() >> returns a
true value.

If you call this method on a L<PPIx::Regexp::Node|PPIx::Regexp::Node>
you will get back a deep clone, but without the insignificant elements.

If you call this method on any other L<PPIx::Regexp|PPIx::Regexp> class
you will get back either the invocant or nothing. This may change to a
clone of the invocant or nothing if unforeseen problems arise with
returning the invocant, or if objects become mutable (unlikely, but not
impossible.)

=cut

sub remove_insignificant {
    my ( $self ) = @_;
    $self->significant()
	and return $self;
    return;
}

=head2 requirements_for_perl

 say $token->requirements_for_perl();

This method returns a string representing the Perl requirements for a
given module. This should only be used for informational purposes, as
the format of the string may be subject to change.

At the moment, the returns may be:

 version <= $]
 version <= $] < version
 two or more of the above joined by '||'
 ! $]

The last means that, although all the components of the regular
expression can be compiled by B<some> version of Perl, there is no
version that will compile all of them.

I reiterate: the returned string may be subject to change, maybe without
warning.

This method was added in version 0.051_01.

=cut

sub requirements_for_perl {
    my ( $self ) = @_;
    my @req;
    foreach my $r ( $self->__perl_requirements() ) {
	push @req, defined $r->{removed} ?
	"$r->{introduced} <= \$] < $r->{removed}" :
	"$r->{introduced} <= \$]";
    }
    @req
	or return '! $]';
    return join ' || ', @req;
}

=head2 scontent

This method returns the significant content of the element. That is, if
called on the parse of C<'/ f u b a r /x'>, it returns C<'/fubar/x'>. If
the invocant contains no insignificant elements, it is the same as
L<content()|/content>. If called on an insignificant element, it returns
nothing -- that is, C<undef> in scalar context, and an empty list in
list context.

This method was inspired by jb's question on Perl Monks about stripping
comments and white space from a regular expression:
L<https://www.perlmonks.org/?node_id=1207556>

This method was added in version 0.053_01

=cut

sub scontent {
    return;
}

=head2 significant

This method returns true if the element is significant and false
otherwise.

=cut

sub significant {
    return 1;
}

=head2 snext_element

This method returns the next significant element, or nothing if
there is none.

Unlike L<snext_sibling()|/snext_sibling>, this will cross from
the content of a structure into the elements that define the structure,
or vice versa.

=cut

sub snext_element {
    my ( $self ) = @_;
    my $inx = $self->__my_inx();
    my $parent = $self->_parent()
	or return;
    my @elem = $parent->elements();
    while ( 1 ) {
	$inx++;
	$elem[$inx]
	    or last;
	$elem[$inx]->significant()
	    and return $elem[$inx];
    }
    return;
}

=head2 snext_sibling

This method returns the element's next significant sibling, or nothing
if there is none.

This method is analogous to the same-named L<PPI::Element|PPI::Element>
method, in that it will not cross from the content of a structure into
the elements that define the structure.

=cut

sub snext_sibling {
    my ( $self ) = @_;
    my $sib = $self;
    while ( defined ( $sib = $sib->next_sibling() ) ) {
	$sib->significant() and return $sib;
    }
    return;
}

=head2 sprevious_element

This method returns the previous significant element, or nothing if
there is none.

Unlike L<sprevious_sibling()|/sprevious_sibling>, this will cross from
the content of a structure into the elements that define the structure,
or vice versa.

=cut

sub sprevious_element {
    my ( $self ) = @_;
    my $inx = $self->__my_inx()
	or return;
    my $parent = $self->_parent()
	or return;
    my @elem = $parent->elements();
    while ( $inx ) {
	$elem[--$inx]->significant()
	    and return $elem[$inx];
    }
    return;
}

=head2 sprevious_sibling

This method returns the element's previous significant sibling, or
nothing if there is none.

This method is analogous to the same-named L<PPI::Element|PPI::Element>
method, in that it will not cross from the content of a structure into
the elements that define the structure.

=cut

sub sprevious_sibling {
    my ( $self ) = @_;
    my $sib = $self;
    while ( defined ( $sib = $sib->previous_sibling() ) ) {
	$sib->significant() and return $sib;
    }
    return;
}

=head2 statement

This method returns the L<PPI::Statement|PPI::Statement> that contains
this element, or nothing if the statement can not be determined.

In general this method will return something only under the following
conditions:

=over

=item * The element is contained in a L<PPIx::Regexp|PPIx::Regexp> object;

=item * That object was initialized from a L<PPI::Element|PPI::Element>;

=item * The L<PPI::Element|PPI::Element> is contained in a statement.

=back

=cut

sub statement {
    my ( $self ) = @_;
    my $top = $self->top()
	or return;
    $top->can( 'source' )
	or return;
    my $source = $top->source()
	or return;
    $source->can( 'statement' )
	or return;
    return $source->statement();
}

=head2 tokens

This method returns all tokens contained in the element.

=cut

sub tokens {
    my ( $self ) = @_;
    return $self;
}

=head2 top

This method returns the top of the hierarchy.

=cut

sub top {
    my ( $self ) = @_;
    my $kid = $self;
    while ( defined ( my $parent = $kid->_parent() ) ) {
	$kid = $parent;
    }
    return $kid;
}

=head2 unescaped_content

This method returns the content of the element, unescaped.

=cut

sub unescaped_content {
    return;
}

=head2 visual_column_number

This method returns the visual column number (taking tabs into account)
of the first character in the element, or C<undef> if that can not be
determined.

=cut

sub visual_column_number {
    my ( $self ) = @_;
    return ( $self->location() || [] )->[LOCATION_COLUMN];
}

=head2 whitespace

This method returns true if the element is whitespace and false
otherwise.

=cut

sub whitespace {
    return;
}

=head2 width

 my ( $min, $max ) = $self->width();

This method returns the minimum and maximum number of characters this
element can match.

Either element can be C<undef> if it cannot be determined. For example,
for C</$foo/> both elements will be C<undef>.  Recursions will return
C<undef> because they can not be analyzed statically -- or at least I am
not smart enough to do so. Back references B<may> return C<undef> if the
referred-to group can not be uniquely determined.

It is possible for C<$max> to be C<Inf>. For example, for C</x*/>
C<$max> will be C<Inf>.

Elements that do not actually match anything will return zeroes.

B<Note:> This method was added because I wanted better detection of
variable-length look-behinds. Both it and L<raw_width()|/raw_width>
(above) should be considered somewhat experimental.

This method was added in version 0.085_01.

=cut

sub width {
    return ( 0, 0 );
}

=head2 nav

This method returns navigation information from the top of the hierarchy
to this node. The return is a list of names of methods and references to
their argument lists. The idea is that given C<$elem> which is somewhere
under C<$top>,

 my @nav = $elem->nav();
 my $obj = $top;
 while ( @nav ) {
     my $method = shift @nav;
     my $args = shift @nav;
     $obj = $obj->$method( @{ $args } ) or die;
 }
 # At this point, $obj should contain the same object
 # as $elem.

=cut

sub nav {
    my ( $self ) = @_;
    __instance( $self, __PACKAGE__ ) or return;

    # We do not use $self->parent() here because PPIx::Regexp overrides
    # this to return the (possibly) PPI object that initiated us.
    my $parent = $self->_parent() or return;

    return ( $parent->nav(), $parent->__nav( $self ) );
}

# Find our index among the parents children. If not found, just return.
# Unlike __my_nav(), this just returns an index, which is appropriate
# for ->element( $inx ), or would be if element() existed.

sub __my_inx {
    my ( $self ) = @_;
    my $parent = $self->_parent() or return;
    my $addr = refaddr( $self );
    my @elem = $parent->elements();
    return first { refaddr( $elem[$_] ) == $addr } 0 .. $#elem;
}

# Find our location and index among the parent's children. If not found,
# just returns.

{
    my %method_map = (
	children => 'child',
    );

    sub __my_nav {
	my ( $self ) = @_;
	my $parent = $self->_parent() or return;
	my $addr = refaddr( $self );
	foreach my $method ( qw{ children start type finish } ) {
	    $parent->can( $method ) or next;
	    my @elem = $parent->$method();
	    defined( my $inx = first { refaddr( $elem[$_] ) == $addr }
		0 .. $#elem )
		or next;
	    return ( $method_map{$method} || $method, $inx );
	}
	return;
    }
}

{
    my %parent;

    # no-argument form returns the parent; one-argument sets it.
    sub _parent {
	my ( $self, @arg ) = @_;
	my $addr = refaddr( $self );
	if ( @arg ) {
	    my $parent = shift @arg;
	    if ( defined $parent ) {
		__instance( $parent, __PACKAGE__ ) or return;
		weaken(
		    $parent{$addr} = $parent );
	    } else {
		delete $parent{$addr};
	    }
	}
	return $parent{$addr};
    }

    sub __parent_keys {
	return scalar keys %parent;
    }

}

# Bless into TOKEN_UNKNOWN, record error message, return 1.
sub __error {
    my ( $self, $msg ) = @_;
    defined $msg
	or $msg = 'Was ' . ref $self;
    TOKEN_UNKNOWN->__PPIX_ELEM__rebless( $self, error => $msg );
    return 1;
}

# This huge kluge is required by
# https://rt.perl.org/Ticket/Display.html?id=128213 which means the
# deprecation will be done in at least two separate phases. It exists
# for the use of PPIx::Regexp::Token::Literal->perl_version_removed, and
# MUST NOT be called by any other code.
# Note that the perldelta for 5.25.1 and 5.26.0 do not acknowledge tha
# phased deprecation, and pretend that everything was done on the phase
# 1 schedule. This appears to be deliberate per
# https://rt.perl.org/Ticket/Display.html?id=131352
sub __following_literal_left_curly_disallowed_in {
    return LITERAL_LEFT_CURLY_REMOVED_PHASE_1;
}

# Called by the lexer to record the capture number.
sub __PPIX_LEXER__record_capture_number {
    my ( undef, $number ) = @_;		# Invocant unused
    return $number;
}

# Called by the lexer to rebless
sub __PPIX_ELEM__rebless {
    my ( $class, $self, %arg ) = @_;
    $self ||= {};
    bless $self, $class;
    delete $self->{error};
    return $self->__PPIX_ELEM__post_reblessing( %arg );
}

sub __PPIX_ELEM__post_reblessing {
    return 0;
}

sub DESTROY {
    $_[0]->_parent( undef );
    return;
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
