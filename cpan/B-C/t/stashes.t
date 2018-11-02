#! /usr/bin/env perl
# testc.sh 46, GH #
use strict;
BEGIN {
  if ($ENV{PERL_CORE}) {
    unshift @INC, ('t', '../../lib');
  } else {
    unshift @INC, 't', "blib/arch", "blib/lib";
  }
  require TestBC;
}
use Config;
use Test::More;
$ENV{SKIP_SLOW_TESTS} = 1 if $Config{ccflags} =~ /-flto/;
plan skip_all => "MSWin32" if $ENV{PERL_CORE} and $^O eq 'MSWin32';
plan tests => 6;
my $i=0;
#use B::C ();

ctestok($i++, "C,-O3", "ccode46g", <<'EOF', "empty stash");
print 'ok' unless keys %Dummy::;
EOF

ctestok($i++, "C", "ccode46g", <<'EOF', "if stash -O0");
print 'ok' unless %Exporter::;
EOF

SKIP: {
skip "slow tests", 4 if $ENV{SKIP_SLOW_TESTS};

ctestok($i++, "C,-O3", "ccode46g", <<'EOF', "if stash -O3");
print 'ok' unless %Exporter::;
EOF

ctestok($i++, "C,-O3", "ccode46g", <<'EOF', "empy keys stash, no %INC");
print 'ok' if keys %Exporter:: < 2;
EOF

ctestok($i++, "C,-O3", "ccode46g", <<'EOF', "TODO use should not skip, special but in %INC");
use Exporter; print 'ok' if keys %Exporter:: > 2;
EOF

my $TODO = $^O eq 'cygwin' ? " TODO " : "";
ctestok($i++, "C,-O3", "ccode46g", <<'EOF', "$TODO use should not skip, in %INC");
use Devel::Peek; print 'ok' if keys %Devel::Peek:: > 2;
EOF
    
}

