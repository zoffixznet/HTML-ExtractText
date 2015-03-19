package HTML::ExtractText;

use strict;
use warnings;

# VERSION

use Try::Tiny;
use Carp qw/croak/;
use Devel::TakeHashArgs;
use Mojo::DOM;
use overload q|""|  => sub { shift->error        },
             q|%{}| => sub { shift->last_results };

sub new {
    my $self = bless [], shift;
    get_args_as_hash( \@_, \ my %args,
        {   # these are optional with defaults
            separator        => "\n",
            ignore_not_found => 1,
        },
        [ ], # these are mandatory (none, ATM)
        [ qw/separator ignore_not_found/ ], # only these args are valid ones
    ) or croak $@;

    $self->$_( $args{$_} ) for keys %args;

    return $self;
}

sub extract {
    my ( $self, $what, $html, $obj ) = @_;

    $self->error( undef );
    $self->last_results( undef );

    ref $what eq 'HASH'
        or return $self->_set_error('First argument to '
                . 'extract_text() must be a hashref');

    defined $html
        or return $self->_set_error('Second argument to extract_text() is '
                    . 'an undef, expected HTML');

    my $dom = Mojo::DOM->new( $html );

    my $did_have_error = 0;
    for my $selector ( sort keys %$what ) {
        my $result;

        try {
            my @results
            = $dom->find( $what->{ $selector } )->map('all_text')->each;

            die "NOT FOUND\n"
                if not @results and not $self->ignore_not_found;

            if ( defined (my $sep = $self->separator) ) {
                $result = join $sep, @results;
            }
            else {
                $result = [ @results ];
            }

        } catch {
            chomp($_);
            $self->error("ERROR: [$selector]:  $_");
            $result = "ERROR: $_";
            $did_have_error = 1;
        };

        $what->{ $selector } = $result;
    }

    if ( defined $obj ) {
        for ( keys %$what ) {
            $obj->$_( $what->{ $_ } );
        }
    }

    $self->last_results( $what );

    if ( $did_have_error ) {
        return;
    }
    else {
        return $what;
    }
}

sub separator {
    my $self = shift;
    if ( @_ ) { $self->[0]->{SEPARATOR} = shift; }
    return $self->[0]->{SEPARATOR};
}

sub ignore_not_found {
    my $self = shift;
    if ( @_ ) { $self->[0]->{IGNORE_NOT_FOUND} = shift; }
    return $self->[0]->{IGNORE_NOT_FOUND};
}

sub last_results {
    my $self = shift;
    if ( @_ ) { $self->[0]->{LAST_RESULTS} = shift; }
    return $self->[0]->{LAST_RESULTS};
}

sub error {
    my $self = shift;
    if ( @_ ) { $self->[0]->{ERROR} = shift; }
    return $self->[0]->{ERROR};
}

sub _set_error {
    my ( $self, $error ) = @_;
    $self->error( $error );
    return;
}



q|
Programming is 10% science, 20% ingenuity,
and 70% getting the ingenuity to work with the science.
|;

__END__

=encoding utf8

=for stopwords Znet Zoffix

=head1 NAME

HTML::ExtractText - extra multiple text strings from HTML content, using CSS selectors

=head1 SYNOPSIS

    use HTML::ExtractText;

    my $html_code = <<'END';
        <title>Example Domain</title>
        <p><a href="http://www.iana.org/domains/example">
            More information...</a></p>
    END

    ## The first argument tells the object what we want to extract
    ## The keys what we'll use as keys to retrieve data
    ## And values are CSS selectors specifying elements we want
    my $extractor = HTML::ExtractText->new;
    $extractor->extract(
        {
            title => 'title',
            external_links => 'a:not([href~="example.com"])[href^="http"]',
        },
        $html_code,
    ) or die "Extraction error: $extractor";

    print "Title is: $extractor->{title}\n\n",
        "External links: $extractor->{external_links}\n";


    ## We can also pass an object and HTML::ExtractText will call
    ## methods on it that are the keys of the input hashref.
    ## We can use that to populate the object with data from HTML
    ## (by having HTML::ExtractText call on accessor methods)

    package Foo;
    sub stuff { my $self = shift; print "@_\n"; }

    package main;

    use HTML::ExtractText;

    my $extractor = HTML::ExtractText->new;
    $extractor->extract(
        { stuff => 'title', },
        '<title>My html code!</title>',
        bless {}, 'Foo',
    ) or die "Extraction error: $extractor";

    print "Title is: $extractor->{stuff}\n\n";

=head1 DESCRIPTION

The module allows to extract [multiple] text strings from HTML documents,
using CSS selector to declare what text needs extracting. The module
can either return the results as a hashref or automatically call
setter methods on a provided object.

=head1 OVERLOADED METHODS

    $extractor->extract(
        { stuff => 'title', },
        '<title>My html code!</title>',
        bless {}, 'Foo',
    ) or die "Extraction error: $extractor";

    print "Title is: $extractor->{stuff}\n\n";

The module incorporates two overloaded methods C<< ->error() >>, which
is overloaded for interpolation (q|""|), and C<< ->last_result() >>,
which is overloaded for hash dereferencing (q|%{}|).

What this means is that you can interpolate the object in a string
to retrive the error message and you can use the object as a hashref
to access the hashref returned by C<< ->last_result() >>.

=head1 METHODS

=head2 C<< ->new() >>

    my $extractor = HTML::ExtractText->new;

    my $extractor = HTML::ExtractText->new(
        separator        => "\n",
        ignore_not_found => 1,
    ); # default values for arguments are shown

Creates and returns new C<HTML::ExtractText> object. Takes optional
arguments as key/value pairs:

=head3 C<separator>

    my $extractor = HTML::ExtractText->new(
        separator => "\n", # default value
    );

    my $extractor = HTML::ExtractText->new(
        separator => undef,
    );

B<Optional>. B<Default:> C<\n> (new line).
Takes C<undef> or a string as a value.
Specifies what to do when the CSS selector matches multiple
elements. If set to a string value, text from all the matching
elements will be joined using that string. If set to C<undef>,
no joining will happen and results will be returned as arrayrefs
instead of strings (even if selector matches a single element).

=head3 C<ignore_not_found>

    my $extractor = HTML::ExtractText->new(
        ignore_not_found => 1,  # default value
    );

    my $extractor = HTML::ExtractText->new(
        ignore_not_found => 0,
    );

B<Optional>. B<Default:> C<1> (true). Takes true or false values
as a value. Specifies whether to consider it an error when any
of the given selectors match nothing. If set to a true value,
any non-matching selectors will have empty strings as values and no
errors will be reported. If set to a false value, all selectors must
match at least one element or the module will error out.

=head2 C<< ->extract() >>

    my $results = $extractor->extract(
        { stuff => 'title', },
        '<title>My html code!</title>',
        $some_object, # optional
    ) or die "Extraction error: $extractor";

    print "Title is: $extractor->{stuff}\n\n";
    # $extractor->{stuff} is the same as $results->{stuff}

Takes two mandatory and one optional arguments. Extracts text from
given HTML code and returns a hashref with results (
    see C<< ->last_results() >> method
). On error, returns
C<undef> or empty list and the error will be available via
C<< ->error() >> method.

=head3 first argument

    $extractor->extract(
        { stuff => 'title', },
        ... ,
        ... ,
    ) or die "Extraction error: $extractor";

Must be a hashref. The keys can be whatever you want; you will use them
to refer to the extracted text. The values must be CSS selectors that
match the elements you want to extract text from.
All the selectors listed on
L<https://metacpan.org/pod/Mojo::DOM::CSS#SELECTORS> are supported.

Note: the values will be modified in place, so you can use that
to your advantage, if needed.

=head3 second argument

    $extractor->extract(
        ... ,
        '<title>My html code!</title>',
        ... ,
    ) or die "Extraction error: $extractor";

Takes a string that is HTML code you're trying to extract text from.

=head3 third argument

    $extractor->extract(
        ... ,
        ... ,
        $some_object,
    ) or die "Extraction error: $extractor";

B<Optional>. No defaults. For convenience, you supply an object and
L<HTML::ExtractText> will call methods on it. The called methods
will be the keys of the first argument given to C<< ->extract() >> and
the extracted text will be given to those methods as the first argument.

=head1 C<< ->error >>

    $extractor->extract(
        { stuff => 'title', },
        '<title>My html code!</title>',
    ) or die "Extraction error: " . $extractor->error;

    $extractor->extract(
        { stuff => 'title', },
        '<title>My html code!</title>',
    ) or die "Extraction error: $extractor";

Takes no arguments. Returns the last error message

=head1 SEE ALSO

L<Mojo::DOM>, L<Text::Balanced>, L<HTML::Extract>

=head1 REPOSITORY

Fork this module on GitHub:
L<https://github.com/zoffixznet/HTML-ExtractText>

=head1 BUGS

To report bugs or request features, please use
L<https://github.com/zoffixznet/HTML-ExtractText/issues>

If you can't access GitHub, you can email your request
to C<bug-html-extracttext at rt.cpan.org>

=head1 AUTHOR

Zoffix Znet <zoffix at cpan.org> (L<http://zoffix.com/>

=head1 LICENSE

You can use and distribute this module under the same terms as Perl itself.
See the C<LICENSE> file included in this distribution for complete
details.

=cut