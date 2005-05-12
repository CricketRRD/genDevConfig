# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2005 Francois Mikus
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

package Packeteer;

use strict;

use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;

### Start package init

use genConfig::Plugin;

our @ISA = qw(genConfig::Plugin);

my $VERSION = 1.00;

### End package init


# These are the OIDS used by this plugin
# the OIDS should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.
my %OIDS = (

       ### Packeteer OIDs
       'partitionMinimumBps'     => '1.3.6.1.4.1.2334.2.1.3.2.1.24',
       'classFullName'           => '1.3.6.1.4.1.2334.2.1.4.2.1.36',
       
      );

###############################################################################
## These are device types we can handle in this plugin
## the names should be contained in the sysdescr string
## returned by the devices. The name is a regular expression.
################################################################################
my @types = ( "Packeteer");


###############################################################################
### Private variables
###############################################################################

my $snmp;

my $req_pixconn = 1; # Enabled by default
my $pixconn;

my $script = "Packeteer genDevConfig Module";

###############################################################################
###############################################################################

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
# IN : options reference
# OUT: N/A
#-------------------------------------------------------------------------------

sub discover {
    my($self, $opts) = @_;

    ### Add our OIDs to the the global OID list

    register_oids(%OIDS);

    ###
    ### START DEVICE DISCOVERY SECTION
    ###

    ### Figure out the OS version number this device is running.  
    ### We need this to figure out which oid to use to get
    ### interface descriptions and which MIBs are supported.


    ### PACKETEER GENERIC SECTION
    
    $opts->{model} = 'Packeteer';
    $opts->{class} = 'packeteer';
    $opts->{chassisttype} = 'Generic-Device';
    $opts->{chassisname} = 'Chassis-Packeteer';

    #$opts->{vendor_soft_ver} = get('versionOID');

    # Default feature promotions for Packeteer
    $opts->{packeteerbox} = 1;
    $opts->{chassiscollect} = 0; # Do not collect any stats on the chassis. No OIDs defined. :-(

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

    ### CAR Traffic shaping stats for packeteer
    ###

    my %classFullName;
    my %partitionMinimumBps;
    if ($opts->{packeteerbox}) {
        %classFullName = gettable('classFullName');
        %partitionMinimumBps = gettable('partitionMinimumBps');
    }

    if (keys(%classFullName)) {
        my $index;
        my $speed_str;
        foreach $index (sort { $a <=> $b } keys(%classFullName)) {
            if (defined $partitionMinimumBps{$index}) {
                    my $b = ($opts->{units} eq "bytes") ? 8 : 1;
                    my $speed = int($partitionMinimumBps{$index} / $b); # bits to bytes
                    $speed_str = ($speed) ? fmi($speed, $opts->{units}) : '';
            } else {
                    $speed_str = "nil";
            }
            my $name = "$opts->{router}.$index";
            my $target = $classFullName{$index};
            ### If we already have _ in the name, replace them with -, other wies it will stuff up the split function below.
            $target =~ s/\_/\-/g;

            ### Drop the leading /, and replace / : or space with _
            $target =~ s/^\///;
            $target =~ s/[\/\s:]/\_/g;
            my $ldesc = ((defined $classFullName{$index}) ? $classFullName{$index} : '');
            $ldesc .= "<BR>$name" if ($name);

            my $sdesc;
            if ($speed_str eq "nil") {
                    $sdesc = "";
            }else{
                    $ldesc .= "<BR>$speed_str";
                    $sdesc = "$speed_str";
            }

            $file->writetarget($target, '',
                    ('interface-name' => $classFullName{$index},
                    'display-name' => '%interface-name%',
                    'target-type'  => 'packeteer-class',
                    'short-desc'     => $sdesc,
                    'long-desc'      => $ldesc,
                    'order'          => $opts->{order},
                    'inst'           => $index
                    ) );

        $opts->{order} -= 1;
       }
    }
  
        
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
#      options reference
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
