#!/bin/env perl
package Neuffer::RenderPhenoGroupWikiPage;
# ABSTRACT: Create wiki pages from groups of phenotype info

#=============================================================================
# STANDARD MODULES AND PRAGMAS
use 5.010;    # Require at least Perl version 5.10
use strict;   # Declare variables before using them
use warnings; # Emit helpful warnings
use autodie;  # Fatal exceptions for common unrecoverable errors (e.g. open)
use Data::Section -setup;      # Set up labeled DATA sections
use Getopt::Long::Descriptive; # Parse @ARGV as command line flags and arguments
use Carp qw( croak );          # Throw errors from calling function


use Text::Template;
use Neuffer::ParseDump;
use Hash::Util  qw( lock_hash );
use LWP::Simple qw( head );

#=============================================================================
# CONSTANTS

# Boolean
my $TRUE =1;
my $FALSE=0;

# String
my $DASH          = q{-};
my $FORWARD_SLASH = q{/};
my $UNDERSCORE    = q{_};

# Dokuwiki code for horizontal line break
my $HORIZONTAL_BREAK = "\n----\n\n";

my $DEFAULT_PHENO_DIR = "$ENV{HOME}/data/neuffer";

my $DEFAULT_WEB_PATH  = 'http://images.maizegdb.org/db_images/Variation/mgn';
my $CD_WEB_PATH       = 'http://images.maizegdb.org/db_images/Variation/cd';
my $UPLOADED_PATH     = 'http://mutants.maizegdb.org/lib/exe/fetch.php?media=';

# REGEX
my $INTEGER = qr{ \d+ }xms;

my @REQUIRED_FLAGS = qw( infile outfile );

# CONSTANTS
#=============================================================================

#=============================================================================
# COMMAND LINE

# Run as a command-line program if not used as a module
main(@ARGV) if !caller();

sub main {

    #-------------------------------------------------------------------------
    # COMMAND LINE INTERFACE                                                 #
    #                                                                        #
    my ( $opt, $usage ) = describe_options(
        '%c %o <some-arg>',
        [ 'infile|i=s',  'input file name',                     ],
        [ 'outfile|o=s', 'output file name',                    ],
        [ 'pheno_dir=s', 'Directory containing phenotype info', ],
        [                                                       ],
        [ 'help', 'print usage message and exit'                ],
    );

    my $exit_with_usage = sub {
        print "\nUSAGE:\n";
        print $usage->text();
        exit();
    };


    # If requested, give usage information regardless of other options
    $exit_with_usage->() if $opt->help;


    # Make some flags required
    my $missing_required = $FALSE;
    for my $flag (@REQUIRED_FLAGS) {
        if ( !defined $opt->$flag ) {
            warn "Missing required option '$flag'\n";
            $missing_required = $TRUE;
        }
    }

    # Exit with usage statement if any required flags are missing
    $exit_with_usage->() if $missing_required;

    #                                                                        #
    # COMMAND LINE INTERFACE                                                 #
    #-------------------------------------------------------------------------

    #-------------------------------------------------------------------------
    #                                                                        #
    #                                                                        #
    my %fh;

    my $pheno_dir = $opt->pheno_dir // $DEFAULT_PHENO_DIR;
    my $infile    = $opt->infile;
    my $outfile   = $opt->outfile;

    process( {infile=> $infile, pheno_dir => $pheno_dir, outfile=>$outfile} );

    return;

    #                                                                        #
    #                                                                        #
    #-------------------------------------------------------------------------
}

# COMMAND LINE
#=============================================================================

#=============================================================================
#

sub process {
    my $opt = shift();
    my ($infile, $outfile, $pheno_dir) = @{ $opt}{qw( infile outfile pheno_dir)};
    $pheno_dir //= $DEFAULT_PHENO_DIR;

    my $neuffer_pheno_def_file = $pheno_dir . '/neuffer_pheno_defs'; 
    my $maizegdb_pheno_id_file = $pheno_dir . '/maizegdb_pheno_ids';

    # Input files
    my %fh;
    open( $fh{in},                '<', $infile );
    open( $fh{pheno},             '<', $neuffer_pheno_def_file );
    open( $fh{maizegdb_pheno_id}, '<', $maizegdb_pheno_id_file );

    # Output files
    open( $fh{out}, '>', $outfile          );
    open( $fh{log}, '>', $outfile . ".log" );
    open ($fh{index_of_pheno}, '>>', 'index_of_phenotypes.txt');

    # Prevent hash key typos from causing problems
    lock_hash(%fh);

    my $print_out = sub{
        print { $fh{out} } @_;
    };

    my $print_to_index = sub {
        print { $fh{index_of_pheno} } @_;
    };

    my %description_for       = %{ read_neuffer_pheno_info($fh{pheno})             };
    my %maizegdb_pheno_id_for = %{ read_maizegdb_pheno_ids($fh{maizegdb_pheno_id}) };

    my $file_href = Neuffer::ParseDump::href_from_file($fh{in});

    $print_out->(string_from('header_template'));

    my $phenotype_header_template = Text::Template->new(
                                        TYPE   => 'STRING',
                                        SOURCE => string_from('phenotype_header'),
                                    );
    my $phenotype_name        = $file_href->{0}->[0]->{phenotype}->{name};
    my $lc_phenotype_name     = lc $phenotype_name;
    my $phenotype_description = $description_for{$lc_phenotype_name} // $file_href->{0}->[0]->{phenotype}->{description};
    my $clean_pheno_name      = $lc_phenotype_name;
    $clean_pheno_name =~ s/[^a-zA-Z0-9]+/ /g;

    $print_to_index->("| [[ :$clean_pheno_name | $phenotype_name ]] | " . substr($phenotype_description,0,47) . "... |\n");

    my $phenotype_header =
        $phenotype_header_template->fill_in(
            HASH => {
                    phenotype_name        => $phenotype_name,
                    phenotype_description => $phenotype_description,
                    maizegdb_pheno_id     => $maizegdb_pheno_id_for{ $lc_phenotype_name},
                }
        );

    $print_out->( $phenotype_header );

    for my $group_num ( keys %{ $file_href } ){
        for my $record_href ( @{ $file_href->{$group_num} } ){

            my $image_template = Text::Template->new(
                                        TYPE   => 'STRING',
                                        SOURCE => string_from('image_template'),
                                    );
            my $web_filename      = $record_href->{image}->{web_filename};
            my $local_filename    = $record_href->{image}->{local_filename};
            my $image_description = $record_href->{image}->{description};
            my $phenotype_name    = $record_href->{phenotype}->{name};

            # Correct for duplicate phenotype name in the image description
            my $phenotype_name_regex = qr{\A(\s*$phenotype_name\s*[:;]\s*)}msi; #No regex x flag means spaces in variable are significant
            if( $image_description =~ /$phenotype_name_regex/msi){ # No x means spaces are significant
                my $duplicate_pheno_name = $1;
                $image_description =~ s/$duplicate_pheno_name//;
            }
            elsif($image_description =~ /[:;]/xms){ # If it contains a colon or semicoln, it may be different than the phenotype name
                say {$fh{log}} "Check the image descriptions for labno '$record_href->{labno}' (i.e. phenotype name: '$phenotype_name')";
            }

            my ($full_image_URL, $downsized_image_URL) = image_URLs_for($web_filename,$local_filename);
            my $image_wiki_content = $image_template->fill_in(
                HASH => {
                            web_filename        => $web_filename        ,
                            image_description   => $image_description   ,
                            phenotype_name      => $phenotype_name      ,
                            full_image_URL      => $full_image_URL      ,
                            downsized_image_URL => $downsized_image_URL ,
                        }
            );

            $print_out->( $image_wiki_content );
            $print_out->( $HORIZONTAL_BREAK   );
        }
    }

    $print_out->( "[<>]\n");

    for my $handle (keys %fh){
        close $fh{$handle};
    }
}
#
#=============================================================================
sub image_URLs_for {
    my $web_filename        = shift;
    my $local_filename      = shift;
    my $full_image_URL      = "$DEFAULT_WEB_PATH/$web_filename";
    my $downsized_image_URL = "$DEFAULT_WEB_PATH/480_w_ds/$web_filename";
    my $image_found         = head($full_image_URL);
    if ($image_found) {
        if ( head($downsized_image_URL) ) {
            return ( $full_image_URL, $downsized_image_URL );
        }
        else {
            return ( $full_image_URL, $full_image_URL );
        }
    }
    else {
        my $local_filename_actually_work_for_web = head($local_filename);
        if ($local_filename_actually_work_for_web) {
            return ( $local_filename, $local_filename );
        }
        else {
            my $altered_name = $web_filename;
            my $PART_A =
              qr{ $INTEGER $UNDERSCORE $INTEGER $UNDERSCORE $INTEGER }xms;

            my $FOUR_INTEGER_CODE =
              qr{ ($PART_A ) ($UNDERSCORE) ($INTEGER) }xms;

            if ( $web_filename =~ m{\A $FOUR_INTEGER_CODE (\.\w+) \Z }xms ) {
                my $first_part   = $1;
                my $last_integer = $3;
                my $extension    = $4;
                $first_part =~ s/$UNDERSCORE/$DASH/g;
                $full_image_URL =
                    $CD_WEB_PATH
                  . $first_part
                  . $FORWARD_SLASH
                  . $last_integer
                  . $extension;
                $downsized_image_URL = $full_image_URL;
            }
            if ( !head($full_image_URL) ) {
                warn "Full image URL not found: $full_image_URL";
                $full_image_URL = uploaded_photo_URL($web_filename);
                warn "Using '$full_image_URL' instead. (Hope it works)\n";
            }
            if ( !head($downsized_image_URL) ) {
                warn "Downsized image URL not found: $downsized_image_URL\n";
                $downsized_image_URL = uploaded_photo_URL($web_filename);
                warn "Using '$downsized_image_URL' instead. (Hope it works)\n";
            }

            return ( $full_image_URL, $downsized_image_URL );
        }
    }
}

sub uploaded_photo_URL {
    my $web_filename = shift;

    # Replace underscores with dashes
    $web_filename =~ s/$UNDERSCORE/$DASH/g;

    return $UPLOADED_PATH . $web_filename;
}

sub read_neuffer_pheno_info {
    my $fh = shift;

    my %description_for;

    while(my $line = readline $fh){
        chomp $line;
        my ($id, $name, $description) = split /\t/, $line;
        my $name_lc = lc $name;
        warn "Duplicate description for '$name'. Replacing previous description of '$description_for{$name_lc}' with '$description'." if exists $description_for{$name_lc};
        $description_for{$name_lc} = $description;
    }

    return \%description_for;
}

sub read_maizegdb_pheno_ids {
    my $fh = shift;

    my %id_for;

    while(my $line = readline $fh){
        chomp $line;
        my ($id, $name) = split /\t/, $line;
        my $name_lc = lc $name;
        warn "Duplicate id for '$name'. Replacing previous id of '$id_for{$name_lc}' with '$id'." if exists $id_for{$name_lc};
        $id_for{$name_lc} = $id;
    }

    return \%id_for;
}


#-----------------------------------------------------------------------------

sub sref_from {
    my $section = shift;

    #Scalar reference to the section text
    return __PACKAGE__->section_data($section);
}

sub string_from {
    my $section = shift;

    #Get the scalar reference
    my $sref = sref_from($section);

    #Return a string containing the entire section
    return ${$sref};
}

sub fh_from {
    my $section = shift;
    my $sref    = sref_from($section);

    #Create filehandle to the referenced scalar
    open( my $fh, '<', $sref );
    return $fh;
}

sub assign_filename_for {
    my $filename = shift;
    my $section  = shift;

    # Don't overwrite existing file
    die "'$filename' already exists." if -e $filename;

    my $string   = string_from($section);
    open(my $fh, '>', $filename);
    print {$fh} $string;
    close $fh;
    return;
}

sub filename_for {
    my $section           = shift;
    my ( $fh, $filename ) = tempfile();
    my $string            = string_from($section);
    print {$fh} $string;
    close $fh;
    return $filename;
}

sub temp_filename {
    my ($fh, $filename) = tempfile();
    close $fh;
    return $filename;
}

sub delete_temp_file {
    my $filename  = shift;
    my $delete_ok = unlink $filename;
    ok($delete_ok, "deleted temp file '$filename'");
}

1;  #Modules must return a true value

=pod


=head1 SYNOPSIS

     perl Neuffer/RenderPhenoGroupWikiPage.pm --infile input_filename --outfile output_filename

=head1 DEPENDENCIES

    Data::Section
    Getopt::Long::Descriptive

=head1 INCOMPATIBILITIES

    None known

=head1 BUGS AND LIMITATIONS

     There are no known bugs in this module.
     Please report problems to the author.
     Patches are welcome.

=cut

__DATA__
__[ header_template ]__
~~NOTOC~~
[<>]
__[ CSS ]__
<html><style>

    /* Headers for each section. These allow for section-level editing. */
    h1{
        text-align:center;
    }

    /* Figure is centered, but later see that the figure caption is left-justified */
    div.figure {
       text-align:center;
    }

    div.figcaption {
        font-size:100%;
        text-align:left;
    }

    /* header for each caption */
    span.caption_header{
        font-weight: bold;
        font-style: italic;
    }

    div.link_list {
        font-size:100%;
    }

    /* Allow for image resizing */
    img {
        max-width:  100%;
        max-height: 90%;
        width:      auto\9; /* ie8 */
    }

    div.phenotype_definition {
        font-size:110%;
    }

    span.phenotype_name {
            font-weight: bold;
    }

    div.header_horizontal_rule {
         height: 10px; border: 0; box-shadow: inset 0 10px 10px -10px rgba(0,0,0,0.5);
    }

</style></html>
__[ phenotype_header ]__

<html>
    <div class="phenotype_definition">
        <span class="phenotype_name">
            {$phenotype_name}
        </span>
        {$phenotype_description}
    </div>{ $maizegdb_pheno_id ? "<a href=\"http://www.maizegdb.org/cgi-bin/displayphenorecord.cgi?id=$maizegdb_pheno_id\">MaizeGDB reference</a>" : '' }
</html>

<html>
    <div class="header_horizontal_rule">
        <HR>
    </div>
</html>

__[ image_template ]__
<html>
    <div class="figure">
        <a href="{$full_image_URL}">
            <img src="{$downsized_image_URL}"/>
        </a>

        <div class="figcaption">
            <span class="caption_header">
                {$phenotype_name}
            </span>
            {$image_description}
        </div>
    </div>
    <BR/>
</html>
