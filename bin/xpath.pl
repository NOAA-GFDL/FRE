#!/usr/bin/env perl
# -*- cperl -*-
# $Id: xpath.pl,v 18.1 2011/01/21 20:57:33 fms Exp $
# ------------------------------------------------------------------------------
# xpath
# ------------------------------------------------------------------------------

use strict;
use XML::LibXML;
use Getopt::Long( ':config', 'no_ignore_case' );

my %options = ( 'xmlfile|x=s', 'expression|e=s' );

my %opt = ();

Getopt::Long::GetOptions( \%opt, %options ) or ( print 'bad opts' and die "\n" );

my $parser = XML::LibXML->new();
my $root   = $parser->parse_file( $opt{xmlfile} )->getDocumentElement;
print STDOUT $root->findvalue("$opt{expression}") . "\n";

