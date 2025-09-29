=head1 NAME

PPIx::Regexp::Token::Unknown - Represent an unknown token

=head1 SYNOPSIS

 use PPIx::Regexp::Dumper;
 PPIx::Regexp::Dumper->new( 'xyzzy' )
     ->print();

=head1 INHERITANCE

C<PPIx::Regexp::Token::Unknown> is a
L<PPIx::Regexp::Token|PPIx::Regexp::Token>.

C<PPIx::Regexp::Token::Unknown> has no descendants.

=head1 DESCRIPTION

This token represents something that could not be identified by the
tokenizer. Sometimes the lexer can fix these up, but the presence of one
of these in a finished parse represents something in the regular
expression that was not understood.

=head1 METHODS

This class provides the following public methods. Methods not documented
here are private, and unsupported in the sense that the author reserves
the right to change or remove them without notice.

=cut

package PPIx::Regexp::Token::Unknown;

use strict;
use warnings;

use base qw{ PPIx::Regexp::Token };

use Carp ();
use PPIx::Regexp::Constant qw{ @CARP_NOT };
use PPIx::Regexp::Util;

our $VERSION = '0.090_02';

sub __new {
    my ( $class, $content, %arg ) = @_;

    defined $arg{error}
	or Carp::confess( 'Programming error - error argument required' );

    my $self = $class->SUPER::__new( $content, %arg )
	or return;

    $self->{error} = $arg{error};

    $self->{explanation} = defined $arg{explanation} ?
	$arg{explanation} :
	$arg{error};

    return $self;
}

# Return true if the token can be quantified, and false otherwise
sub can_be_quantified { return };

sub explain {
    my ( $self ) = @_;
    return $self->{explanation};
}

=head2 is_matcher

This method returns C<undef> because, since we could not identify the
token, we have no idea whether it matches anything.

=cut

sub is_matcher { return undef; }	## no critic (ProhibitExplicitReturnUndef)

=head2 ordinal

This method returns the results of the ord built-in on the content
(meaning, of course, the first character of the content). No attempt is
made to interpret the content, since after all this B<is> the unknown
token.

=cut

sub ordinal {
    my ( $self ) = @_;
    return ord $self->content();
}

sub width {
    return ( undef, undef );
}

*__PPIX_ELEM__post_reblessing = \&PPIx::Regexp::Util::__post_rebless_error;

# Since the lexer does not count these on the way in (because it needs
# the liberty to rebless them into a known class if it figures out what
# is going on) we count them as failures at the finalization step.
sub __PPIX_LEXER__finalize {
    return 1;
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
