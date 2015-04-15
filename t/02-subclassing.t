#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Deep;

package Test0::Foo;
use parent 'HTML::ExtractText';

our @ReturnData;

sub extra_processing {
    @ReturnData = @{[@_]};
    $ReturnData[4] = {%{$ReturnData[4]}};
}

package main;

my $ext = Test0::Foo->new;
can_ok($ext,
    qw/new  extract  error  last_results  separator
        ignore_not_found extra_processing/
);
isa_ok($ext, 'Test0::Foo');

$ext->extract({foo => 'div'}, '<div>ber</div><p>X<div>boorr</div>');

my ( $obj, $dom ) = (
    splice(@Test0::Foo::ReturnData, 0, 1),
    splice(@Test0::Foo::ReturnData, 1, 1),
);

isa_ok( $obj, 'Test0::Foo' );
isa_ok( $dom, 'Mojo::DOM' );

is $dom->find('p')->map('all_text')->compact->join("\n"),
    'X',
    'Mojo::DOM object is loaded with correct HTML';

cmp_deeply
    \@Test0::Foo::ReturnData,
    [
        [qw/ber  boorr/],
        'foo',
        {foo => 'div'},
    ],
    'extra_processing method got the goods';

done_testing();