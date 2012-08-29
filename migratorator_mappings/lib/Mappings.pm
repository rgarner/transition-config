package Mappings;

use strict;
use warnings;

use Text::CSV;
use URI::Split  qw( uri_split uri_join );



sub new {
    my $class    = shift;
    my $csv_file = shift;
    
    my $self = {};
    bless $self, $class;
    
    $self->{'csv'} = Text::CSV->new({ binary => 1 });
    open $self->{'csv_handle'}, '<:encoding(utf8)', $csv_file
        or return undef;
    
    $self->{'column_names'} = $self->read_column_names();
    return unless scalar @{$self->{'column_names'}};
    return unless $self->has_mandatory_columns();
    
    return $self;
}

sub entire_csv_as_nginx_config {
    my $self = shift;
    
    my %configs;
    while ( my( $host, $line ) = $self->row_as_nginx_config() ) {
        $configs{$host} = []
            unless defined $configs{$host};
        push @{ $configs{$host} }, $line;
    }
    
    foreach my $host ( keys %configs ) {
        $configs{$host} = join '', sort @{ $configs{$host} };
    }
    
    return \%configs;
}
sub row_as_nginx_config {
    my $self = shift;
    my $row  = $self->get_row();
    
    return unless defined $row;
    
    my $status  = $row->{'Status'};
    my $new_url = $row->{'New Url'};
    
    my( $scheme, $host, $path, $query, $frag ) = uri_split $row->{'Old Url'};
    my $old_url = uri_join undef, undef, $path, $query, $frag;
    
    # strip potential trailing whitespace
    $new_url =~ s{\s+$}{};
    $old_url =~ s{\s+$}{};
    
    return( $host, "location = $old_url { return 410; }\n" )
        if '410' eq $status && length $old_url;
    return( $host, "location = $old_url { return 301 $new_url; }\n" )
        if '301' eq $status && length $old_url && length $new_url;
    
    return(
        $host,
        "# invalid entry: status='$status' old='$row->{'Old Url'}' new='$new_url'\n"
    );
}
sub get_row {
    my $self = shift;
    return $self->{'csv'}->getline_hr( $self->{'csv_handle'} );
}

sub read_column_names {
    my $self = shift;
    
    my $names = $self->{'csv'}->getline( $self->{'csv_handle'} );
    return unless scalar @$names;
    
    $self->{'csv'}->column_names( @$names );
    return $names;
}
sub has_mandatory_columns {
    my $self = shift;
    
    my $has_status  = 0;
    my $has_old_url = 0;
    my $has_new_url = 0;
    foreach my $col ( @{$self->{'column_names'}} ) {
        $has_status  = 1 if 'Status'  eq $col;
        $has_old_url = 1 if 'Old Url' eq $col;
        $has_new_url = 1 if 'New Url' eq $col;
    }
    
    return 1 if $has_status && $has_old_url && $has_new_url;
    return 0;
}

1;
