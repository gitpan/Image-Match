# $Id: Match.pm,v 1.1 2008/09/01 09:26:28 dk Exp $
package Image::Match;

use strict;
use warnings;
use Prima::noX11;
use Prima;
require Exporter;

our $VERSION = '1.01';
our $Y_GROWS_UPWARDS = 0;

sub match
{
        my ( $image, $subimage, $multiple) = @_;

        my $G   = $image-> data;
        my $W   = $image-> width;
        my $H   = $image-> height;
        my $w   = $subimage-> width;
        my $h   = $subimage-> height;
        my $bpp = ($image-> type & im::BPP) / 8;

	# 1 and 4 bit images aren't supported, autoconvert
	if ( $bpp < 0) {
		$image = $image-> dup;
		my $t = $subimage-> type & im::BPP;
		$t = 8 if $t < 8;
		$image-> type($t);
        	$bpp = ($image-> type & im::BPP) / 8;
	}

	# need same bpp!
	if ( $subimage-> type != $image-> type) {
		$subimage = $subimage-> dup;
		$subimage-> type( $image-> type);
	}

        my $I   = $subimage-> data;
        my $gw  = int(( $W * ( $image->    type & im::BPP) + 31) / 32) * 4;
        my $iw  = int(( $w * ( $subimage-> type & im::BPP) + 31) / 32) * 4;
        my $ibw = $w * $bpp;
        my $dw  = $gw - $ibw;
        
        my $rx  = join( ".{$dw}", map { quotemeta substr( $I, $_ * $iw, $ibw) } 
                (0 .. $subimage-> height - 1));
        my ( $x, $y);
	my @ret;
	my $blanker = ("\0" x ( $bpp * $w));

	while ( 1) {
		pos($G) = 0;
  		study $G;
		my @loc_ret;
		while ( 1) {
		        unless ( $G =~ m/\G.*?$rx/gcs) {
				return unless $multiple;
				last;
			}
			my $p = pos($G);
			$x = ($p - $w * $bpp) % $gw / $bpp;
			$y = int(($p - ( $x + $w) * $bpp) / $gw) + 1;
			next if $x + $w > $W; # scanline wrap
			$y = $y - $h;
			$y = $H - $h - $y unless $Y_GROWS_UPWARDS;
        		push @loc_ret, [ $x, $y ];
			return @{ $loc_ret[0] } unless $multiple;
		}
		# blank zeros over the found stuff to avoid overlapping matches
		for ( @loc_ret) {
			my ( $x, $y) = @$_;
			my $pos = $y * $gw + $x;
			for ( my $i = 0; $i < $h; $i++, $pos += $gw) {
				substr( $G, $pos, $w * $bpp) = $blanker;
			}
		}
		push @ret, @loc_ret;
		return @ret unless @loc_ret;
		@loc_ret = ();
	}
}

sub screenshot
{
	shift if defined($_[0]) and ( ref($_[0]) or ($_[0] =~ /Image/) );

	unless ( $::application) {
		my $error = Prima::XOpenDisplay();
		die $error if defined $error;
		require Prima::Application;
		import Prima::Application;
	}

	my ( $x, $y, $w, $h) = @_;
	my @as = $::application-> size;

	$x ||= 0;
	$y ||= 0;
	$w = $as[0] unless defined $w;
	$h = $as[1] unless defined $h;

	$y = $as[1] - $h - $y unless $Y_GROWS_UPWARDS;

	return $::application-> get_image( $x, $y, $w, $h);
}

*Prima::Image::match = \&match;
*Prima::Image::screenshot = \&screenshot;

1;

=pod

=head1 NAME

Image::Match - locate image inside another

=head1 DESCRIPTION

The module searches for occurencies of an image inside of a larger image.

The interesting stuff here is the image finding itself - it is done by a
regexp!  For all practical reasons, images can be easily treated as byte
strings, and regexps are not exception. For example, one needs to locate an
image 2x2 in larger 7x7 image. The regexp constructed should be the first
scanline of smaller image, 2 bytes, verbatim, then 7 - 2 = 5 of any character,
and finally the second scanline, 2 bytes again. Of course there are some quirks,
but these explained in API section.

The original idea was implemented in L<OCR::Naive> and L<Win32::GUIRobot>, but
this module extracts the pure matching logic, unburdened from wrappers that
were needed back then for matters at hand.

=head1 SYNOPSIS

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

=head1 API

=over

=item match $IMAGE, $SUBIMAGE, $MULTIPLE

Locates a $SUBIMAGE in $IMAGE, returns one or many matches, depending on $MULTIPLE.
If single match is requested, stops on the first match, and returns a pair of (X,Y)
coordinates. If $MULTIPLE is 1, returns array of (X,Y) pairs. In both modes, returns
empty list if nothing was found.

=item screenshot [ $X = 0, $Y = 0, $W = screen width, $H = screen height ]

Returns a new C<Prima::Image> object with a screen shot, taken at
given coordinates.

=item $Y_GROWS_UPWARDS = 0

The module uses L<Prima> for imaging storage and manipulations. Note that
C<Prima>'s notion of graphic coordinates is such that Y axis grows upwards.
This module can use both mathematical (Y grows upwards) and screen-based (Y
grows downwards) modes.  The latter is default; set
C<Image::Match::Y_GROWS_UPWARDS> to 1 to change that.

=back

=head1 NOTES

C<Prima> by default will start X11 session on unix. The module changes that
behavior. If your code needs X11 connection, change that by explicitly stating

   use Prima;

before invoking

   use Image::Match.

See L<Prima/noX11> for more.

=head1 PREREQUISITES

L<Prima>

=head1 SEE ALSO

L<Prima>, L<OCR::Naive>, L<Win32::GUIRobot>

=head1 LICENSE AND COPYRIGHT

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

Dmitry Karasik, E<lt>dmitry@karasik.eu.orgE<gt>.

=cut
