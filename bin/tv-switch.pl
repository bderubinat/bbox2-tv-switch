#!/usr/bin/perl -w

###############################################################################
#
# Author: Bernard de Rubinat <bernard@derubinat.net>
#
# Licence: GNU GENERAL PUBLIC LICENSE v2
# 
###############################################################################

use strict;

use FindBin qw($Bin);
use lib "$Bin/../etc";

use Compress::Zlib;
use Data::Dumper;
use Getopt::Long;
use HTTP::Cookies;
use LWP;
use Pod::Usage;
use Switch;
use WWW::Mechanize;

use feature "switch";

# Default config vars

our @plug = ('plug1', 'plug2', 'plug3', 'plug4');
our $bbox = "192.168.1.1";

# Overwrite config vars
require "tv-switch.inc";


=head1 BBox2 TV switcher

=over 12

=item Purpose

Switch on or off TV plugs 3 and 4.

=item Syntax

tv-switch.pl status		# returns the status of plugs
tv-switch.pl [on|off]		# set the status of both plugs
tv-switch.pl [on|off] [on|off]	# set the sattus of plug 3 and plug 4


=back

=cut

my ($debug, $help);

GetOptions (
        "debug"     => \$debug,
        'help'      => \$help,
        );

pod2usage(-exitstatus => 0, -verbose => 2) if ($help);


$|=1;
local $^W = 0;

my $tvstate;
my $tvstate2;

my $user_agent;
my $page_content;
my $fetch_url;
my $response;

my $db_group_members_page;

my %header = ( );

my $cookie_jar = HTTP::Cookies->new();


my $browser = WWW::Mechanize->new(
	onwarn => undef,
	onerror => undef);

$browser->cookie_jar($cookie_jar);

sub save_page {
    my ($fn, $html) = @_;
    open LOG, ">/tmp/$fn.html";
    print LOG $html;
    close LOG;
}

sub get_page {
    my ($url, $fn) = @_;

    $debug and print "Getting $fn\n";

    my $res = $browser->get($url, %header);
    $cookie_jar->extract_cookies( $response );

    my $content = $res->content;

    save_page($fn, $content);

    $header{Referer} = $url;

    return $res;
}



my $home="http://$bbox/";

my $res;


switch ($ARGV[0]) {
	case "on" { $tvstate='on' }
	case "off" { $tvstate='off' }
	case "status" { $tvstate='status' }
	default {die "missing argument.\n Args: [on|off|status] [on|off]"; }
}

given ($ARGV[1]) {
	when (/^on$/)  { $tvstate2='on' }
	when (/^off$/) { $tvstate2='off' }
	default        { $tvstate2 = $tvstate }
}


$res = get_page($home, "home");

my $id;
$id=`/bin/grep f.action= /tmp/home.html |head -1|cut -d\\" -f2`;
chomp $id;

$browser->form_name('form_contents')->action("http://$bbox$id");
$browser->field('mimic_button_field'=>'sidebar: lb_sidebar_advanced_main..');
$res=$browser->submit_form();
save_page("adv",$res->content);


$id=`/bin/grep f.action= /tmp/home.html |head -1|cut -d\\" -f2`;
chomp $id;
$browser->form_name('form_contents')->action("http://$bbox$id");
$browser->field('mimic_button_field'=>'sidebar: lb_sidebar_advanced_network..');
$res=$browser->submit_form();
save_page("route",$res->content);


$id=`/bin/grep f.action= /tmp/home.html |head -1|cut -d\\" -f2`;
chomp $id;
$browser->form_name('form_contents')->action("http://$bbox$id");
$browser->field('mimic_button_field'=>'btn_tab_goto: 810..');
$res=$browser->submit_form();
save_page("routing",$res->content);


$id=`/bin/grep f.action= /tmp/home.html |head -1|cut -d\\" -f2`;
chomp $id;
$browser->form_name('form_contents')->action("http://$bbox$id");

printf ("%s: on\n", $plug[0])  if ($browser->value('tv_port_1'));
printf ("%s: on\n", $plug[1])  if ($browser->value('tv_port_2'));
printf ("%s: on\n", $plug[2])  if ($browser->value('tv_port_3'));
printf ("%s: on\n", $plug[3])  if ($browser->value('tv_port_4'));

my $post = undef;
switch ("$tvstate$tvstate2") {
	case 'onon' {
			$browser->tick('tv_port_3',1,1);
			$browser->tick('tv_port_4',1,1);
			$post=1;
		}
	case 'offoff' {
			$browser->untick('tv_port_3',1);
			$browser->untick('tv_port_4',1);
			$post=1;
		}
	case 'onoff' {
			$browser->tick('tv_port_3',1,1);
			$browser->untick('tv_port_4',1,1);
			$post=1;
		}
	case 'offon' {
			$browser->untick('tv_port_3',1,1);
			$browser->tick('tv_port_4',1,1);
			$post=1;
		}

}

if ($post) {
	$browser->field('mimic_button_field'=>'submit_button_apply: ..');
	$res=$browser->submit_form();
	save_page("applied",$res->content);

	print "Now:\n";

	printf ("%s: on\n", $plug[0])  if ($browser->value('tv_port_1'));
	printf ("%s: on\n", $plug[1])  if ($browser->value('tv_port_2'));
	printf ("%s: on\n", $plug[2])  if ($browser->value('tv_port_3'));
	printf ("%s: on\n", $plug[3])  if ($browser->value('tv_port_4'));
}

