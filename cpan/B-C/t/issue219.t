#! /usr/bin/env perl
# GH #219 overload stringify failed 5.18-5.22
# See also t/issue172.t
use strict;
use Config;
my @plan;
BEGIN {
  if ($ENV{PERL_CORE}) {
    unshift @INC, ('t', '../../lib');
  } else {
    unshift @INC, 't', "blib/arch", "blib/lib";
  }
  require TestBC;
  $ENV{SKIP_SLOW_TESTS} = 1 if $Config{ccflags} =~ /-flto/;
  $ENV{SKIP_SLOW_TESTS} = 1 if $^O eq 'MSWin32' and $ENV{APPVEYOR};

  if ($ENV{SKIP_SLOW_TESTS}) {
    @plan = (skip_all => 'SKIP_SLOW_TESTS, timeout on CI');
  } else {
    @plan = (tests => 3);
  }
}
use Test::More @plan;
use B::C ();
my $todo = ($] >= 5.018 and $B::C::VERSION lt '1.52_18') ? "TODO 5.18-5.22" : "";

ctestok(1,'C,-O3','ccode219i',<<'EOF',$todo.'#219 overload stringify, testc 172');
package Foo;
use overload q("") => sub { "Foo" };
package main;
my $foo = bless {}, "Foo";
print "ok\n" if "$foo" eq "Foo";
EOF

ctestok(2,'C,-O3','ccode219i',<<'EOF',$todo.'#219 overload stringify');
package OverloadTest;
use overload qw("") => sub { ${$_[0]} };
package main;
my $foo = bless \(my $bar = "ok"), "OverloadTest"; 
print $foo."\n";
EOF

ctestok(3,'C,-O3','ccode219i',<<'EOF','#219 overload integer, testc 2731');
package Foo; 
use overload; 
sub import { overload::constant "integer" => sub { return shift }}; 
package main; 
BEGIN { $INC{"Foo.pm"} = "/lib/Foo.pm" }; 
use Foo;
print "ok\n" if 11 == eval "5+6";
EOF
