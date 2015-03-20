#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Deep;

plan tests => 22;

use HTML::ExtractText;

{
    my $ext = HTML::ExtractText->new;
    can_ok($ext,
        qw/new  extract  error  last_results  separator  ignore_not_found/
    );
    isa_ok($ext, 'HTML::ExtractText');
}

{ # check defaults
    my $ext = HTML::ExtractText->new;
    is $ext->separator, "\n", 'default separator';
    is $ext->ignore_not_found, 1, 'default ignore_not_found';
}

{ # check basic extraction
    my $ext = HTML::ExtractText->new;
    my $result = $ext->extract(
        {
            p => 'p',
            a => '[href]',
        },
        '<p>Paras1</p><a href="#">Linkas</a><p>Paras2</p>',
    );

    my $expected_result = {
        p => "Paras1\nParas2",
        a => 'Linkas',
    };

    cmp_deeply $result, $expected_result, 'return of ->extract';
    cmp_deeply +{%$ext}, $expected_result, 'hash interpolation of object';
    cmp_deeply $ext->last_results, $expected_result,
        'return from ->last_results()';
}

{ # check undef separator
    my $ext = HTML::ExtractText->new;
    $ext->separator(undef);
    my $result = $ext->extract(
        {
            p => 'p',
            a => '[href]',
        },
        '<p>Paras1</p><a href="#">Linkas</a><p>Paras2</p>',
    );

    my $expected_result = {
        p => [ 'Paras1', 'Paras2' ],
        a => [ 'Linkas' ],
    };

    cmp_deeply $result, $expected_result, 'return of ->extract';
    cmp_deeply +{%$ext}, $expected_result, 'hash interpolation of object';
    cmp_deeply $ext->last_results, $expected_result,
        'return from ->last_results()';
}

{ # check non-default, non-undef separator
    my $ext = HTML::ExtractText->new;
    $ext->separator("FOO");
    my $result = $ext->extract(
        {
            p => 'p',
            a => '[href]',
        },
        '<p>Paras1</p><a href="#">Linkas</a><p>Paras2</p>',
    );

    my $expected_result = {
        p => "Paras1FOOParas2",
        a => 'Linkas',
    };

    cmp_deeply $result, $expected_result, 'return of ->extract';
    cmp_deeply +{%$ext}, $expected_result, 'hash interpolation of object';
    cmp_deeply $ext->last_results, $expected_result,
        'return from ->last_results()';

    is $ext->separator, 'FOO', '->separator value';
}

{ # check object method calls
    my $ext = HTML::ExtractText->new;

    package Test::ZofMockObj;
    sub test_method {
        my $self = shift;
        if ( @_ ) { $self->{EXTRACT} = shift; }
        return $self->{EXTRACT};
    }

    package main;

    my $mock_obj = bless ({}, 'Test::ZofMockObj');

    ok !defined($mock_obj->test_method),
        'test_method on mock object before extracting';

    my $result = $ext->extract(
        {
            test_method => 'p',
        },
        '<p>Paras1</p><a href="#">Linkas</a><p>Paras2</p>',
        $mock_obj,
    );

    my $expected_result = {
        test_method => "Paras1\nParas2",
    };

    cmp_deeply $result, $expected_result, 'return of ->extract';
    cmp_deeply +{%$ext}, $expected_result, 'hash interpolation of object';
    cmp_deeply $ext->last_results, $expected_result,
        'return from ->last_results()';

    is $mock_obj->test_method, "Paras1\nParas2",
        'test_method on mock object before extracting';

}

{ # check errors
    my $ext = HTML::ExtractText->new;
    $ext->ignore_not_found(undef);
    my $result = $ext->extract(
        {
            p => 'p',
            a => 'BLARG!',
        },
        '<p>Paras1</p><a href="#">Linkas</a><p>Paras2</p>',
    );

    my $expected_result = {
        p => "Paras1\nParas2",
        a => 'ERROR: NOT FOUND',
    };

    ok !defined($result), 'return of ->extract';
    cmp_deeply +{%$ext}, $expected_result, 'hash interpolation of object';
    cmp_deeply $ext->last_results, $expected_result,
        'return from ->last_results()';


}