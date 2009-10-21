=head1 NAME

PPIx::Regexp - Represent a regular expression of some sort

=head1 SYNOPSIS

 use PPIx::Regexp;
 use PPIx::Regexp::Dumper;
 my $re = PPIx::Regexp->new( 'qr{foo}smx' );
 PPIx::Regexp::Dumper->new( $re )
     ->print();

=head1 INHERITANCE

C<PPIx::Regexp> is a L<PPIx::Regexp::Node|PPIx::Regexp::Node>.

C<PPIx::Regexp> has no descendants.

=head1 DESCRIPTION

The purpose of the F<PPIx-Regexp> package is to parse regular
expressions in a manner similar to the way the L<PPI|PPI> package parses
Perl. This class forms the root of the parse tree, playing a role
similar to L<PPI::Document|PPI::Document>.

Navigation is similar to that provided by L<PPI|PPI>. That is to say,
things like C<children>, C<find_first>, C<snext_sibling> and so on all
work pretty much the same way as in L<PPI|PPI>.

The class hierarchy is also similar to L<PPI|PPI>. Except for some
utility classes (the dumper, the lexer, and the tokenizer) all classes
are descended from L<PPIx::Regexp::Element|PPIx::Regexp::Element>, which
provides basic navigation. Tokens are descended from
L<PPIx::Regexp::Token|PPIx::Regexp::Token>, which provides content. All
containers are descended from L<PPIx::Regexp::Node|PPIx::Regexp::Node>,
which provides for children, and all structure elements are descended
from L<PPIx::Regexp::Structure|PPIx::Regexp::Structure>, which provides
beginning and ending delimiters, and a type.

There are two features of L<PPI|PPI> that this package does not provide
- mutability and operator overloading. There are no plans for serious
mutability, though something like L<PPI|PPI>'s C<prune> functionality
might be considered. Similarly there are no plans for operator
overloading, which appears to the author to represent a performance hit
for little tangible gain.

=head1 METHODS

This class provides the following public methods. Methods not documented
here are private, and unsupported in the sense that the author reserves
the right to change or remove them without notice.

=cut

package PPIx::Regexp;

use strict;
use warnings;

use base qw{ PPIx::Regexp::Node };

use Params::Util 0.25 qw{ _INSTANCE };
use PPIx::Regexp::Lexer ();
use Scalar::Util qw{ refaddr };

our $VERSION = '0.000_04';

=head2 new

 my $re = PPIx::Regexp->new('/foo/');

This method instantiates a C<PPIx::Regexp> object from a string, a
L<PPI::Token::QuoteLike::Regexp|PPI::Token::QuoteLike::Regexp>, a
L<PPI::Token::Regexp::Match|PPI::Token::Regexp::Match>, or a
L<PPI::Token::Regexp::Substitute|PPI::Token::Regexp::Substitute>.
Honestly, any L<PPI::Element|PPI::Element> will do, but only the three
Regexp classes mentioned previously are likely to do anything useful.

=cut

{

    my $errstr;

    sub new {
	my ( $class, $content, %args ) = @_;
	ref $class and $class = ref $class;

	$errstr = undef;

	my $tokenizer = PPIx::Regexp::Tokenizer->new(
	    $content, %args ) or do {
	    $errstr = PPIx::Regexp::Tokenizer->errstr();
	    return;
	};

	my $lexer = PPIx::Regexp::Lexer->new( $tokenizer, %args );
	my @nodes = $lexer->lex();
	my $self = $class->SUPER::_new( @nodes );
	$self->{source} = $content;
	$self->{failures} = $lexer->failures();
	return $self;
    }

    sub errstr {
	return $errstr;
    }

}

=head2 new_from_cache

This static method wraps L</new> in a caching mechanism. Only one object
will be generated for a given L<PPI::Element|PPI::Element>, no matter
how many times this method is called. Calls after the first for a given
L<PPI::Element|PPI::ELement> simply return the same C<PPIx::Regexp>
object.

When the C<PPIx::Regexp> object is returned from cache, the values of
the optional arguments are ignored.

Calls to this method with the regular expression in a string rather than
a L<PPI::Element|PPI::Element> will not be cached.

B<Caveat:> This method is provided for code like
L<Perl::Critic|Perl::Critic> which might instantiate the same object
multiple times. The cache will persist until L</flush_cache> is called.

=head2 flush_cache

 $re->flush_cache();            # Remove $re from cache
 PPIx::Regexp->flush_cache();   # Empty the cache

This method flushes the cache used by L</new_from_cache>. If called as a
static method with no arguments, the entire cache is emptied. Otherwise
any objects specified are removed from the cache.

=cut

{

    my %cache;

    sub _cache_size {
	return scalar keys %cache;
    }

    sub new_from_cache {
	my ( $class, $content, %args ) = @_;

	_INSTANCE( $content, 'PPI::Element' )
	    or return $class->new( $content, %args );

	my $addr = refaddr( $content );
	exists $cache{$addr} and return $cache{$addr};

	my $self = $class->new( $content, %args )
	    or return;

	$cache{$addr} = $self;

	return $self;

    }

    sub flush_cache {
	my @args = @_;

	ref $args[0] or shift @args;

	if ( @args ) {
	    foreach my $obj ( @args ) {
		if ( _INSTANCE( ( my $parent = $obj->parent() ),
			'PPI::Element' ) ) {
		    delete $cache{ refaddr( $parent ) };
		}
	    }
	} else {
	    %cache = ();
	}
	return;
    }

}


=head2 capture_names

 foreach my $name ( $re->capture_names() ) {
     print "Capture name '$name'\n";
 }

This convenience method returns the capture names found in the regular
expression.

This method is equivalent to

 $self->regular_expression()->capture_names();

except that if C<< $self->regular_expression() >> returns C<undef>
(meaning that something went terribly wrong with the parse) this method
will simply return.

=cut

sub capture_names {
    my ( $self ) = @_;
    my $re = $self->regular_expression() or return;
    return $re->capture_names();
}

=head2 errstr

This static method returns the error string from the most recent attempt
to instantiate a C<PPIx::Regexp>. It will be C<undef> if the most recent
attempt succeeded.

=cut

# defined above, just after sub new.

=head2 failures

 print "There were ", $re->failures(), " parse failures\n";

This method returns the number of parse failures. This is a count of the
number of unknown tokens plus the number of unterminated structures plus
the number of unmatched right brackets of any sort.

=cut

sub failures {
    my ( $self ) = @_;
    return $self->{failures};
}

=head2 max_capture_number

 print "Highest used capture number ",
     $re->max_capture_number(), "\n";

This convenience method returns the highest capture number used by the
regular expression. If there are no captures, the return will be 0.

This method is equivalent to

 $self->regular_expression()->max_capture_number();

except that if C<< $self->regular_expression() >> returns C<undef>
(meaning that something went terribly wrong with the parse) this method
will too.

=cut

sub max_capture_number {
    my ( $self ) = @_;
    my $re = $self->regular_expression() or return;
    return $re->max_capture_number();
}

=head2 modifier

 my $re = PPIx::Regexp->new( 's/(foo)/${1}bar/smx' );
 print $re->modifier()->content(), "\n";
 # prints 'smx'.

This method retrieves the modifier of the object. This comes from the
end of the initializing string or object and will be a
L<PPIx::Regexp::Token::Modifier|PPIx::Regexp::Token::Modifier>.

In the event of a parse failure, there may not be a modifier present, in
which case nothing is returned.

=cut

sub modifier {
    my ( $self ) = @_;
    return $self->_component( 'PPIx::Regexp::Token::Modifier' );
}

=head2 regular_expression

 my $re = PPIx::Regexp->new( 's/(foo)/${1}bar/smx' );
 print $re->regular_expression()->content(), "\n";
 # prints '/(foo)/'.

This method returns that portion of the object which actually represents
a regular expression.

=cut

sub regular_expression {
    my ( $self ) = @_;
    return $self->_component( 'PPIx::Regexp::Structure::Regexp' );
}

=head2 replacement

 my $re = PPIx::Regexp->new( 's/(foo)/${1}bar/smx' );
 print $re->replacement()->content(), "\n";
 # prints '${1}bar/'.

This method returns that portion of the object which represents the
replacement string. This will be C<undef> unless the regular expression
actually has a replacement string. Delimiters will be included, but
there will be no beginning delimiter unless the regular expression was
bracketed.

=cut

sub replacement {
    my ( $self ) = @_;
    return $self->_component( 'PPIx::Regexp::Structure::Replacement' );
}

=head2 source

 my $source = $re->source();

This method returns the object or string that was used to instantiate
the object.

=cut

sub source {
    my ( $self ) = @_;
    return $self->{source};
}

=head2 type

 my $re = PPIx::Regexp->new( 's/(foo)/${1}bar/smx' );
 print $re->type()->content(), "\n";
 # prints 's'.

This method retrieves the type of the object. This comes from the
beginning of the initializing string or object, and will be a
L<PPIx::Regexp::Token::Structure|PPIx::Regexp::Token::Structure>
whose C<content> is one of 's',
'm', 'qr', or ''.

=cut

sub type {
    my ( $self ) = @_;
    return $self->_component( 'PPIx::Regexp::Token::Structure' );
}

sub _component {
    my ( $self, $class ) = @_;
    foreach my $elem ( $self->children() ) {
	$elem->isa( $class ) and return $elem;
    }
    return;
}

1;

__END__

=head1 RESTRICTIONS

By the nature of this module, it is never going to get everything right.
Many of the known problem areas involve interpolations one way or
another.

=head2 Ambiguous Syntax

Perl's regular expressions contain cases where the syntax is ambiguous.
A particularly egregious example is an interpolation followed by square
or curly brackets, for example C<$foo[...]>. There is nothing in the
syntax to say whether the programmer wanted to interpolate an element of
array C<@foo>, or whether he wanted to interpolate scalar C<$foo>, and
then follow that interpolation by a character class.

The F<perlop> documentation notes that in this case what Perl does is to
guess. That is, it employs various heuristics on the code to try to
figure out what the programmer wanted. These heuristics are documented
as being undocumented (!) and subject to change without notice.

Given this situation, this module's chances of duplicating every Perl
version's interpretation of every regular expression are pretty much nil.
What it does now is to assume that square brackets containing B<only> an
integer or an interpolation represent a subscript; otherwise they
represent a character class. Similarly, curly brackets containing
B<only> a bareword or an interpolation are a subscript; otherwise they
represent a quantifier.

=head2 Static Parsing

It is well known that Perl can not be statically parsed. That is, you
can not completely parse a piece of Perl code without executing that
same code.

Nevertheless, this class is trying to statically parse regular
expressions. The main problem with this is that there is no way to know
what is being interpolated into the regular expression by an
interpolated variable. This is a problem because the interpolated value
can change the interpretation of adjacent elements.

This module deals with this by making assumptions about what is in an
interpolated variable. These assumptions will not be enumerated here,
but in general the principal is to assume the interpolated value does
not change the interpretation of the regular expression. For example,

 my $foo = 'a-z]';
 my $re = qr{[$foo};

is fine with the Perl interpreter, but will confuse the dickens out of
this module. Similarly and more usefully, something like

 my $mods = 'i';
 my $re = qr{(?$mods:foo)};

or maybe

 my $mods = 'i';
 my $re = qr{(?$mods)$foo};

probably sets a modifier of some sort, and that is how this module
interprets it. If the interpolation is B<not> about modifiers, this
module will get it wrong. Another such semi-benign example is

 my $foo = $] >= 5.010 ? '?<foo>' : '';
 my $re = qr{($foo\w+)};

which will parse, but this module will never realize that it might be
looking at a named capture.

=head2 Non-Standard Syntax

There are modules out there that alter the syntax of Perl. If the syntax
of a regular expression is altered, this module has no way to understand
that it has been altered, much less to adapt to the alteration. The
following modules are known to cause problems:

L<Acme::PerlML|Acme::PerlML>, which renders Perl as XML.

L<Data::PostfixDeref|Data::PostfixDeref>, which causes Perl to interpret
suffixed empty brackets as dereferencing the thing they suffix.

L<Filter::Trigraph|Filter::Trigraph>, which recognizes ANSI C trigraphs,
allowing Perl to be written in the ISO 646 character set.

L<Perl6::Pugs|Perl6::Pugs>. Enough said.

L<Perl6::Rules|Perl6::Rules>, which back-ports some of the Perl 6
regular expression syntax to Perl 5.

L<Regexp::Extended|Regexp::Extended>, which extends regular expressions
in various ways, some of which seem to conflict with Perl 5.010.

=head1 SEE ALSO

L<Regexp::Parser|Regexp::Parser>, which parses a bare regular expression
(without enclosing C<qr{}>, C<m//>, or whatever) and uses a different
navigation model.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009, Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
