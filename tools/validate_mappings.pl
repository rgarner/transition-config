#!/usr/bin/env perl

#
#  validate a redirector mappings format CSV file
#
use v5.10;
use strict;
use warnings;

use Test::More;
use Text::CSV;
use Getopt::Long;
use Pod::Usage;
use HTTP::Request;
use LWP::UserAgent;
use URI;

my $skip_canonical;
my $check_duplicates;
my $allow_https;
my $whitelist = "data/whitelist.txt";
my $host = "";
my %hosts = ();
my %seen = ();
my $help;

GetOptions(
    "skip-canonical|c"  => \$skip_canonical,
    "check-duplicates|d"  => \$check_duplicates,
    "allow-https|s"  => \$allowhttps,
    "host|h=s"  => \$host,
    "whitelist|w=s"  => \$whitelist,
    'help|?' => \$help,
) or pod2usage(1);

pod2usage(2) if ($help);

load_whitelist($whitelist);

foreach my $filename (@ARGV) {
    %seen = ();
    check_unquoted($filename);
    test_file($filename);
}

done_testing();

exit;

sub test_file {
    my $filename = shift;
    my $csv = Text::CSV->new({ binary => 1 }) or die "Cannot use CSV: " . Text::CSV->error_diag();

    open(my $fh, "<", $filename) or die "$filename: $!";

    my $names = $csv->getline($fh);
    $csv->column_names(@$names);

    while (my $row = $csv->getline_hr($fh)) {
        test_row($row);
    }
}

sub test_row {
    my $row  = shift;

    my $old_url = $row->{'Old Url'} // '';
    my $new_url = $row->{'New Url'} // '';
    my $status = $row->{'Status'} // '';

    my $old_uri = check_url('Old Url', $old_url);

    my $scheme = $old_uri->scheme;

    my $s = ($allow_https) ? "s?": "";
    ok($scheme =~ m{^http$s$}, "Old Url [$old_url] scheme [$scheme] must be [http] line $.");

    ok($old_url =~ m{^https?://$host}, "Old Url [$old_url] host not [$host] line $.");

    my $c14n = c14n_url($old_url);

    unless (!$skip_canonical) {
        is($old_url, $c14n, "Old Url [$old_url] is not canonical [$c14n] line $.");
    }

    if ($check_duplicates) {
        ok(!defined($seen{$c14n}), "Old Url [$old_url] line $. is a duplicate of line " . ($seen{$c14n} // ""));
        $seen{$c14n} = $.;
    }

    if ( "301" eq $status) {
        my $new_uri = check_url('New Url', $new_url);
        my $new_host = $new_uri->host;
        ok($hosts{$new_host}, "New Url [$new_url] host [$new_host] not whiltelist line $.");
    } elsif ( "410" eq $status) {
        ok($new_url eq '', "unexpected New Url [$new_url] for 410 line $.");
    } elsif ( "200" eq $status) {
        ok($new_url eq '', "unexpected New Url [$new_url] for 200 line $.");
    } else {
       fail("invalid Status [$status] for Old Url [$old_url] line $.");
    }
}

sub check_url {
    my ($name, $url) = @_;

    # | is valid in our Urls
    $url =~ s/\|/%7C/g;

    ok($url =~ m{^https?://}, "$name '$url' should be a full URI line $.");

    my $uri = URI->new($url);
    is($uri, $url, "$name '$url' should be a valid URI line $.");

    return $uri;
}

sub c14n_url {
    my ($url) = @_;
    $url = lc($url);
    $url =~ s/\?*$//;
    $url =~ s/\/*$//;
    $url =~ s/\#*$//;
    $url =~ s/,/%2C/;
    return $url;
}

sub load_whitelist {
    my $filename = shift;
    local *FILE;
    open(FILE, "< $filename") or die "unable to open whitelist $filename";
    while (<FILE>) {
        chomp;
        $_ =~ s/\s*\#.*$//;
        $hosts{$_} = 1 if ($_);
    }
}

sub check_unquoted {
    my $filename = shift;
    open(FILE, "< $filename") or die "unable to open whitelist $filename";
    my $contents = do { local $/; <FILE> };
    ok($contents !~ /["']/, "file [$filename] contains quotes");
}

__END__

=head1 NAME

validate_csv - validate a redirector mappings format CSV file

=head1 SYNOPSIS

prove tools/validate_csv.pl :: [options] [file ...]

Options:

    -c, --skip-canonical        don't check for canonical Old Urls
    -d, --check-duplicates      check for duplicate Old Urls
    -h, --host host             constrain Old Urls to host
    -s, --allow-https           allow https in Old Urls
    -w, --whitelist filename    constrain New Urls to those in a whitelist
    -?, --help                  print usage

=cut
