#!/usr/local/bin/perl
# Show a form for dis-associating a domain registration with this server

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'dereg_err'});
$access{'registrar'} || &error($text{'import_ecannot'});

# Get the Virtualmin domain
$d = &virtual_server::get_domain_by("dom", $in{'dom'});
$d || &error(&text('contact_edom', $in{'dom'}));
$d->{$module_name} || &error($text{'dereg_ealready'});
($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
		  &list_registrar_accounts();
$account || &error(&text('contact_eaccount', $in{'dom'}));

&ui_print_header(&virtual_server::domain_in($d), $text{'dereg_title'}, "",
		 "dereg");

print "<center>\n";
print &ui_form_start("dereg.cgi", "post");
print &ui_hidden("dom", $in{'dom'});
print &text('dereg_rusure', "<i>$account->{'desc'}</i>"),"<p>\n";
print &ui_form_end([ [ undef, $text{'dereg_ok'} ] ]);
print "</center>\n";

&ui_print_footer(&virtual_server::domain_footer_link($d));
