use strict;
use warnings;
use Test::More tests => 4;
use Mappings;

use constant REDIRECT_NGINX => qq(location = /en/MoneyTaxAndBenefits/TaxCredits/Gettingstarted/whoqualifies/DG_201943 { return 301 https://www.gov.uk/working-tax-credit/overview; }\n);



my $mappings = Mappings->new( 'tests/migratorator_mappings/has_space.csv' );
isa_ok( $mappings, 'Mappings' );

my( $r_host, $r_type, $redirect ) = $mappings->row_as_nginx_config();

is( $r_host,        'www.direct.gov.uk', 'redirect host is directgov' );
is( $r_type,        'location',          'redirect type is location' );
is( REDIRECT_NGINX, $redirect,           'redirect' );
