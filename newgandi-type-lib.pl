# Functions for talking to gandi.net with the new API
use strict;
no strict 'refs';
use warnings;
our (%text);
our $module_name;
our $account;

my $newgandi_api_url_test = "https://rpc.ote.gandi.net/xmlrpc/";
my $newgandi_api_url = "https://rpc.gandi.net/xmlrpc/";

$@ = undef;
eval "use XML::RPC";
my $frontier_client_err = $@;

# Returns the name of this registrar
sub type_newgandi_desc
{
return $text{'type_newgandi'};
}

# Returns an error message if needed dependencies are missing
sub type_newgandi_check
{
if ($frontier_client_err) {
	my $rv = &text('gandi_eperl', "<tt>XML::RPC</tt>",
		     "<tt>".&html_escape($frontier_client_err)."</tt>");
	if (&foreign_available("cpan")) {
		$rv .= "\n".&text('gandi_cpan',
			"../cpan/download.cgi?source=3&cpan=XML::RPC&".
			"return=../$module_name/&".
			"returndesc=".&urlize($text{'index_return'}));
		}
	return $rv;
	}
return undef;
}

# type_newgandi_domains(&account)
# Returns a list of TLDs that can be used with gandi.net.
sub type_newgandi_domains
{
my ($account) = @_;
if ($account) {
	# Try to query gandi API
	my ($server, $sid) = &connect_newgandi_api($account, 1);
	if ($server) {
		my $doms;
		eval {
			$doms = $server->call("domain.tld.list", $sid);
			die $doms->{'faultString'} if (ref($doms) eq 'HASH' &&
						       $doms->{'faultString'});
			};
		if ($doms && !$@) {
			return map { ".".$_->{'name'} } @$doms;
			}
		}
	}
# Fall back to hard-coded list
return (
	".ae.org", ".aero", ".af", ".ag", ".ar.com", ".asia", ".at", ".be",
	".biz", ".br.com", ".bz", ".ca", ".cc", ".ch", ".cn", ".cn.com",
	".co", ".co.uk", ".com", ".com.de", ".coop", ".cx", ".de", ".de.com",
	".es", ".eu", ".eu.com", ".fm", ".fr", ".gb.com", ".gb.net", ".gr.com",
	".gs", ".gy", ".hk", ".hn", ".ht", ".hu.com", ".im", ".info",
	".it", ".jp", ".jpn.com", ".ki", ".kr.com", ".la", ".lc", ".li",
	".lt", ".lu", ".me", ".me.uk", ".mn", ".mobi", ".mu", ".name",
	".net", ".nf", ".nl", ".no", ".no.com", ".nu", ".org", ".org.uk",
	".pl", ".pro", ".pt", ".qc.com", ".re", ".ru", ".ru.com", ".sa.com",
	".sb", ".sc", ".se", ".se.com", ".se.net", ".tel", ".tl", ".travel",
	".tv", ".tw", ".uk.com", ".uk.net", ".us", ".us.com", ".us.org",
	".uy.com", ".vc", ".ws", ".xn--p1ai", ".za.com",
	);
}

# type_newgandi_edit_inputs(&account, new?)
# Returns table fields for entering the account login details
sub type_newgandi_edit_inputs
{
my ($account, $new) = @_;
my $rv;
$rv .= &ui_table_row($text{'gandi_contact'},
	&ui_textbox("gandi_account", $account->{'gandi_account'}, 30));
$rv .= &ui_table_row($text{'gandi_apikey'},
	&ui_textbox("gandi_apikey", $account->{'gandi_apikey'}, 30));
$rv .= &ui_table_row($text{'rcom_years'},
	&ui_opt_textbox("gandi_years", $account->{'gandi_years'},
			4, $text{'rcom_yearsdef'}));
$rv .= &ui_table_row($text{'rcom_test'},
	&ui_radio("gandi_test", int($account->{'gandi_test'}),
		  [ [ 1, $text{'rcom_test1'} ], [ 0, $text{'rcom_test0'} ] ]));
return $rv;
}

# type_newgandi_edit_parse(&account, new?, &in)
# Updates the account object with parsed inputs. Returns undef on success or
# an error message on failure.
sub type_newgandi_edit_parse
{
my ($account, $new, $in) = @_;
$in->{'gandi_account'} =~ /^\S+$/ || return $text{'gandi_eaccount'};
$account->{'gandi_account'} = $in->{'gandi_account'};
$in->{'gandi_apikey'} =~ /^\S+$/ || return $text{'gandi_eapikey'};
$account->{'gandi_apikey'} = $in->{'gandi_apikey'};
if ($in->{'gandi_years_def'}) {
	delete($account->{'gandi_years'});
	}
else {
	$in->{'gandi_years'} =~ /^\d+$/ && $in->{'gandi_years'} > 0 &&
	  $in->{'gandi_years'} <= 10 || return $text{'rcom_eyears'};
	$account->{'gandi_years'} = $in->{'gandi_years'};
	}
$account->{'gandi_test'} = $in->{'gandi_test'};
return undef;
}

# type_newgandi_renew_years(&account, &domain)
# Returns the number of years by default to renew a domain for
sub type_newgandi_renew_years
{
my ($account, $d) = @_;
return $account->{'gandi_years'} || 2;
}

# type_newgandi_validate(&account)
# Checks if an account's details are vaid. Returns undef if OK or an error
# message if the login or password are wrong.
sub type_newgandi_validate
{
my ($account) = @_;
my ($server, $sid_or_err) = &connect_newgandi_api($account, 1);
if ($server) {
	return undef;
	}
else {
	return $sid_or_err;
	}
}

# type_newgandi_check_domain(&account, domain)
# Checks if some domain name is available for registration, returns undef if
# yes, or an error message if not.
sub type_newgandi_check_domain
{
my ($account, $dname) = @_;
my ($server, $sid) = &connect_newgandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);
while(1) {
	my $avail;
	eval {
		$avail = $server->call("domain.available", $sid, [ $dname ]);
		die $avail->{'faultString'} if ($avail->{'faultString'});
		};
	return &text('gandi_error', "$@") if ($@);
	next if ($avail->{$dname} eq 'pending');
	return undef if ($avail->{$dname} eq 'available');
	return $text{'gandi_taken'};
	}
}

# type_newgandi_owned_domain(&account, domain, [id])
# Checks if some domain is owned by the given account. If so, returns the
# 1 and the registrar's ID - if not, returns 1 and undef, on failure returns
# 0 and an error message.
sub type_newgandi_owned_domain
{
my ($account, $dname, $id) = @_;
my ($server, $sid) = &connect_newgandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Get the domain list
my $info;
eval {
	$info = $server->call("domain.info", $sid, $dname);
	die $info->{'faultString'} if ($info->{'faultString'});
	};
return (0, &text('gandi_error', "$@")) if ($@);

if ($info) {
	# Found it
	return (1, $dname);
	}
else {
	# Not found
	return (1, undef);
	}
}

# type_newgandi_create_domain(&account, &domain)
# Actually register a domain, if possible. Returns 0 and an error message if
# it failed, or 1 and an ID for the domain on success.
sub type_newgandi_create_domain
{
my ($account, $d) = @_;
my ($server, $sid) = &connect_newgandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Get the nameservers
my $nss = &get_domain_nameservers($account, $d);
if (!ref($nss)) {
        return (0, $nss);
        }
elsif (!@$nss) {
        return (0, $text{'rcom_ensrecords'});
        }
elsif (@$nss < 2) {
	return (0, &text('gandi_enstwo', 2, $nss->[0]));
	}

# Check if the contact can be used
# Doesn't seem to have any value
#eval {
#	my $assoc = $server->call("contact.can_associate_domain",
#				     $sid,
#				     $account->{'gandi_account'},
#				     { 'domain' => $d->{'dom'},
#				       'owner' => $server->boolean(1),
#				       'admin' => $server->boolean(1) });
#	$assoc || return (0, &text('gandi_eassoc',
#				   $account->{'gandi_account'}));
#	};
#return (0, &text('gandi_error', "$@")) if ($@);

# Call to create
my $oper;
eval {
	my $spec = { 'duration' => $d->{'registrar_years'} ||
				      $account->{'gandi_years'} || 1,
			'owner' => $account->{'gandi_account'},
			'admin' => $account->{'gandi_account'},
			'bill' => $account->{'gandi_account'},
			'tech' => $account->{'gandi_account'},
			'nameservers' => $nss };
	$oper = $server->call("domain.create", $sid, $d->{'dom'}, $spec);
	die $oper->{'faultString'} if ($oper->{'faultString'});
	};
return (0, &text('gandi_error', "$@")) if ($@);

# Wait for completion
my ($ok, $msg) = &wait_for_gandi_operation($sid, $oper, $server);
return (0, &text('gandi_ecreate', $msg)) if (!$ok);

return (1, $d->{'dom'});
}

# type_newgandi_get_nameservers(&account, &domain)
# Returns a array ref list of nameserver hostnames for some domain, or
# an error message on failure.
sub type_newgandi_get_nameservers
{
my ($account, $d) = @_;
my ($server, $sid) = &connect_newgandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);

my $rv;
eval {
	my $info = $server->call("domain.info", $sid, $d->{'dom'});
	die $info->{'faultString'} if ($info->{'faultString'});
	$rv = $info->{'nameservers'};
	};
return $@ ? &text('gandi_error', "$@") : $rv;
}

# type_newgandi_set_nameservers(&account, &domain, [&nameservers])
# Updates the nameservers for a domain to match DNS. Returns undef on success
# or an error message on failure.
sub type_newgandi_set_nameservers
{
my ($account, $d, $nss) = @_;
my ($server, $sid) = &connect_newgandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Get nameservers in DNS
$nss ||= &get_domain_nameservers($account, $d);
if (!ref($nss)) {
	return $nss;
	}
elsif (!@$nss) {
	return $text{'rcom_ensrecords'};
	}
elsif (@$nss < 2) {
	return (0, &text('gandi_enstwo', 2, $nss->[0]));
	}

# Call to set nameservers
my $oper;
eval {
	$oper = $server->call("domain.nameservers.set",
			      $sid, $d->{'dom'}, $nss);
	die $oper->{'faultString'} if ($oper->{'faultString'});
	};
return &text('gandi_error', "$@") if ($@);

# Wait for result
my ($ok, $msg) = &wait_for_gandi_operation($sid, $oper, $server);
return $msg if (!$ok);

return undef;
}

# type_newgandi_delete_domain(&account, &domain)
# Deletes a domain previously created with this registrar
sub type_newgandi_delete_domain
{
my ($account, $d) = @_;
my ($server, $sid) = &connect_newgandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Call to delete
my $oper;
eval {
	$oper = $server->call("domain.delete", $sid, $d->{'dom'});
	die $oper->{'faultString'} if ($oper->{'faultString'});
	};
return (0, &text('gandi_error', "$@")) if ($@);

# Wait for result
my ($ok, $msg) = &wait_for_gandi_operation($sid, $oper, $server);
return (0, $msg) if (!$ok);

return (1, $oper->{'id'});
}

# type_newgandi_get_contact(&account, &domain)
# Returns a array containing hashes of domain contact information, or an error
# message if it could not be found.
sub type_newgandi_get_contact
{
my ($account, $d) = @_;
my ($server, $sid) = &connect_newgandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);

# Get the contact IDs and contact details
my $info;
eval {
	$info = $server->call("domain.info", $sid, $d->{'dom'});
	die $info->{'faultString'} if ($info->{'faultString'});
	};
return &text('gandi_error', "$@") if ($@);
my @rv;
foreach my $ct ('admin', 'tech', 'bill') {
	next if (!$info->{'contacts'}->{$ct});
	my $con;
	eval {
		$con = $server->call("contact.info", $sid,
				     $info->{'contacts'}->{$ct}->{'handle'});
		die $con->{'faultString'} if ($con->{'faultString'});
		};
	if (!$@ && $con) {
		$con->{'purpose'} = $ct;
		$con->{'id'} = $con->{'handle'};
		push(@rv, $con);
		}
	}

return \@rv;
}

# type_newgandi_save_contact(&&account, &domain, &contacts)
# Updates contacts from an array of hashes
sub type_newgandi_save_contact
{
my ($account, $d, $cons) = @_;

my ($server, $sid) = &connect_newgandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);

# Get existing contacts
my $oldcons = &type_newgandi_get_contact($account, $d);
return $oldcons if (!ref($oldcons));

# For changed contacts, create a new one and associate with the domain
my %sets;
my %same;
foreach my $c (@$cons) {
	my $purpose = $c->{'purpose'};
	my ($oldc) = grep { $_->{'purpose'} eq $purpose } @$oldcons;
	my $hash = &contact_hash_to_string($c);
	if ($oldc && $hash eq &contact_hash_to_string($oldc)) {
		# No change
		$same{$hash} = $c->{'handle'};
		next;
		}

	if ($same{$hash}) {
		# Re-use same contact
		$c->{'handle'} = $same{$hash};
		}
	else {
		# Make the new contact
		delete($c->{'handle'});
		my $pass = $d->{'parent'} ?
			&virtual_server::get_domain($d->{'parent'})->{'pass'} :
			$d->{'pass'};
		$pass ||= &virtual_server::random_password(6);
		if (length($pass) < 6) {
			$pass .= "12345";
			}
		$c->{'password'} = $pass;
		my $err = &type_newgandi_create_one_contact(
				$account, $c);
		return $err if ($err);
		$same{$hash} = $c->{'handle'};
		}
	$sets{$purpose} = $c->{'handle'};
	}

if (keys %sets) {
	# Update in the domain
	my $oper;
	eval {
		$oper = $server->call("domain.contacts.set", $sid,
				      $d->{'dom'}, \%sets);
		die $oper->{'faultString'} if ($oper->{'faultString'});
		};
	return &text('gandi_error', "$@") if ($@);

	my ($ok, $msg) = &wait_for_gandi_operation($sid, $oper, $server);
	return (0, $msg) if (!$ok);
	}

return undef;
}

# type_newgandi_get_contact_schema(&account, &domain, type, new?, class)
# Returns a list of fields for domain contacts, as seen by gandi.net
sub type_newgandi_get_contact_schema
{
my ($account, $d, $type, $newcontact, $cls) = @_;
return ( { 'name' => 'handle',
	   'readonly' => 1 },
         { 'name' => 'type',
	   'choices' => [ [ 0, $text{'gandi_individual'} ],
			  [ 1, $text{'gandi_company'} ],
			  [ 2, $text{'gandi_public'} ],
			  [ 3, $text{'gandi_association'} ] ],
	   'opt' => 0,
	   'readonly' => 1,
	 },
	 { 'name' => 'given',
	   'size' => 40,
	   'opt' => 0 },
	 { 'name' => 'family',
	   'size' => 40,
	   'opt' => 0 },
	 $cls == 1 || $cls == 2 || $cls == 3 ? (
		 { 'name' => 'orgname',
		   'size' => 40,
		   'opt' => 0,
		   'readonly' => !$newcontact },
		 ) :
		 ( ),
	 { 'name' => 'streetaddr',
	   'size' => 60,
	   'opt' => 0 },
	 { 'name' => 'city',
	   'size' => 40,
	   'opt' => 0 },
	 { 'name' => 'state',
	   'size' => 40,
	   'opt' => 1 },
         { 'name' => 'zip',
	   'size' => 10,
	   'opt' => 1 },
         { 'name' => 'country',
	   'choices' => [ map { [ $_->[1], $_->[0] ] } &list_countries() ],
	   'opt' => 1 },
         { 'name' => 'email',
	   'size' => 60,
	   'opt' => 0 },
         { 'name' => 'phone',
	   'size' => 40,
	   'opt' => 0 },
	 $newcontact ? ( { 'name' => 'password',
		           'size' => 40,
		           'opt' => 0 } )
		     : ( ),
	);
}

# type_newgandi_nice_contact_name(&contact)
# Returns a contact type and name string
sub type_newgandi_nice_contact_name
{
my ($con) = @_;
if ($con->{'type'} == 0) {
	return $con->{'handle'}." - ".
	       $con->{'given'}." ".$con->{'family'}.
	       " (".$text{'gandi_individual'}.")";
	}
else {
	return $con->{'handle'}." - ".
	       $con->{'orgname'}." (".
	       ($con->{'type'} == 1 ? $text{'gandi_company'} :
		$con->{'type'} == 2 ? $text{'gandi_public'} :
		$con->{'type'} == 3 ? $text{'gandi_association'} :
				      "Type $con->{'type'}").")";
	}
}

# type_newgandi_get_contact_classes(&account)
# Returns a list of hash refs with ID and desc fields, for different classes
# of contacts (individual, business, etc)
sub type_newgandi_get_contact_classes
{
my ($account) = @_;
return ( { 'id' => 0, 'desc' => $text{'gandi_individual'},
	   'field' => 'type' },
	 { 'id' => 1, 'desc' => $text{'gandi_company'},
	   'field' => 'type' },
	 { 'id' => 2, 'desc' => $text{'gandi_public'},
	   'field' => 'type' },
	 { 'id' => 3, 'desc' => $text{'gandi_association'},
	   'field' => 'type' } );
}

# type_newgandi_list_contacts(&account)
# Returns a list of all contacts associated with some Gandi account
sub type_newgandi_list_contacts
{
my ($account) = @_;
my ($server, $sid) = &connect_newgandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);
my $list;
eval {
	$list = $server->call("contact.list", $sid);
	die $list->{'faultString'} if (ref($list) eq 'HASH' &&
				       $list->{'faultString'});
	};
return (0, &text('gandi_error', "$@")) if ($@);
foreach my $con (@$list) {
	if (!defined($con->{'type'})) {
		# Not complete .. need to re-query this contact explicitly
		my $newcon = $server->call("contact.info", $sid,
                                     $con->{'handle'});
		foreach my $k (keys %$newcon) {
			$con->{$k} = $newcon->{$k};
			}
		}
	$con->{'id'} = $con->{'handle'};
	}
return (1, $list);
}

# type_newgandi_create_one_contact(&account, &contact)
# Create a single new contact for some account
sub type_newgandi_create_one_contact
{
my ($account, $con) = @_;
my ($server, $sid) = &connect_newgandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);

eval {
	my $callcon = { %$con };
	my @schema = &type_newgandi_get_contact_schema(
				$account, undef, undef, 1, $con->{'type'});
	foreach my $k (keys %$callcon) {
		delete($callcon->{$k}) if ($callcon->{$k} eq '');
		my ($s) = grep { $_->{'name'} eq $k } @schema;
		delete($callcon->{$k}) if (!$s || $s->{'readonly'});
		}
	$callcon->{'type'} = $con->{'type'};	# Always set, even though RO
	$callcon->{'zip'} = &as_string($con->{'zip'});
	$callcon->{'phone'} = &as_string($con->{'phone'});
	my $newcon = $server->call("contact.create", $sid, $callcon);
	die $newcon->{'faultString'} if ($newcon->{'faultString'});
	$con->{'id'} = $con->{'handle'} = $newcon->{'handle'};
	};
return &text('gandi_error', "$@") if ($@);

return undef;
}

# type_newgandi_modify_one_contact(&account, &contact)
# Update a single contact for some account. Doesn't send fields not in the
# schema, so they are left unchanged.
sub type_newgandi_modify_one_contact
{
my ($account, $con) = @_;
my ($server, $sid) = &connect_newgandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);

eval {
	my $callcon = { %$con };
	my @schema = &type_newgandi_get_contact_schema(
				$account, undef, undef, 0, $con->{'type'});
	foreach my $k (keys %$callcon) {
		delete($callcon->{$k}) if ($callcon->{$k} eq '');
		my ($s) = grep { $_->{'name'} eq $k } @schema;
		delete($callcon->{$k}) if (!$s || $s->{'readonly'});
		}
	$callcon->{'zip'} = &as_string($con->{'zip'});
	$callcon->{'phone'} = &as_string($con->{'phone'});
	my $newcon = $server->call("contact.update", $sid, $con->{'handle'},
				   $callcon);
	die $newcon->{'faultString'} if ($newcon->{'faultString'});
	};
return (0, &text('gandi_error', "$@")) if ($@);

return undef;
}

# type_newgandi_update_contacts(&account, &domain, &contacts)
# Sets the contacts used by some domain.
sub type_newgandi_update_contacts
{
my ($account, $d, $cons) = @_;
my ($server, $sid) = &connect_newgandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);

my $oper;
eval {
	my %cspec;
	foreach my $con (@$cons) {
		$cspec{$con->{'purpose'}} = $con->{'handle'};
		}
	$oper = $server->call("domain.contacts.set", $sid, $d->{'dom'}, \%cspec);
	die $oper->{'faultString'} if ($oper->{'faultString'});
	};
return (0, &text('gandi_error', "$@")) if ($@);

# Wait for completion
my ($ok, $msg) = &wait_for_gandi_operation($sid, $oper, $server);
return (0, &text('gandi_ecreate', $msg)) if (!$ok);

return undef;
}

# type_newgandi_get_expiry(&account, &domain)
# Returns either 1 and the expiry time (unix) for a domain, or 0 and an error
# message.
sub type_newgandi_get_expiry
{
my ($account, $d) = @_;
my ($server, $sid) = &connect_newgandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Call to get info
my $info;
eval {
	$info = $server->call("domain.info", $sid, $d->{'dom'});
	die $info->{'faultString'} if ($info->{'faultString'});
	};
return (0, &text('gandi_error', "$@")) if ($@);
my $expirydate = $info->{'date_registry_end'};
if ($expirydate =~ /^(\d{4})(\d\d)(\d\d)T(\d\d):(\d\d):(\d\d)$/) {
	return (1, timelocal($6, $5, $4, $3, $2-1, $1-1900));
	}
return (0, &text('gandi_eexpiry', $expirydate));
}

# type_newgandi_renew_domain(&account, &domain, years)
# Attempts to renew a domain for the specified period. Returns 1 and the
# registrars confirmation code on success, or 0 and an error message on
# failure.
sub type_newgandi_renew_domain
{
my ($account, $d, $years) = @_;
my ($server, $sid) = &connect_newgandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Call to renew
my $oper;
eval {
	my @tm = localtime(time());
	$oper = $server->call("domain.renew", $sid, $d->{'dom'},
			      { 'duration' => $years,
				'current_year' => $tm[5]+1900 });
	die $oper->{'faultString'} if ($oper->{'faultString'});
	};
return (0, &text('gandi_error', "$@")) if ($@);

# Wait for operation result
my ($ok, $msg) = &wait_for_gandi_operation($sid, $oper, $server);
return (0, $msg) if (!$ok);

return (1, $oper->{'id'});
}

# type_newgandi_add_instructions()
# Returns HTML for instructions to be shown on the account adding form, such
# as where to create one.
sub type_newgandi_add_instructions
{
return &text('gandi_newinstructions', 'https://www.gandi.net/resellers/',
				      'https://www.gandi.net/admin/apixml');
}

# type_newgandi_transfer_domain(&account, &domain, key)
# Transfer a domain from whatever registrar it is currently hosted with to
# this Gandi account. Returns 1 and an order ID on succes, or 0
# and an error mesasge on failure. If a number of years is given, also renews
# the domain for that period.
sub type_newgandi_transfer_domain
{
my ($account, $d, $key) = @_;

my ($server, $sid) = &connect_newgandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Get my nameservers
my $nss = &get_domain_nameservers($account, $d);
if (!ref($nss)) {
        return (0, $nss);
        }
elsif (!@$nss) {
        return (0, $text{'rcom_ensrecords'});
        }
elsif (@$nss < 2) {
	return (0, &text('gandi_enstwo', 2, $nss->[0]));
	}

# Do the transfer
my $oper;
eval {
	$oper = $server->call("domain.transferin.proceed", $sid, $d->{'dom'},
			     { 'owner' => $account->{'gandi_account'},
			       'admin' => $account->{'gandi_account'},
			       'bill' => $account->{'gandi_account'},
			       'tech' => $account->{'gandi_account'},
			       'nameservers' => $nss,
			       'authinfo' => $key,
			       'duration' => $d->{'registrar_years'} ||
                                      $account->{'gandi_years'} || 1,
			     });
	die $oper->{'faultString'} if ($oper->{'faultString'});
	};
return (0, &text('gandi_error', "$@")) if ($@);

# Wait for completion
my ($ok, $msg) = &wait_for_gandi_operation($sid, $oper, $server);
return (0, $msg) if (!$ok);

return (1, $oper->{'id'});
}

# connect_newgandi_api(&account, [return-error])
# Returns a handle connected to the Gandi XML-RPC API and a session ID,
# or calls error
my %done_connect_newgandi_api;
sub connect_newgandi_api
{
my ($account, $reterr) = @_;
my $server;
eval {
	$server = XML::RPC->new(
		$account->{'gandi_test'} ? $newgandi_api_url_test
					 : $newgandi_api_url);
	};
if ($@) {
	if ($reterr) {
		return (undef, $@);
		}
	else {
		&error($@);
		}
	}
my $dkey = $account->{'id'}."/".$account->{'gandi_apikey'}."/".
	      int($account->{'gandi_test'});
if ($done_connect_newgandi_api{$dkey}) {
	# Already tested successfully
	return ($server, $account->{'gandi_apikey'});
	}
my $ver;
eval {
	$ver = $server->call("version.info", $account->{'gandi_apikey'});
	die $ver->{'faultString'} if ($ver->{'faultString'});
	};
my @rv = $@ =~ /DataError:\s*(.*)/ ? ( undef, $1 ) :
       	    $@ ? (undef, $@) :
            !$ver ? (undef, "No version returned")
	          : ($server, $account->{'gandi_apikey'});
if ($rv[0]) {
	$done_connect_newgandi_api{$dkey} = $account->{'gandi_apikey'};
	}
return @rv;
}

# wait_for_gandi_operation(sid, &operation, &server)
# Poll the Gandi API until some operation completes. Returns 0 and an error
# message on failure, or 1 and the result structure on success.
sub wait_for_gandi_operation
{
my ($sid, $oper, $server) = @_;
my $tries = 0;
while(1) {
	sleep(1);
	my $rv = $server->call("operation.info", $sid, $oper->{'id'});
	if ($rv->{'step'} eq 'DONE') {
		return (1, $rv);
		}
	elsif ($rv->{'step'} eq 'ERROR') {
		return (0, $rv->{'last_error'} || $rv->{'faultString'});
		}
	elsif ($rv->{'faultString'}) {
		return (0, $rv->{'faultString'});
		}
	$tries++;
	if ($tries > 30) {
		return (0, &text('gandi_etries', $rv->{'step'}, 30));
		}
	}
}

sub as_string
{
my ($val) = @_;
return sub { { string => $val }; };
}

1;
