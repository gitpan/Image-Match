# $Id: test.pl,v 1.1 2008/09/01 09:26:28 dk Exp $
use strict;
use Image::Match;

# make screenshot
my $big = Image::Match-> screenshot;
# extract 50x50 image
my $small = $big-> extract( 230, $big-> height - 70 - 230, 70, 70);
# save
$small-> save('1.png');
# load
$small = Prima::Image-> load('1.png') or die "Can't load: $@";
# find again
my ( $x, $y) = $big-> match( $small);
print defined($x) ? "found at $x:$y\n" : "not found\n";

run Prima;
1;
