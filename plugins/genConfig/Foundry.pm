# -*-perl-*-
#    genRtrConfig plugin module
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

package Foundry;

use strict;

use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;

### Start package init

use genConfig::Plugin;

our @ISA = qw(genConfig::Plugin);

my $VERSION = 1.03;

### End package init


###############################################################################
# These are device types we can handle in this plugin
# the names should be contained in the sysdescr string
# returned by the devices. The name is a regular expression.
###############################################################################
my @types = ( 'Foundry',
            );

###############################################################################
# These are the OIDS used by this plugin
# the OIDS should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.
###############################################################################
my %OIDS = (
       ### from FOUNDRY-SN-ROOT-MIB
       ### foundry.products.switch.snSwitch.snSwPortInfo...

       'snSwPortName'                => '1.3.6.1.4.1.1991.1.1.3.3.1.1.24',
       'snSwPortIfIndex'             => '1.3.6.1.4.1.1991.1.1.3.3.1.1.38',
       'snSwPortDescr'               => '1.3.6.1.4.1.1991.1.1.3.3.1.1.39',

       ### from FOUNDRY-SN-ROOT-MIB
       ### foundry.products.switch.snAgentSys.snAgentGbl...

       'snAgBuildVer'                => '1.3.6.1.4.1.1991.1.1.2.1.49',
      );

###############################################################################
### Private variables
###############################################################################

# none

#-------------------------------------------------------------------------------
# device_types
# IN : N/A
# OUT: returns an array ref of devices this plugin can handle
#-------------------------------------------------------------------------------

sub device_types {
   my $self = shift;
   return \@types;
}

#-------------------------------------------------------------------------------
# can_handle
# IN : opts reference
# OUT: returns a true if the device can be handled by this plugin
#-------------------------------------------------------------------------------

sub can_handle {
    my($self, $opts) = @_;

    return (grep { $opts->{sysDescr} =~ m/$_/gi } @types)

}

#-------------------------------------------------------------------------------
# discover
# IN : options hash
# OUT: returns the options hash
#-------------------------------------------------------------------------------

sub discover {
    my($self, $opts) = @_;

    ### Add our OIDs to the the global OID list

    register_oids(%OIDS);

    ###
    ### START DEVICE DISCOVERY SECTION
    ###

    ### Figure out which oid to use to get interface descriptions and which
    ### MIBs are supported.
    ###

    if ($opts->{sysDescr} =~ /Foundry/) {

        $opts->{model} = 'Foundry-Generic';

        ($opts->{vendor_soft_ver})  = snmpUtils::get($opts->{snmp}, $OIDS{'snAgBuildVer'});
        $opts->{vendor_descr_oid} = 'ifAlias';
        # $opts->{vendor_descr_oid} = 'snSwPortName';

        # if $opts->{vendor_soft_ver} ge "???";

        # Default feature promotions for Foundry Devices
        $opts->{foundrybox} = 1    if ($opts->{req_vendorbox});
        $opts->{foundryint} = 1    if ($opts->{req_vendorint});
        $opts->{extendedint} = 0      if ($opts->{req_extendedint});
        $opts->{namedonly} = 1     if ($opts->{req_namedonly});
    }

    if ($opts->{foundrybox}){ # Default Foundry config
        $opts->{chassisttype} = 'Foundry-Generic-Router';
        $opts->{chassisname} = 'Chassis-Foundry';
        $opts->{usev2c} = 1 if ($opts->{req_usev2c});
    }


    return;
}

#-------------------------------------------------------------------------------
# custom_targets
# IN : data reference for transient data, options reference
# OUT: N/A
#-------------------------------------------------------------------------------

sub custom_targets {
    my ($self,$data,$opts) = @_;
                       
    # Saving local copies of runtime data
    my %ifspeed    = %{$data->{ifspeed}};
    my %ifdescr    = %{$data->{ifdescr}};
    my %intdescr   = %{$data->{intdescr}};
    my %iftype     = %{$data->{iftype}};
    my %ifmtu      = %{$data->{ifmtu}};
    my %slotPortMapping   = %{$data->{slotPortMapping}};
    my $file = $opts->{file};

    ###
    ### START DEVICE CUSTOM CONFIG SECTION
    ###


    ###
    ### END DEVICE CUSTOM CONFIG SECTION
    ###

    # Saving local copies of runtime data
    %{$data->{ifspeed}} = %ifspeed;
    %{$data->{ifdescr}} = %ifdescr;
    %{$data->{intdescr}} = %intdescr;
    %{$data->{iftype}} = %iftype;
    %{$data->{ifmtu}} = %ifmtu;
    %{$data->{slotPortMapping}} = %slotPortMapping;

    return;
}

#-------------------------------------------------------------------------------
# custom_interfaces
# IN : current ifIndex, 
#      data reference for transient data
#      options refrence
# OUT: N/A
#-------------------------------------------------------------------------------

sub custom_interfaces {
    my ($self,$index,$data,$opts) = @_;

    # Saving local copies of runtime data
    my %ifspeed    = %{$data->{ifspeed}};
    my %ifdescr    = %{$data->{ifdescr}};
    my %intdescr   = %{$data->{intdescr}};
    my %iftype     = %{$data->{iftype}};
    my %ifmtu      = %{$data->{ifmtu}};
    my %slotPortMapping   = %{$data->{slotPortMapping}};
    my @config     = @{$data->{config}};
    my $hc         = $data->{hc};
    my $class      = $data->{class};
    my $match      = $data->{match};
    my $customsdesc = $data->{customsdesc};
    my $customldesc = $data->{customldesc};
    my $customfile = $data->{customfile};

    ###
    ### START DEVICE CUSTOM INTERFACE CONFIG SECTION
    ###

    if ($opts->{foundryint}) {

        ### Collect extra stats from the Foundry MIB

        # Apply logic for filtering option --gigonly interfaces
        next if ($opts->{gigonly} && int($ifspeed{$index}) != 1000000000 );

        push(@config, 'target-type' => 'foundry-interface' . $class . $hc);
    }

    ###
    ### END INTERFACE CUSTOM CONFIG SECTION
    ###

    # Saving local copies of runtime data
    %{$data->{ifspeed}}  = %ifspeed;
    %{$data->{ifdescr}}  = %ifdescr;
    %{$data->{intdescr}} = %intdescr;
    %{$data->{iftype}}   = %iftype;
    %{$data->{ifmtu}}    = %ifmtu;
    %{$data->{slotPortMapping}} = %slotPortMapping;
    @{$data->{config}} = @config;
    $data->{hc}     = $hc;
    $data->{class}  = $class;
    $data->{match}  = $match;
    $data->{customsdesc} = $customsdesc;
    $data->{customldesc} = $customldesc;
    $data->{customfile} = $customfile;

    return;
}

#-------------------------------------------------------------------------------
# custom_files
# IN : options hash
# OUT: returns the options hash
#-------------------------------------------------------------------------------

sub custom_files {
    my ($self,$data,$opts) = @_;

    # Saving local copies of runtime data
    my $customfile     = $data->{customfile};
    my $file           = $data->{file};
    my $c              = $data->{c};
    my $target         = $data->{target};
    my @config         = @{$data->{config}};
    my $wmatch         = $data->{wmatch};

    ###
    ### START FILE CUSTOM CONFIG SECTION
    ###


    ###
    ### END FILE CUSTOM CONFIG SECTION
    ###

    # Save return value in the reference hash
    $data->{wmatch}  = $wmatch;
}

1;
