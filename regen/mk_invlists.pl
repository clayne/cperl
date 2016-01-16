#!perl -w
use 5.015;
use strict;
use warnings;
use Unicode::UCD qw(prop_aliases
                    prop_values
                    prop_value_aliases
                    prop_invlist
                    prop_invmap search_invlist
                   );
require './regen/regen_lib.pl';
require './regen/charset_translations.pl';

# This program outputs charclass_invlists.h, which contains various inversion
# lists in the form of C arrays that are to be used as-is for inversion lists.
# Thus, the lists it contains are essentially pre-compiled, and need only a
# light-weight fast wrapper to make them usable at run-time.

# As such, this code knows about the internal structure of these lists, and
# any change made to that has to be done here as well.  A random number stored
# in the headers is used to minimize the possibility of things getting
# out-of-sync, or the wrong data structure being passed.  Currently that
# random number is:

# charclass_invlists.h now also has a partial implementation of inversion
# maps; enough to generate tables for the line break properties, such as GCB

my $VERSION_DATA_STRUCTURE_TYPE = 148565664;

# integer or float
my $numeric_re = qr/ ^ -? \d+ (:? \. \d+ )? $ /ax;

# Matches valid C language enum names: begins with ASCII alphabetic, then any
# ASCII \w
my $enum_name_re = qr / ^ [[:alpha:]] \w* $ /ax;

my $out_fh = open_new('charclass_invlists.h', '>',
		      {style => '*', by => $0,
                      from => "Unicode::UCD"});

my $in_file_pound_if = 0;

print $out_fh "/* See the generating file for comments */\n\n";

# The symbols generated by this program are all currently defined only in a
# single dot c each.  The code knows where most of them go, but this hash
# gives overrides for the exceptions to the typical place
my %exceptions_to_where_to_define =
                        ( NonL1_Perl_Non_Final_Folds => 'PERL_IN_REGCOMP_C',
                          AboveLatin1                => 'PERL_IN_REGCOMP_C',
                          Latin1                     => 'PERL_IN_REGCOMP_C',
                          UpperLatin1                => 'PERL_IN_REGCOMP_C',
                          _Perl_Any_Folds            => 'PERL_IN_REGCOMP_C',
                          _Perl_Folds_To_Multi_Char  => 'PERL_IN_REGCOMP_C',
                          _Perl_IDCont               => 'PERL_IN_UTF8_C',
                          _Perl_IDStart              => 'PERL_IN_UTF8_C',
                        );

# This hash contains the properties with enums that have hard-coded references
# to them in C code.  Its only use is to make sure that if perl is compiled
# with an older Unicode data set, that all the enum values the code is
# expecting will still be in the enum typedef.  Thus the code doesn't have to
# change.  The Unicode version won't have any code points that have these enum
# values, so the code that handles them will not get exercised.  This is far
# better than having to #ifdef things.
my %hard_coded_enums =
 ( gcb => [
            'Control',
            'CR',
            'Extend',
            'L',
            'LF',
            'LV',
            'LVT',
            'Other',
            'Prepend',
            'Regional_Indicator',
            'SpacingMark',
            'T',
            'V',
        ],
   sb  => [
            'ATerm',
            'Close',
            'CR',
            'Extend',
            'Format',
            'LF',
            'Lower',
            'Numeric',
            'OLetter',
            'Other',
            'SContinue',
            'Sep',
            'Sp',
            'STerm',
            'Upper',
        ],
   wb  => [
            'ALetter',
            'CR',
            'Double_Quote',
            'Extend',
            'ExtendNumLet',
            'Format',
            'Hebrew_Letter',
            'Katakana',
            'LF',
            'MidLetter',
            'MidNum',
            'MidNumLet',
            'Newline',
            'Numeric',
            'Other',
            'Perl_Tailored_HSpace',
            'Regional_Indicator',
            'Single_Quote',
        ],
);

my @a2n;

sub uniques {
    # Returns non-duplicated input values.  From "Perl Best Practices:
    # Encapsulated Cleverness".  p. 455 in first edition.

    my %seen;
    return grep { ! $seen{$_}++ } @_;
}

sub a2n($) {
    my $cp = shift;

    # Returns the input Unicode code point translated to native.

    return $cp if $cp !~ $numeric_re || $cp > 255;
    return $a2n[$cp];
}

sub end_file_pound_if {
    if ($in_file_pound_if) {
        print $out_fh "\n#endif\t/* $in_file_pound_if */\n";
        $in_file_pound_if = 0;
    }
}

sub switch_pound_if ($$) {
    my $name = shift;
    my $new_pound_if = shift;

    # Switch to new #if given by the 2nd argument.  If there is an override
    # for this, it instead switches to that.  The 1st argument is the
    # static's name, used to look up the overrides

    if (exists $exceptions_to_where_to_define{$name}) {
        $new_pound_if = $exceptions_to_where_to_define{$name};
    }

    # Exit current #if if the new one is different from the old
    if ($in_file_pound_if
        && $in_file_pound_if !~ /$new_pound_if/)
    {
        end_file_pound_if;
    }

    # Enter new #if, if not already in it.
    if (! $in_file_pound_if) {
        $in_file_pound_if = "defined($new_pound_if)";
        print $out_fh "\n#if $in_file_pound_if\n";
    }
}

sub output_invlist ($$;$) {
    my $name = shift;
    my $invlist = shift;     # Reference to inversion list array
    my $charset = shift // "";  # name of character set for comment

    die "No inversion list for $name" unless defined $invlist
                                             && ref $invlist eq 'ARRAY';

    # Output the inversion list $invlist using the name $name for it.
    # It is output in the exact internal form for inversion lists.

    # Is the last element of the header 0, or 1 ?
    my $zero_or_one = 0;
    if (@$invlist && $invlist->[0] != 0) {
        unshift @$invlist, 0;
        $zero_or_one = 1;
    }
    my $count = @$invlist;

    switch_pound_if ($name, 'PERL_IN_PERL_C');

    print $out_fh "\nstatic const UV ${name}_invlist[] = {";
    print $out_fh " /* for $charset */" if $charset;
    print $out_fh "\n";

    print $out_fh "\t$count,\t/* Number of elements */\n";
    print $out_fh "\t$VERSION_DATA_STRUCTURE_TYPE, /* Version and data structure type */\n";
    print $out_fh "\t", $zero_or_one,
                  ",\t/* 0 if the list starts at 0;",
                  "\n\t\t   1 if it starts at the element beyond 0 */\n";

    # The main body are the UVs passed in to this routine.  Do the final
    # element separately
    for my $i (0 .. @$invlist - 1) {
        printf $out_fh "\t0x%X", $invlist->[$i];
        print $out_fh "," if $i < @$invlist - 1;
        print $out_fh "\n";
    }

    print $out_fh "};\n";
}

sub output_invmap ($$$$$$$) {
    my $name = shift;
    my $invmap = shift;     # Reference to inversion map array
    my $prop_name = shift;
    my $input_format = shift;   # The inversion map's format
    my $default = shift;        # The property value for code points who
                                # otherwise don't have a value specified.
    my $extra_enums = shift;    # comma-separated list of our additions to the
                                # property's standard possible values
    my $charset = shift // "";  # name of character set for comment

    # Output the inversion map $invmap for property $prop_name, but use $name
    # as the actual data structure's name.

    my $count = @$invmap;

    my $output_format;
    my $declaration_type;
    my %enums;
    my $name_prefix;

    if ($input_format eq 's') {
        $prop_name = (prop_aliases($prop_name))[1] // $prop_name =~ s/^_Perl_//r; # Get full name
        my $short_name = (prop_aliases($prop_name))[0] // $prop_name;
            my @enums = prop_values($prop_name);
            if (! @enums) {
                die "Only enum properties are currently handled; '$prop_name' isn't one";
            }
            else {

                # Convert short names to long
                @enums = map { (prop_value_aliases($prop_name, $_))[1] } @enums;

                my @expected_enums = @{$hard_coded_enums{lc $short_name}};
                die 'You need to update %hard_coded_enums to reflect new entries in this Unicode version'
                    if @expected_enums < @enums;

                # Remove the enums found in the input from the ones we expect
                for (my $i = @expected_enums - 1; $i >= 0; $i--) {
                    splice(@expected_enums, $i, 1)
                                if grep { $expected_enums[$i] eq $_ } @enums;
                }

                # The ones remaining must be because we're using an older
                # Unicode version.  Add them to the list.
                push @enums, @expected_enums;

                # Add in the extra values coded into this program, and sort.
                @enums = sort @enums;

                # The internal enums comes last.
                push @enums, split /,/, $extra_enums if $extra_enums ne "";

                # Assign a value to each element of the enum.  The default
                # value always gets 0; the others are arbitrarily assigned.
                my $enum_val = 0;
                my $canonical_default = prop_value_aliases($prop_name, $default);
                $default = $canonical_default if defined $canonical_default;
                $enums{$default} = $enum_val++;
                for my $enum (@enums) {
                    $enums{$enum} = $enum_val++ unless exists $enums{$enum};
                }
            }

            # Inversion map stuff is currently used only by regexec
            switch_pound_if($name, 'PERL_IN_REGEXEC_C');
        {

            # The short names tend to be two lower case letters, but it looks
            # better for those if they are upper. XXX
            $short_name = uc($short_name) if length($short_name) < 3
                                             || substr($short_name, 0, 1) =~ /[[:lower:]]/;
            $name_prefix = "${short_name}_";
            my $enum_count = keys %enums;
            print $out_fh "\n#define ${name_prefix}ENUM_COUNT ", scalar keys %enums, "\n";

            print $out_fh "\ntypedef enum {\n";
            my @enum_list;
            foreach my $enum (keys %enums) {
                $enum_list[$enums{$enum}] = $enum;
            }
            foreach my $i (0 .. @enum_list - 1) {
                my $name = $enum_list[$i];
                print $out_fh  "\t${name_prefix}$name = $i";
                print $out_fh "," if $i < $enum_count - 1;
                print $out_fh "\n";
            }
            $declaration_type = "${name_prefix}enum";
            print $out_fh "} $declaration_type;\n";

            $output_format = "${name_prefix}%s";
        }
    }
    else {
        die "'$input_format' invmap() format for '$prop_name' unimplemented";
    }

    die "No inversion map for $prop_name" unless defined $invmap
                                             && ref $invmap eq 'ARRAY'
                                             && $count;

    print $out_fh "\nstatic const $declaration_type ${name}_invmap[] = {";
    print $out_fh " /* for $charset */" if $charset;
    print $out_fh "\n";

    # The main body are the scalars passed in to this routine.
    for my $i (0 .. $count - 1) {
        my $element = $invmap->[$i];
        my $full_element_name = prop_value_aliases($prop_name, $element);
        $element = $full_element_name if defined $full_element_name;
        $element = $name_prefix . $element;
        print $out_fh "\t$element";
        print $out_fh "," if $i < $count - 1;
        print $out_fh  "\n";
    }
    print $out_fh "};\n";
}

sub mk_invlist_from_sorted_cp_list {

    # Returns an inversion list constructed from the sorted input array of
    # code points

    my $list_ref = shift;

    return unless @$list_ref;

    # Initialize to just the first element
    my @invlist = ( $list_ref->[0], $list_ref->[0] + 1);

    # For each succeeding element, if it extends the previous range, adjust
    # up, otherwise add it.
    for my $i (1 .. @$list_ref - 1) {
        if ($invlist[-1] == $list_ref->[$i]) {
            $invlist[-1]++;
        }
        else {
            push @invlist, $list_ref->[$i], $list_ref->[$i] + 1;
        }
    }
    return @invlist;
}

# Read in the Case Folding rules, and construct arrays of code points for the
# properties we need.
my ($cp_ref, $folds_ref, $format) = prop_invmap("Case_Folding");
die "Could not find inversion map for Case_Folding" unless defined $format;
die "Incorrect format '$format' for Case_Folding inversion map"
                                                    unless $format eq 'al'
                                                           || $format eq 'a';
my @has_multi_char_fold;
my @is_non_final_fold;

for my $i (0 .. @$folds_ref - 1) {
    next unless ref $folds_ref->[$i];   # Skip single-char folds
    push @has_multi_char_fold, $cp_ref->[$i];

    # Add to the non-finals list each code point that is in a non-final
    # position
    for my $j (0 .. @{$folds_ref->[$i]} - 2) {
        push @is_non_final_fold, $folds_ref->[$i][$j]
                unless grep { $folds_ref->[$i][$j] == $_ } @is_non_final_fold;
    }
}

sub _Perl_Non_Final_Folds {
    @is_non_final_fold = sort { $a <=> $b } @is_non_final_fold;
    return mk_invlist_from_sorted_cp_list(\@is_non_final_fold);
}

sub prop_name_for_cmp ($) { # Sort helper
    my $name = shift;

    # Returns the input lowercased, with non-alphas removed, as well as
    # everything starting with a comma

    $name =~ s/,.*//;
    $name =~ s/[[:^alpha:]]//g;
    return lc $name;
}

sub UpperLatin1 {
    return mk_invlist_from_sorted_cp_list([ 128 .. 255 ]);
}

output_invlist("Latin1", [ 0, 256 ]);
output_invlist("AboveLatin1", [ 256 ]);

end_file_pound_if;

# We construct lists for all the POSIX and backslash sequence character
# classes in two forms:
#   1) ones which match only in the ASCII range
#   2) ones which match either in the Latin1 range, or the entire Unicode range
#
# These get compiled in, and hence affect the memory footprint of every Perl
# program, even those not using Unicode.  To minimize the size, currently
# the Latin1 version is generated for the beyond ASCII range except for those
# lists that are quite small for the entire range, such as for \s, which is 22
# UVs long plus 4 UVs (currently) for the header.
#
# To save even more memory, the ASCII versions could be derived from the
# larger ones at runtime, saving some memory (minus the expense of the machine
# instructions to do so), but these are all small anyway, so their total is
# about 100 UVs.
#
# In the list of properties below that get generated, the L1 prefix is a fake
# property that means just the Latin1 range of the full property (whose name
# has an X prefix instead of L1).
#
# An initial & means to use the subroutine from this file instead of an
# official inversion list.

for my $charset (get_supported_code_pages()) {
    print $out_fh "\n" . get_conditional_compile_line_start($charset);

    @a2n = @{get_a2n($charset)};
    no warnings 'qw';
                         # Ignore non-alpha in sort
    for my $prop (sort { prop_name_for_cmp($a) cmp prop_name_for_cmp($b) } qw(
                             ASCII
                             Cased
                             VertSpace
                             XPerlSpace
                             XPosixAlnum
                             XPosixAlpha
                             XPosixBlank
                             XPosixCntrl
                             XPosixDigit
                             XPosixGraph
                             XPosixLower
                             XPosixPrint
                             XPosixPunct
                             XPosixSpace
                             XPosixUpper
                             XPosixWord
                             XPosixXDigit
                             _Perl_Any_Folds
                             &NonL1_Perl_Non_Final_Folds
                             _Perl_Folds_To_Multi_Char
                             &UpperLatin1
                             _Perl_IDStart
                             _Perl_IDCont
                             _Perl_GCB,EDGE
                             _Perl_SB,EDGE
                             _Perl_WB,EDGE,UNKNOWN
                           )
    ) {

        # For the Latin1 properties, we change to use the eXtended version of the
        # base property, then go through the result and get rid of everything not
        # in Latin1 (above 255).  Actually, we retain the element for the range
        # that crosses the 255/256 boundary if it is one that matches the
        # property.  For example, in the Word property, there is a range of code
        # points that start at U+00F8 and goes through U+02C1.  Instead of
        # artificially cutting that off at 256 because 256 is the first code point
        # above Latin1, we let the range go to its natural ending.  That gives us
        # extra information with no added space taken.  But if the range that
        # crosses the boundary is one that doesn't match the property, we don't
        # start a new range above 255, as that could be construed as going to
        # infinity.  For example, the Upper property doesn't include the character
        # at 255, but does include the one at 256.  We don't include the 256 one.
        my $prop_name = $prop;
        my $is_local_sub = $prop_name =~ s/^&//;
        my $extra_enums = "";
        $extra_enums = $1 if $prop_name =~ s/, ( .* ) //x;
        my $lookup_prop = $prop_name;
        my $l1_only = ($lookup_prop =~ s/^L1Posix/XPosix/
                       or $lookup_prop =~ s/^L1//);
        my $nonl1_only = 0;
        $nonl1_only = $lookup_prop =~ s/^NonL1// unless $l1_only;
        ($lookup_prop, my $has_suffixes) = $lookup_prop =~ / (.*) ( , .* )? /x;

        my @invlist;
        my @invmap;
        my $map_format;
        my $map_default;
        my $maps_to_code_point;
        my $to_adjust;
        if ($is_local_sub) {
            @invlist = eval $lookup_prop;
        }
        else {
            @invlist = prop_invlist($lookup_prop, '_perl_core_internal_ok');
            if (! @invlist) {

                # If couldn't find a non-empty inversion list, see if it is
                # instead an inversion map
                my ($list_ref, $map_ref, $format, $default)
                          = prop_invmap($lookup_prop, '_perl_core_internal_ok');
                if (! $list_ref) {
                    # An empty return here could mean an unknown property, or
                    # merely that the original inversion list is empty.  Call
                    # in scalar context to differentiate
                    my $count = prop_invlist($lookup_prop,
                                             '_perl_core_internal_ok');
                    die "Could not find inversion list for '$lookup_prop'"
                                                          unless defined $count;
                }
                else {
                    @invlist = @$list_ref;
                    @invmap = @$map_ref;
                    $map_format = $format;
                    $map_default = $default;
                    $maps_to_code_point = $map_format =~ /x/;
                    $to_adjust = $map_format =~ /a/;
                }
            }
        }


        # Short-circuit an empty inversion list.
        if (! @invlist) {
            output_invlist($prop_name, \@invlist, $charset);
            next;
        }

        # Re-order the Unicode code points to native ones for this platform.
        # This is only needed for code points below 256, because native code
        # points are only in that range.  For inversion maps of properties
        # where the mappings are adjusted (format =~ /a/), this reordering
        # could mess up the adjustment pattern that was in the input, so that
        # has to be dealt with.
        #
        # And inversion maps that map to code points need to eventually have
        # all those code points remapped to native, and it's better to do that
        # here, going through the whole list not just those below 256.  This
        # is because some inversion maps have adjustments (format =~ /a/)
        # which may be affected by the reordering.  This code needs to be done
        # both for when we are translating the inversion lists for < 256, and
        # for the inversion maps for everything.  By doing both in this loop,
        # we can share that code.
        #
        # So, we go through everything for an inversion map to code points;
        # otherwise, we can skip any remapping at all if we are going to
        # output only the above-Latin1 values, or if the range spans the whole
        # of 0..256, as the remap will also include all of 0..256  (256 not
        # 255 because a re-ordering could cause 256 to need to be in the same
        # range as 255.)
        if ((@invmap && $maps_to_code_point)
            || (! $nonl1_only || ($invlist[0] < 256
                                  && ! ($invlist[0] == 0 && $invlist[1] > 256))))
        {

            if (! @invmap) {    # Straight inversion list
            # Look at all the ranges that start before 257.
            my @latin1_list;
            while (@invlist) {
                last if $invlist[0] > 256;
                my $upper = @invlist > 1
                            ? $invlist[1] - 1      # In range

                              # To infinity.  You may want to stop much much
                              # earlier; going this high may expose perl
                              # deficiencies with very large numbers.
                            : $Unicode::UCD::MAX_CP;
                for my $j ($invlist[0] .. $upper) {
                    push @latin1_list, a2n($j);
                }

                shift @invlist; # Shift off the range that's in the list
                shift @invlist; # Shift off the range not in the list
            }

            # Here @invlist contains all the ranges in the original that start
            # at code points above 256, and @latin1_list contains all the
            # native code points for ranges that start with a Unicode code
            # point below 257.  We sort the latter and convert it to inversion
            # list format.  Then simply prepend it to the list of the higher
            # code points.
            @latin1_list = sort { $a <=> $b } @latin1_list;
            @latin1_list = mk_invlist_from_sorted_cp_list(\@latin1_list);
            unshift @invlist, @latin1_list;
            }
            else {  # Is an inversion map

                # This is a similar procedure as plain inversion list, but has
                # multiple buckets.  A plain inversion list just has two
                # buckets, 1) 'in' the list; and 2) 'not' in the list, and we
                # pretty much can ignore the 2nd bucket, as it is completely
                # defined by the 1st.  But here, what we do is create buckets
                # which contain the code points that map to each, translated
                # to native and turned into an inversion list.  Thus each
                # bucket is an inversion list of native code points that map
                # to it or don't map to it.  We use these to create an
                # inversion map for the whole property.

                # As mentioned earlier, we use this procedure to not just
                # remap the inversion list to native values, but also the maps
                # of code points to native ones.  In the latter case we have
                # to look at the whole of the inversion map (or at least to
                # above Unicode; as the maps of code points above that should
                # all be to the default).
                my $upper_limit = ($maps_to_code_point) ? 0x10FFFF : 256;

                my %mapped_lists;   # A hash whose keys are the buckets.
                while (@invlist) {
                    last if $invlist[0] > $upper_limit;

                    # This shouldn't actually happen, as prop_invmap() returns
                    # an extra element at the end that is beyond $upper_limit
                    die "inversion map that extends to infinity is unimplemented" unless @invlist > 1;

                    my $bucket;

                    # A hash key can't be a ref (we are only expecting arrays
                    # of scalars here), so convert any such to a string that
                    # will be converted back later (using a vertical tab as
                    # the separator).  Even if the mapping is to code points,
                    # we don't translate to native here because the code
                    # output_map() calls to output these arrays assumes the
                    # input is Unicode, not native.
                    if (ref $invmap[0]) {
                        $bucket = join "\cK", @{$invmap[0]};
                    }
                    elsif ($maps_to_code_point && $invmap[0] =~ $numeric_re) {

                        # Do convert to native for maps to single code points.
                        # There are some properties that have a few outlier
                        # maps that aren't code points, so the above test
                        # skips those.
                        $bucket = a2n($invmap[0]);
                    } else {
                        $bucket = $invmap[0];
                    }

                    # We now have the bucket that all code points in the range
                    # map to, though possibly they need to be adjusted.  Go
                    # through the range and put each translated code point in
                    # it into its bucket.
                    my $base_map = $invmap[0];
                    for my $j ($invlist[0] .. $invlist[1] - 1) {
                        if ($to_adjust
                               # The 1st code point doesn't need adjusting
                            && $j > $invlist[0]

                               # Skip any non-numeric maps: these are outliers
                               # that aren't code points.
                            && $base_map =~ $numeric_re

                               #  'ne' because the default can be a string
                            && $base_map ne $map_default)
                        {
                            # We adjust, by incrementing each the bucket and
                            # the map.  For code point maps, translate to
                            # native
                            $base_map++;
                            $bucket = ($maps_to_code_point)
                                      ? a2n($base_map)
                                      : $base_map;
                        }

                        # Add the native code point to the bucket for the
                        # current map
                        push @{$mapped_lists{$bucket}}, a2n($j);
                    } # End of loop through all code points in the range

                    # Get ready for the next range
                    shift @invlist;
                    shift @invmap;
                } # End of loop through all ranges in the map.

                # Here, @invlist and @invmap retain all the ranges from the
                # originals that start with code points above $upper_limit.
                # Each bucket in %mapped_lists contains all the code points
                # that map to that bucket.  If the bucket is for a map to a
                # single code point is a single code point, the bucket has
                # been converted to native.  If something else (including
                # multiple code points), no conversion is done.
                #
                # Now we recreate the inversion map into %xlated, but this
                # time for the native character set.
                my %xlated;
                foreach my $bucket (keys %mapped_lists) {

                    # Sort and convert this bucket to an inversion list.  The
                    # result will be that ranges that start with even-numbered
                    # indexes will be for code points that map to this bucket;
                    # odd ones map to some other bucket, and are discarded
                    # below.
                    @{$mapped_lists{$bucket}}
                                    = sort{ $a <=> $b} @{$mapped_lists{$bucket}};
                    @{$mapped_lists{$bucket}}
                     = mk_invlist_from_sorted_cp_list(\@{$mapped_lists{$bucket}});

                    # Add each even-numbered range in the bucket to %xlated;
                    # so that the keys of %xlated become the range start code
                    # points, and the values are their corresponding maps.
                    while (@{$mapped_lists{$bucket}}) {
                        my $range_start = $mapped_lists{$bucket}->[0];
                        if ($bucket =~ /\cK/) {
                            @{$xlated{$range_start}} = split /\cK/, $bucket;
                        }
                        else {
                            $xlated{$range_start} = $bucket;
                        }
                        shift @{$mapped_lists{$bucket}}; # Discard odd ranges
                        shift @{$mapped_lists{$bucket}}; # Get ready for next
                                                         # iteration
                    }
                } # End of loop through all the buckets.

                # Here %xlated's keys are the range starts of all the code
                # points in the inversion map.  Construct an inversion list
                # from them.
                my @new_invlist = sort { $a <=> $b } keys %xlated;

                # If the list is adjusted, we want to munge this list so that
                # we only have one entry for where consecutive code points map
                # to consecutive values.  We just skip the subsequent entries
                # where this is the case.
                if ($to_adjust) {
                    my @temp;
                    for my $i (0 .. @new_invlist - 1) {
                        next if $i > 0
                                && $new_invlist[$i-1] + 1 == $new_invlist[$i]
                                && $xlated{$new_invlist[$i-1]} =~ $numeric_re
                                && $xlated{$new_invlist[$i]} =~ $numeric_re
                                && $xlated{$new_invlist[$i-1]} + 1 == $xlated{$new_invlist[$i]};
                        push @temp, $new_invlist[$i];
                    }
                    @new_invlist = @temp;
                }

                # The inversion map comes from %xlated's values.  We can
                # unshift each onto the front of the untouched portion, in
                # reverse order of the portion we did process.
                foreach my $start (reverse @new_invlist) {
                    unshift @invmap, $xlated{$start};
                }

                # Finally prepend the inversion list we have just constructed to the
                # one that contains anything we didn't process.
                unshift @invlist, @new_invlist;
            }
        }

        # prop_invmap() returns an extra final entry, which we can now
        # discard.
        if (@invmap) {
            pop @invlist;
            pop @invmap;
        }

        if ($l1_only) {
            die "Unimplemented to do a Latin-1 only inversion map" if @invmap;
            for my $i (0 .. @invlist - 1 - 1) {
                if ($invlist[$i] > 255) {

                    # In an inversion list, even-numbered elements give the code
                    # points that begin ranges that match the property;
                    # odd-numbered give ones that begin ranges that don't match.
                    # If $i is odd, we are at the first code point above 255 that
                    # doesn't match, which means the range it is ending does
                    # match, and crosses the 255/256 boundary.  We want to include
                    # this ending point, so increment $i, so the splice below
                    # includes it.  Conversely, if $i is even, it is the first
                    # code point above 255 that matches, which means there was no
                    # matching range that crossed the boundary, and we don't want
                    # to include this code point, so splice before it.
                    $i++ if $i % 2 != 0;

                    # Remove everything past this.
                    splice @invlist, $i;
                    splice @invmap, $i if @invmap;
                    last;
                }
            }
        }
        elsif ($nonl1_only) {
            my $found_nonl1 = 0;
            for my $i (0 .. @invlist - 1 - 1) {
                next if $invlist[$i] < 256;

                # Here, we have the first element in the array that indicates an
                # element above Latin1.  Get rid of all previous ones.
                splice @invlist, 0, $i;
                splice @invmap, 0, $i if @invmap;

                # If this one's index is not divisible by 2, it means that this
                # element is inverting away from being in the list, which means
                # all code points from 256 to this one are in this list (or
                # map to the default for inversion maps)
                if ($i % 2 != 0) {
                    unshift @invlist, 256;
                    unshift @invmap, $map_default if @invmap;
                }
                $found_nonl1 = 1;
                last;
            }
            die "No non-Latin1 code points in $lookup_prop" unless $found_nonl1;
        }

        output_invlist($prop_name, \@invlist, $charset);
        output_invmap($prop_name, \@invmap, $lookup_prop, $map_format, $map_default, $extra_enums, $charset) if @invmap;
    }
    end_file_pound_if;
    print $out_fh "\n" . get_conditional_compile_line_end();
}

my $sources_list = "lib/unicore/mktables.lst";
my @sources = ($0, qw(lib/unicore/mktables
                      lib/Unicode/UCD.pm
                      regen/charset_translations.pl
                      ));
{
    # Depend on mktables’ own sources.  It’s a shorter list of files than
    # those that Unicode::UCD uses.
    if (! open my $mktables_list, $sources_list) {

          # This should force a rebuild once $sources_list exists
          push @sources, $sources_list;
    }
    else {
        while(<$mktables_list>) {
            last if /===/;
            chomp;
            push @sources, "lib/unicore/$_" if /^[^#]/;
        }
    }
}
read_only_bottom_close_and_rename($out_fh, \@sources)
