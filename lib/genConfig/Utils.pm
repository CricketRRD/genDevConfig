# -*-perl-*-
###############################################################################
#
#    genConfig::Utils module
#
#    Copyright (C) 2002 Francois Mikus
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
###############################################################################

package genConfig::Utils;

use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
use Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(fmi translateRttTargetAddr);

my ($gInstallRoot);
BEGIN {
    $gInstallRoot = (($0 =~ m:^(.*/):)[0] || "./") . "..";
}

use lib "$gInstallRoot/lib";

use Common::Log;
use Socket;

###############################################################################
# Convert bits and bytes to SI units.
###############################################################################

sub fmi {
  my($number, $units) = @_;
  my @short;


  my @abrv = ('','k','M','G','T','P','E');
  my $b = ($units eq 'bytes') ? 'Bytes' : 'Bits';

  my $digits = length("".$number);
  my $divm = 0;
  while ($digits - $divm*3 > 4) { $divm++; }
  my $divnum = $number/10**($divm*3);

  return sprintf("%1.1f %s%s/s", $divnum, $abrv[$divm], $b);
}

###############################################################################
#
# Conversion d'adresse Hexa des agents SNMP SAA en decimal
#
###############################################################################

sub translateRttTargetAddr {
    my ($type, $value) = @_;
    return ("unknown") if ($type ne "saa-rtt");

    $value = inet_ntoa($value);
    Debug("TranslateRttTarget: $value");
    return ( $value );
}

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# tab-width: 4
# perl-indent-level: 4
# End:
