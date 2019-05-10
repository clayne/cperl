#!./perl

BEGIN {
    $ENV{PERL_UNICODE} = 0;
    unless (-d 'blib') {
        chdir 't' if -d 't';
    }
    require q(./test.pl);
    set_up_inc('../lib');
}

use strict;
use warnings;
use utf8 qw( Devanagari Bopomofo Ethiopic Hangul Cyrillic Katakana
             Mongolian Kannada Thai Runic Ogham Lao Gujarati
             Oriya Georgian Malayalam Gurmukhi Mongolian Hiragana );
use open qw( :utf8 :std );

plan(tests => 46);

{
    package Ｎeẁ;
    use strict;
    use warnings;

    package ऑlㄉ;
    use strict;
    use warnings;

    {
      no strict 'refs';
      *{'ऑlㄉ::'} = *{'Ｎeẁ::'};
    }
}

ok (ऑlㄉ->isa(Ｎeẁ::), 'ऑlㄉ inherits from Ｎeẁ');
ok (Ｎeẁ->isa(ऑlㄉ::), 'Ｎeẁ inherits from ऑlㄉ');

object_ok (bless ({}, ऑlㄉ::), Ｎeẁ::, 'ऑlㄉ object');
object_ok (bless ({}, Ｎeẁ::), ऑlㄉ::, 'Ｎeẁ object');


# Test that replacing a package by assigning to an existing glob
# invalidates the isa caches
for(
 {
   name => 'assigning a glob to a glob',
   code => '$life_raft = $::{"ｌㅔf::"}; *ｌㅔf:: = $::{"릭Ⱶᵀ::"}',
 },
 {
   name => 'assigning a string to a glob',
   code => '$life_raft = $::{"ｌㅔf::"}; *ｌㅔf:: = "릭Ⱶᵀ::"',
 },
 {
   name => 'assigning a stashref to a glob',
   code => '$life_raft = \%ｌㅔf::; *ｌㅔf:: = \%릭Ⱶᵀ::',
 },
) {
my $prog =    q~
     BEGIN {
         unless (-d 'blib') {
             chdir 't' if -d 't';
             @INC = '../lib';
         }
     }
     use utf8 qw( Hangul Gurmukhi Mongolian Cyrillic Mongolian Kannada
                  Runic Ethiopic );
     use open qw( :utf8 :std );

     @숩cਲᠠ::ISA = "ｌㅔf";
     @ｌㅔf::ISA = "톺ĺФț";

     sub 톺ĺФț::Ｓᠠeಅḱ { "Woof!" }
     sub ᴖ릭ᚽʇ::Ｓᠠeಅḱ { "Bow-wow!" }

     my $thing = bless [], "숩cਲᠠ";

     # mro_package_moved needs to know to skip non-globs
     $릭Ⱶᵀ::{"ᚷꝆエcƙ::"} = 3;

     @릭Ⱶᵀ::ISA = 'ᴖ릭ᚽʇ';
     my $life_raft;
    __code__;

     print $thing->Ｓᠠeಅḱ, "\n";

     undef $life_raft;
     print $thing->Ｓᠠeಅḱ, "\n";
   ~ =~ s\__code__\$$_{code}\r; #\
utf8::encode($prog);
 fresh_perl_is
  $prog, 
  "Bow-wow!\nBow-wow!\n",
   {},
  "replacing packages by $$_{name} updates isa caches";
}

# Similar test, but with nested packages
#
#  톺ĺФț (Woof)    ᴖ릭ᚽʇ (Bow-wow)
#      |                 |
#  ｌㅔf::Side   <-   릭Ⱶᵀ::Side
#      |
#   숩cਲᠠ
#
# This test assigns 릭Ⱶᵀ:: to ｌㅔf::, indirectly making ｌㅔf::Side an
# alias to 릭Ⱶᵀ::Side (following the arrow in the diagram).
for(
 {
   name => 'assigning a glob to a glob',
   code => '$life_raft = $::{"ｌㅔf::"}; *ｌㅔf:: = $::{"릭Ⱶᵀ::"}',
 },
 {
   name => 'assigning a string to a glob',
   code => '$life_raft = $::{"ｌㅔf::"}; *ｌㅔf:: = "릭Ⱶᵀ::"',
 },
 {
   name => 'assigning a stashref to a glob',
   code => '$life_raft = \%ｌㅔf::; *ｌㅔf:: = \%릭Ⱶᵀ::',
 },
) {
 my $prog = q~
     BEGIN {
         unless (-d 'blib') {
             chdir 't' if -d 't';
             @INC = '../lib';
         }
     }
     use utf8 qw( Hangul Gurmukhi Mongolian Cyrillic Mongolian Kannada
                  Runic Ethiopic );
     use open qw( :utf8 :std );
     @숩cਲᠠ::ISA = "ｌㅔf::Side";
     @ｌㅔf::Side::ISA = "톺ĺФț";

     sub 톺ĺФț::Ｓᠠeಅḱ { "Woof!" }
     sub ᴖ릭ᚽʇ::Ｓᠠeಅḱ { "Bow-wow!" }

     my $thing = bless [], "숩cਲᠠ";

     @릭Ⱶᵀ::Side::ISA = 'ᴖ릭ᚽʇ';
     my $life_raft;
    __code__;

     print $thing->Ｓᠠeಅḱ, "\n";

     undef $life_raft;
     print $thing->Ｓᠠeಅḱ, "\n";
   ~ =~ s\__code__\$$_{code}\r;
 utf8::encode($prog);

 fresh_perl_is
  $prog,
  "Bow-wow!\nBow-wow!\n",
   {},
  "replacing nested packages by $$_{name} updates isa caches";
}

# Another nested package test, in which the isa cache needs to be reset on
# the subclass of a package that does not exist.
#
# Parenthesized packages do not exist.
#
#  ɵűʇㄦ::인ንʵ    ( cฬnए::인ንʵ )
#       |                 |
#     Ｌфť              R익hȚ
#
#        ɵűʇㄦ  ->  cฬnए
#
# This test assigns ɵűʇㄦ:: to cฬnए::, making cฬnए::인ንʵ an alias to
# ɵűʇㄦ::인ንʵ.
#
# Then we also run the test again, but without ɵűʇㄦ::인ንʵ
for(
 {
   name => 'assigning a glob to a glob',
   code => '*cฬnए:: = *ɵűʇㄦ::',
 },
 {
   name => 'assigning a string to a glob',
   code => '*cฬnए:: = "ɵűʇㄦ::"',
 },
 {
   name => 'assigning a stashref to a glob',
   code => '*cฬnए:: = \%ɵűʇㄦ::',
 },
) {
 for my $tail ('인ንʵ', '인ንʵ::', '인ንʵ:::', '인ንʵ::::') {
  my $prog =     q~
     BEGIN {
         unless (-d 'blib') {
             chdir 't' if -d 't';
             @INC = '../lib';
         }
      }
      use utf8 qw( Cyrillic Hangul Thai Devanagari Bopomofo Ethiopic );
      use open qw( :utf8 :std );
      use Encode ();

      if (grep /\P{ASCII}/, @ARGV) {
        @ARGV = map { Encode::decode("UTF-8", $_) } @ARGV;
      }

      my $tail = shift;
      @Ｌфť::ISA = "ɵűʇㄦ::$tail";
      @R익hȚ::ISA = "cฬnए::$tail";
      bless [], "ɵűʇㄦ::$tail"; # autovivify the stash

     __code__;

      print "ok 1", "\n" if Ｌфť->isa("cฬnए::$tail");
      print "ok 2", "\n" if R익hȚ->isa("ɵűʇㄦ::$tail");
      print "ok 3", "\n" if R익hȚ->isa("cฬnए::$tail");
      print "ok 4", "\n" if Ｌфť->isa("ɵűʇㄦ::$tail");
    ~ =~ s\__code__\$$_{code}\r;
  utf8::encode($prog);
  fresh_perl_is
   $prog,
   "ok 1\nok 2\nok 3\nok 4\n",
    { args => [$tail] },
   "replacing nonexistent nested packages by $$_{name} updates isa caches"
     ." ($tail)";

  # Same test but with the subpackage autovivified after the assignment
  $prog =     q~
      BEGIN {
         unless (-d 'blib') {
             chdir 't' if -d 't';
             @INC = '../lib';
         }
      }
      use utf8 qw( Cyrillic Hangul Thai Devanagari Bopomofo Ethiopic );
      use open qw( :utf8 :std );
      use Encode ();

      if (grep /\P{ASCII}/, @ARGV) {
        @ARGV = map { Encode::decode("UTF-8", $_) } @ARGV;
      }

      my $tail = shift;
      @Ｌфť::ISA = "ɵűʇㄦ::$tail";
      @R익hȚ::ISA = "cฬnए::$tail";

     __code__;

      bless [], "ɵűʇㄦ::$tail";

      print "ok 1", "\n" if Ｌфť->isa("cฬnए::$tail");
      print "ok 2", "\n" if R익hȚ->isa("ɵűʇㄦ::$tail");
      print "ok 3", "\n" if R익hȚ->isa("cฬnए::$tail");
      print "ok 4", "\n" if Ｌфť->isa("ɵűʇㄦ::$tail");
    ~ =~ s\__code__\$$_{code}\r;
  utf8::encode($prog);
  fresh_perl_is
   $prog,
   "ok 1\nok 2\nok 3\nok 4\n",
    { args => [$tail] },
   "Giving nonexistent packages multiple effective names by $$_{name}"
     . " ($tail)";
 }
}

no warnings; # temporary; there seems to be a scoping bug, as this does not
             # work when placed in the blocks below

# Test that deleting stash elements containing
# subpackages also invalidates the isa cache.
# Maybe this does not belong in package_aliases.t, but it is closely
# related to the tests immediately preceding.
{
 @ቹऋ::ISA = ("Cuȓ", "ฮﾝᛞ");
 @Cuȓ::ISA = "Hyḹ앛Ҭテ";

 sub Hyḹ앛Ҭテ::Ｓᠠeಅḱ { "Arff!" }
 sub ฮﾝᛞ::Ｓᠠeಅḱ { "Woof!" }

 my $pet = bless [], "ቹऋ";

 my $life_raft = delete $::{'Cuȓ::'};

 is $pet->Ｓᠠeಅḱ, 'Woof!',
  'deleting a stash from its parent stash invalidates the isa caches';

 undef $life_raft;
 is $pet->Ｓᠠeಅḱ, 'Woof!',
  'the deleted stash is gone completely when freed';
}
# Same thing, but with nested packages
{
 @펱ᠠ::ISA = ("Cuȓȓ::Cuȓȓ::Cuȓȓ", "ɥwn");
 @Cuȓȓ::Cuȓȓ::Cuȓȓ::ISA = "lȺt랕ᚖ";

 sub lȺt랕ᚖ::Ｓᠠeಅḱ { "Arff!" }
 sub ɥwn::Ｓᠠeಅḱ { "Woof!" }

 my $pet = bless [], "펱ᠠ";

 my $life_raft = delete $::{'Cuȓȓ::'};

 is $pet->Ｓᠠeಅḱ, 'Woof!',
  'deleting a stash from its parent stash resets caches of substashes';

 undef $life_raft;
 is $pet->Ｓᠠeಅḱ, 'Woof!',
  'the deleted substash is gone completely when freed';
}

# [perl #77358]
my $prog =    q~#!perl -w
     BEGIN {
         unless (-d 'blib') {
             chdir 't' if -d 't';
             @INC = '../lib';
         }
     }
     use utf8 qw( Hangul Mongolian Ethiopic Runic Katakana Kannada Ogham
                  Lao );
     use open qw( :utf8 :std );
     @펱ᠠ::ISA = "T잌ዕ";
     @T잌ዕ::ISA = "Bᛆヶṝ";
     
     sub Bᛆヶṝ::Ｓᠠeಅḱ { print "Woof!\n" }
     sub lȺt랕ᚖ::Ｓᠠeಅḱ { print "Bow-wow!\n" }
     
     my $pet = bless [], "펱ᠠ";
     
     $pet->Ｓᠠeಅḱ;
     
     sub ດƓ::Ｓᠠeಅḱ { print "Hello.\n" } # strange ດƓ!
     @ດƓ::ISA = 'lȺt랕ᚖ';
     *T잌ዕ:: = delete $::{'ດƓ::'};
     
     $pet->Ｓᠠeಅḱ;
   ~;
utf8::encode($prog);
fresh_perl_is
  $prog,
  "Woof!\nHello.\n",
   { stderr => 1 },
  "Assigning a nameless package over one w/subclasses updates isa caches";

# mro_package_moved needs to make a distinction between replaced and
# assigned stashes when keeping track of what it has seen so far.
no warnings; {
    no strict 'refs';

    sub ʉ::bᠠnǩ::bᠠnǩ::ພo { "bbb" }
    sub ᵛeↄl움::ພo { "lasrevinu" }
    @ᠠ엗Ƚeᵬૐᵖ::ISA = qw 'ພo::bᠠnǩ::bᠠnǩ ᵛeↄl움';
    *ພo::ବㄗ:: = *ʉ::bᠠnǩ::;   # now ʉ::bᠠnǩ:: is on both sides
    *ພo:: = *ʉ::;         # here ʉ::bᠠnǩ:: is both deleted and added
    *ʉ:: = *ቦᵕ::;          # now it is only known as ພo::bᠠnǩ::

    # At this point, before the bug was fixed, %ພo::bᠠnǩ::bᠠnǩ:: ended
    # up with no effective name, allowing it to be deleted without updating
    # its subclassesâ caches.

    my $accum = '';

    $accum .= 'ᠠ엗Ƚeᵬૐᵖ'->ພo;          # bbb
    delete ${"ພo::bᠠnǩ::"}{"bᠠnǩ::"};
    $accum .= 'ᠠ엗Ƚeᵬૐᵖ'->ພo;          # bbb (Oops!)
    @ᠠ엗Ƚeᵬૐᵖ::ISA = @ᠠ엗Ƚeᵬૐᵖ::ISA;
    $accum .= 'ᠠ엗Ƚeᵬૐᵖ'->ພo;          # lasrevinu

    is $accum, 'bbblasrevinulasrevinu',
      'nested classes deleted & added simultaneously';
}
use warnings;

# mro_package_moved needs to check for self-referential packages.
# This broke Text::Template [perl #78362].
watchdog 3;
*ᠠ:: = \%::;
*Aᶜme::M::Aᶜme:: = \*Aᶜme::; # indirect self-reference
pass("mro_package_moved and self-referential packages");

# Deleting a glob whose name does not indicate its location in the symbol
# table but which nonetheless *is* in the symbol table.
{
    no strict refs=>;
    no warnings;
    @ოƐ::mഒrェ::ISA = "foᚒ";
    sub foᚒ::ວmᠠ { "aoeaa" }
    *ťວ:: = *ოƐ::;
    delete $::{"ოƐ::"};
    @C힐dᠠl았::ISA = 'ťວ::mഒrェ';
    my $accum = 'C힐dᠠl았'->ວmᠠ . '-';
    my $life_raft = delete ${"ťວ::"}{"mഒrェ::"};
    $accum .= eval { 'C힐dᠠl았'->ວmᠠ } // '<undef>';
    is $accum, 'aoeaa-<undef>',
     'Deleting globs whose loc in the symtab differs from gv_fullname'
}

# Pathological test for undeffing a stash that has an alias.
*ᵍh엞:: = *ኔƞ::;
@숩cਲᠠ::ISA = 'ᵍh엞';
undef %ᵍh엞::;
sub F렐ᛔ::ວmᠠ { "clumpren" }
eval '
  $ኔƞ::whatever++;
  @ኔƞ::ISA = "F렐ᛔ";
';
is eval { '숩cਲᠠ'->ວmᠠ }, 'clumpren',
 'Changes to @ISA after undef via original name';
undef %ᵍh엞::;
eval '
  $ᵍh엞::whatever++;
  @ᵍh엞::ISA = "F렐ᛔ";
';
is eval { '숩cਲᠠ'->ວmᠠ }, 'clumpren',
 'Changes to @ISA after undef via alias';


# Packages whose containing stashes have aliases must lose all names cor-
# responding to that container when detached.
{
 {package śmᛅḙ::በɀ} # autovivify
 *pḢ린ᚷ:: = *śmᛅḙ::;  # śmᛅḙ::በɀ now also named pḢ린ᚷ::በɀ
 *본:: = delete $śmᛅḙ::{"በɀ::"};
 # In 5.13.7, it has now lost its śmᛅḙ::በɀ name (reverting to pḢ린ᚷ::በɀ
 # as the effective name), and gained 본 as an alias.
 # In 5.13.8, both śmᛅḙ::በɀ *and* pḢ린ᚷ::በɀ names are deleted.

 # Make some methods
 no strict 'refs';
 *{"pḢ린ᚷ::በɀ::fฤmᛈ"} = sub { "hello" };
 sub Ｆルmፕṟ::fฤmᛈ { "good bye" };

 @ᵇるᠠ킨::ISA = qw "본 Ｆルmፕṟ"; # now wrongly inherits from pḢ린ᚷ::በɀ

 is fฤmᛈ ᵇるᠠ킨, "good bye",
  'detached stashes lose all names corresponding to the containing stash';
}

# Crazy edge cases involving packages ending with a single : are forbidden in cperl
# under strict names
@촐oン::ISA = 'ᚖგ:';
eval 'bless [], "ᚖგ:";';
like $@, qr/Invalid identifier \"\\341\\232\\226\\341\\203\\222:\" while "strict names" in use/;

=cut
