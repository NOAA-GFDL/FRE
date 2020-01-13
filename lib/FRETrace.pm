#
# $Id: FRETrace.pm,v 18.0 2010/03/02 23:59:00 fms Exp $
# ------------------------------------------------------------------------------
# FMS/FRE Project: Trace Management Module
# ------------------------------------------------------------------------------
# afy    Ver   1.00  Initial version                                October 09
# afy    Ver   2.00  Replace prints by calls to FREMsg::out         November 09
# ------------------------------------------------------------------------------
# Copyright (C) NOAA Geophysical Fluid Dynamics Laboratory, 2000-2009
# Designed and written by V. Balaji, Amy Langenhorst and Aleksey Yakovlev
#

package FRETrace;

use strict;

use DBI();

use FREMsg();

# //////////////////////////////////////////////////////////////////////////////
# ////////////////////////////////////////////////////////// Global Constants //
# //////////////////////////////////////////////////////////////////////////////

use constant DBI_CNF_FILENAME => 'fre.mysql.cnf';
use constant DBI_CMD_INSERT   => '
  INSERT fre_trace(user_id, tool_name, tool_version, xmlfile, platform, target, options, arguments)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?)
';

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////// Exported Functions //
# //////////////////////////////////////////////////////////////////////////////

sub insert($$$$)

    # ------ arguments: $siteDir $caller $xmlfile $refToOptions
{
    my ( $d, $c, $f, $r ) = @_;
    if ( scalar( grep( $_ eq 'mysql', DBI->available_drivers(1) ) ) > 0 ) {
        my $cnf = $d . '/' . DBI_CNF_FILENAME;
        my $dbh
            = DBI->connect( "DBI:mysql:mysql_read_default_file=$cnf", '', '', { PrintError => 0 } );
        if ($dbh) {
            chomp( my $versionId = qx($c -V) );
            my $versionNo = ( $versionId =~ m/(\d+(?:\.\d+)+)/ ) ? $1 : '';
            my $options = '';
            foreach my $key ( sort( keys( %{$r} ) ) ) {
                if ( scalar( grep( $_ eq $key, ( 'platform', 'target', 'xmlfile' ) ) ) == 0 ) {
                    $options .= ' ' if $options;
                    $options .= $key . '=' . $r->{$key};
                }
            }
            my $sth = $dbh->prepare(DBI_CMD_INSERT);
            my $res = $sth->execute(
                $ENV{USER},   $c,       $versionNo, $f, $r->{platform},
                $r->{target}, $options, join ' ',   @ARGV
            );
            FREMsg::out( $r->{verbose}, 3, "Database insertion failed" ) unless $res;
            $dbh->disconnect();
            return ($res) ? 1 : 0;
        }
        else {
            FREMsg::out( $r->{verbose}, 3, "Database connection failed" );
            return 0;
        }
    } ## end if ( scalar( grep( $_ ...)))
    else {
        FREMsg::out( $r->{verbose}, 3, "Database driver isn't found" );
        return 0;
    }
} ## end sub insert($$$$)

# //////////////////////////////////////////////////////////////////////////////
# //////////////////////////////////////////////////////////// Initialization //
# //////////////////////////////////////////////////////////////////////////////

return 1;
