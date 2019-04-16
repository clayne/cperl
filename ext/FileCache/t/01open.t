#!./perl

use FileCache;

my @files = map { $_ . $$ } qw(foo bar baz quux Foo_Bar);
END { 1 while unlink @files }

use Test::More tests => 1;

{# Test 1: that we can open files
     for my $path ( @files ){
	 cacheout $path;
	 print $path "$path 1\n";
	 close $path;
     }
     ok(scalar(map { -f } @files) == scalar(@files));
}
