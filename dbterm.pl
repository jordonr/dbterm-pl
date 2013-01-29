#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use DBI;
use Tkx;
use Tkx::FindBar;
use Tkx::ROText;
use Tkx::Scrolled;
use Text::TabularDisplay;

#  dbterm.rb
#  
#  Copyright 2013 jordonr <jordonr@dev-linux>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#  
#  

our $dbh;
our $textIn;

my $mw = Tkx::widget->new('.');
$mw->g_wm_title("DBTerm");

## Bindings ##
$mw->g_bind("<F6>", \&runAll);
$mw->g_bind("<F7>", \&runSel);
$mw->g_bind("<F10>", \&quit);
## /Bindings ##

my $topFrame = $mw->new_frame();

## Buttons ##
our $connectButton = $topFrame->new_button(
       -text => "Connect",
       -command => sub { \&logIn() },
  )->g_pack(-side => 'left', -anchor => 'nw');
  
our $disconnectButton = $topFrame->new_button(
       -text => "Disconnect",
       -command => sub { \&dbDisconnect() },
  )->g_pack(-side => 'left', -anchor => 'nw');

$topFrame->new_button(
       -text => "Run All (F6)",
       -command => sub { \&runAll() },
  )->g_pack(-side  => 'right', -anchor => 'w');

$topFrame->new_button(
       -text => "Run Selected (F7)",
       -command => sub { \&runSel() },
  )->g_pack(-side  => 'right', -anchor => 'w');
  
$topFrame->new_button(
       -text => "About",
       -command => sub { \&about() },
  )->g_pack(-side  => 'right', -anchor => 'w');
  
$topFrame->new_button(
  -text => "Exit (F10)",
  -command => sub { \&quit() },
)->g_pack(-side  => 'right', -anchor => 'w');
## /Buttons ##

$topFrame->g_pack(-side => 'top', -anchor => 'nw');

my $outFrame = $mw->new_frame();

our $textOut = $outFrame->new_tkx_Scrolled('tkx_ROText',
    -scrollbars => 'osoe',
    -wrap       => 'none',
);

my $findbar = $outFrame->new_tkx_FindBar(-textwidget => $textOut);

$findbar->add_bindings($mw,
    '<Control-f>'  => 'show',
    '<Escape>'     => 'hide',
    '<F3>'         => 'next',
    '<Control-F3>' => 'previous',
);

$textOut->g_pack(-fill => 'both', -expand => 1, -fill  => 'both');

$findbar->g_pack(
    -after => $textOut,
    -side  => 'bottom',
    -fill  => 'both',
);

$outFrame->g_pack(-side => 'top', -anchor => 'nw', -expand => 1, -fill  => 'both');

my $inFrame = $mw->new_frame();

$textIn = $inFrame->new_tkx_Scrolled('text',
    -scrollbars => 'osoe',
    -wrap => 'word',
    -height => 5,
    -bd => 1,
    -undo => 1,
);

$textIn->insert('end',"show databases;");

$textIn->g_pack(-fill => 'both', -expand => 1, -fill  => 'both');

$inFrame->g_pack(-side => 'top', -anchor => 'nw', -expand => 1, -fill  => 'both');

$findbar->hide();

my $bottomFrame = $mw->new_frame(-bd => 1);

#our $statusLabel = $bottomFrame->new_label(-text => "Status")->g_pack(-side => 'left', -anchor => 'nw');

#our $errorLabel = $bottomFrame->new_label(-text => "Errors")->g_pack(-side => 'right', -anchor => 'nw');

$bottomFrame->g_pack(-side => 'top', -anchor => 'nw', -fill  => 'x');

$mw->g_focus();
Tkx::MainLoop();

## Functions ##

sub about {
     Tkx::tk___messageBox(
        -parent => $mw,
        -title => "About \uDBTerm",
        -type => "ok",
        -icon => "info",
        -message => "DBTerm\n" .
                    "Copyright 2010 Jordon Replogle. " .
                    "All rights reserved."
               );
}

sub dbConnect {
	my ($host, $port, $uname, $passwd, $db) = @_;
	
	if($port eq "") {
		$port = 3306;
	}
	
	eval { $dbh->disconnect(); };
	
	$dbh = DBI->connect("DBI:mysql:database=$db;host=$host;port=$port",
		"$uname", "$passwd",
          {'RaiseError' => 1});
	
	$mw->g_wm_title("DBTerm - " . $host);
	printResults("Connected!");
}

sub dbDisconnect {
	$dbh->disconnect();
	$mw->g_wm_title("DBTerm");
	printResults("Disconnected!");
}

sub getAllText {
	return $textIn->get('0.1', 'end');
}

sub getSelText {
	return $textIn->get('sel.first', 'sel.last');
}

sub printResults {
	my $dump = shift;
	$textOut->insert('end', "$dump\n\n\n");
	$textOut->see('end');
	return 1;
}

sub querydb {
	my $q = shift;
	my $t = Text::TabularDisplay->new();
	my $sth;
	
	eval {
		$sth = $dbh->prepare($q);
	}; return $@ if $@;
	
	eval {
		if (!$sth) {
			print "Error:" . $dbh->errstr . "\n";
		}
		if (!$sth->execute) {
			print "Error:" . $sth->errstr . "\n";
		}
	}; return $@ if $@;
	
	eval {
		my $names = $sth->{'NAME'};
		my $numFields = $sth->{'NUM_OF_FIELDS'};
		my @results;
		
		for (my $i = 0;  $i < $numFields;  $i++) {
			$results[$i] = $$names[$i];
		}
		$t->columns(@results);
		
		if(ref($names) eq "ARRAY") {

			while (my $ref = $sth->fetchrow_arrayref) {
				$t->add($ref);
			}
			
		}
		else {
			$t->add($sth->rows);
		}
		
	}; return $@ if $@;
	
	$sth->finish();
	
	return $t->render . "\nAffected Rows: " . $sth->rows;
}

sub quit {
	eval { $dbh->disconnect(); };
	$mw->g_destroy;
}

sub runAll {
	my $query = getAllText();
	$query = querydb($query);
	printResults($query);
	return 1;	
}

sub runSel {
	my $txtBox = shift;
	my $query = getSelText($txtBox);
	$query = querydb($query);
	printResults($query);
	return 1;
}

sub loopHash {
	my %hash = shift;
	my $text;
	
	foreach my $key ( keys %hash )
	{
		$text .= "key: $key, value: $hash{$key}\n";
	}
	return $text;
}

sub alertMe {
	my $message = shift;
     Tkx::tk___messageBox(
        -parent => $mw,
        -title => "Alert",
        -type => "ok",
        -icon => "warning",
        -message => $message
        );
}

sub logIn {
	my $dbTxt;
	my $hostEntryTxt;
	my $portEntryTxt;
	my $unameEntryTxt;
	my $passwdEntryTxt;
	
	my $lw = $mw->new_toplevel;
	$lw->g_wm_title("Connection Info");
	
	my $body = $lw->new_frame();
	
	my $line0 = $body->new_frame();
	$line0->new_label(-text => "Database:")->g_pack(-side => 'left', -anchor => 'ne');
	my $db = $line0->new_entry(-textvariable => \$dbTxt)->g_pack(-side => 'right', -anchor => 'e');
	$line0->g_pack();
	
	my $line1 = $body->new_frame();
	$line1->new_label(-text => "Host:")->g_pack(-side => 'left', -anchor => 'ne');
	$line1->new_entry(-textvariable => \$hostEntryTxt)->g_pack(-side => 'right', -anchor => 'e');
	$line1->g_pack();
	
	my $line2 = $body->new_frame();
	$line2->new_label(-text => "Port:")->g_pack(-side => 'left', -anchor => 'ne');
	$line2->new_entry(-textvariable => \$portEntryTxt)->g_pack(-side => 'right', -anchor => 'e');
	$line2->g_pack();
	
	my $line3 = $body->new_frame();
	$line3->new_label(-text => "User Name:")->g_pack(-side => 'left', -anchor => 'ne');
	$line3->new_entry(-textvariable => \$unameEntryTxt)->g_pack(-side => 'right', -anchor => 'e');
	$line3->g_pack();
	
	my $line4 = $body->new_frame();
	$line4->new_label(-text => "Password:")->g_pack(-side => 'left', -anchor => 'ne');
	$line4->new_entry(-show => '*', -textvariable => \$passwdEntryTxt)->g_pack(-side => 'right', -anchor => 'e');
	$line4->g_pack();
	
	my $line5 = $body->new_frame();
	$line5->new_button(
		-text => "Go!",
		-command => sub { \&dbConnect($hostEntryTxt, $portEntryTxt, $unameEntryTxt, $passwdEntryTxt, $dbTxt); $lw->g_destroy; }
		)->g_pack(-side => 'right', -anchor => 'ne', -padx => 5, -pady => 2);
	$line5->g_pack(-side => 'right');
	
	$body->g_pack();
}
