use 5.008;    # Require at least Perl version 5.8
use strict;   # Must declare all variables before using them
use warnings; # Emit helpful warnings
use autodie;  # Fatal exceptions for common unrecoverable errors (e.g. w/open)
use Try::Tiny;# Simple exception handling

# Testing-related modules
use Test::More;                  # provide testing functions (e.g. is, like)
use Test::LongString;            # Compare strings byte by byte
use Data::Section -setup;        # Set up labeled DATA sections
use File::Temp  qw( tempfile );  #
use File::Slurp qw( slurp    );  # Read a file into a string

#use Data::Show;

# Distribution-specific modules
use lib 'lib';              # add 'lib' to @INC
use Neuffer::RenderPhenoGroupWikiPage;

# TODO add test for things like anthocyanin-Dt (something with non-alphanumerics)

# Variables used in multiple tests
my $index_of_phenotypes = 'index_of_phenotypes';
my $index_of_pheno_file = "$index_of_phenotypes.txt";


{   # Test image_URLs_for on actual existing files
    my $input = 'http://images.maizegdb.org/db_images/Variation/coe9208-3663/54.jpg';
    my $expected = $input;
    my $result = Neuffer::RenderPhenoGroupWikiPage::image_URLs_for($input,$input); 
    is($result, $expected, 'Correctly does not munge filename that matches existing file on the web');
}

{   # Test read_neuffer_pheno_info
    my $input_fh       = fh_from('input_phenotypes');
    my $result_href    = Neuffer::RenderPhenoGroupWikiPage::read_neuffer_pheno_info($input_fh);
    my $expected_href  = expected_neuffer_pheno_info();
    is_deeply($result_href, $expected_href, 'neuffer pheno info read correctly');
}

{   # Test read_maizegdb_pheno_ids
    my $input_fh       = fh_from('input_maizegdb_pheno_ids');
    my $result_href    = Neuffer::RenderPhenoGroupWikiPage::read_maizegdb_pheno_ids($input_fh);
    my $expected_href  = expected_maizegdb_pheno_ids();
    is_deeply($result_href, $expected_href, 'MaizeGDB pheno IDs table read correctly');
}

{
    my $pheno_filename  = assign_filename_for('neuffer_pheno_defs', 'input_phenotypes');
    my $var_filename    = assign_filename_for('maizegdb_pheno_ids', 'input_maizegdb_pheno_ids');
    for my $set (qw( anthocyanin brittle_stalk booster_of_anthocyanin)) {
        my $input_filename  = filename_for("input_$set");
        my $output_filename = temp_filename();
        system( "perl lib/Neuffer/RenderPhenoGroupWikiPage.pm --infile $input_filename --pheno_dir '.' --outfile $output_filename");
        my $result   = slurp $output_filename;
        my $expected = string_from("expected_local_$set");
        is_string( $result, $expected, "successfully created page for '$set' from tab-delimited file");
    }
    my $expected_index = string_from($index_of_phenotypes);
    my $result_index   = slurp($index_of_pheno_file);
    is_string ($result_index, $expected_index, 'Index of phenotypes page created');
    delete_temp_file($pheno_filename);
    delete_temp_file($var_filename);
    unlink $index_of_pheno_file;
}

{
    for my $set (qw( anthocyanin brittle_stalk booster_of_anthocyanin iojap)) {
        my $input_filename  = filename_for("input_$set");
        my $output_filename = temp_filename();
        system( "perl lib/Neuffer/RenderPhenoGroupWikiPage.pm --infile $input_filename --outfile $output_filename");
        my $result   = slurp $output_filename;
        my $expected = string_from("expected_$set");
        is_string( $result, $expected, "successfully created page for '$set' from tab-delimited file (deafult pheno_dir used)");
    }
    unlink $index_of_pheno_file;
}


done_testing();

sub expected_neuffer_pheno_info {
    return {
        'anthocyanin'   => 'blah blah Purple or red anthocyanin pigments in aleurone of kernel, seedling and plant parts depending on modifying genes and red pigment in pericarp with P-r.',
        'brittle stalk' => 'brittle stalk and leaves, shattered by moderate air movement',
        'iojap'         => 'variable longitudinal white stripes on leaves at all stages; boldest at margins and at base.',
    };
}

sub expected_maizegdb_pheno_ids {
    return {
        'anthocyanin'            => 64259,
        'brittle stalk'          => 64265,
        'booster'                => 64260,
        'booster of anthocyanin' => 64260,
    };
}


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
    return $filename;
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

#------------------------------------------------------------------------
# IMPORTANT!
#
# Each line from each section automatically ends with a newline character
#------------------------------------------------------------------------

__DATA__
__[ input_phenotypes ]__
1	anthocyanin	blah blah Purple or red anthocyanin pigments in aleurone of kernel, seedling and plant parts depending on modifying genes and red pigment in pericarp with P-r.
2	brittle stalk	brittle stalk and leaves, shattered by moderate air movement
174	iojap	variable longitudinal white stripes on leaves at all stages; boldest at margins and at base.
__[ input_maizegdb_pheno_ids ]__
64259	anthocyanin
64265	brittle stalk
64260	booster
64260	Booster of anthocyanin
__[ input_duplicate_phenotypes ]__
anthocyanin	purple or red anthocyanin pigments in aleurone of kernel, seedling and plant parts depending on modifying genes and red pigment in pericarp with P-r
anthocyanin	purple or red anthocyanin pigments in aleurone of kernel, seedling and plant parts depending on modifying genes and red pigment in pericarp with P-r
brittle stalk	brittle stalk and leaves, shattered by moderate air movement
__[ input_anthocyanin ]__
G001.001	A1-r	anthocyanin	junk purple or red anthocyanin pigments in aleurone of kernel, seedling and plant parts depending on modifying genes and red pigment in pericarp with P-r	anthocyanin: kernel and pericarp.   Three ears segregating for purple or red color (A1) vs. colorless aleurone (a1/a1) on ears, respectively (top to bottom), with colorless pericarp (p1/p1); brown pericarp (with P1-rr/- and the A1-b allele); and red pericarp (P1-rr) with the common A1 allele.	Research Images\maize\WalMart CDs\7101-3161-0702\7101-3161-0702-55.jpg	http://images.maizegdb.org/db_images/Variation/mgn/7101_3161_0702_55.jpg
G001.001	A1-r	anthocyanin pheno name with spaces	purple or red anthocyanin  pigments in aleurone of kernel, seedling and plant parts depending on modifying genes and red pigment in pericarp with P-r	anthocyanin pheno name with spaces: kernel.  The aleurone color of three ears segregating A1 a1 (upper ear); a1-p a1, Dt1 dt1; and A1 a1-pm.	Research Images\maize\WalMart CDs\7099-3173-2577\7099-3173-2577-58.jpg	http://images.maizegdb.org/db_images/Variation/mgn/7099_3173_2577_58.jpg
DUMMY	DUMMY	DUMMY	DUMMY	DUMMY	DUMMY	DUMMY
__[ expected_local_anthocyanin ]__
~~NOTOC~~
[<>]

<html>
    <div class="phenotype_definition">
        <span class="phenotype_name">
            anthocyanin
        </span>
        blah blah Purple or red anthocyanin pigments in aleurone of kernel, seedling and plant parts depending on modifying genes and red pigment in pericarp with P-r.
    </div><a href="http://www.maizegdb.org/cgi-bin/displayphenorecord.cgi?id=64259">MaizeGDB reference</a>
</html>

<html>
    <div class="header_horizontal_rule">
        <HR>
    </div>
</html>

<html>
    <div class="figure">
        <a href="http://images.maizegdb.org/db_images/Variation/mgn/7101_3161_0702_55.jpg">
            <img src="http://images.maizegdb.org/db_images/Variation/mgn/480_w_ds/7101_3161_0702_55.jpg"/>
        </a>

        <div class="figcaption">
            <span class="caption_header">
                anthocyanin
            </span>
            kernel and pericarp.   Three ears segregating for purple or red color (A1) vs. colorless aleurone (a1/a1) on ears, respectively (top to bottom), with colorless pericarp (p1/p1); brown pericarp (with P1-rr/- and the A1-b allele); and red pericarp (P1-rr) with the common A1 allele.
        </div>
    </div>
    <BR/>
</html>

----

<html>
    <div class="figure">
        <a href="http://images.maizegdb.org/db_images/Variation/mgn/7099_3173_2577_58.jpg">
            <img src="http://images.maizegdb.org/db_images/Variation/mgn/480_w_ds/7099_3173_2577_58.jpg"/>
        </a>

        <div class="figcaption">
            <span class="caption_header">
                anthocyanin pheno name with spaces
            </span>
            kernel.  The aleurone color of three ears segregating A1 a1 (upper ear); a1-p a1, Dt1 dt1; and A1 a1-pm.
        </div>
    </div>
    <BR/>
</html>

----

<html>
    <div class="figure">
        <a href="http://mutants.maizegdb.org/lib/exe/fetch.php?media=dummy">
            <img src="http://mutants.maizegdb.org/lib/exe/fetch.php?media=dummy"/>
        </a>

        <div class="figcaption">
            <span class="caption_header">
                DUMMY
            </span>
            DUMMY
        </div>
    </div>
    <BR/>
</html>

----

[<>]
__[ expected_anthocyanin ]__
~~NOTOC~~
[<>]

<html>
    <div class="phenotype_definition">
        <span class="phenotype_name">
            anthocyanin
        </span>
        Purple or red anthocyanin pigments in aleurone of kernel, seedling and plant parts depending on modifying genes and red pigment in pericarp with P-r.
    </div><a href="http://www.maizegdb.org/cgi-bin/displayphenorecord.cgi?id=64259">MaizeGDB reference</a>
</html>

<html>
    <div class="header_horizontal_rule">
        <HR>
    </div>
</html>

<html>
    <div class="figure">
        <a href="http://images.maizegdb.org/db_images/Variation/mgn/7101_3161_0702_55.jpg">
            <img src="http://images.maizegdb.org/db_images/Variation/mgn/480_w_ds/7101_3161_0702_55.jpg"/>
        </a>

        <div class="figcaption">
            <span class="caption_header">
                anthocyanin
            </span>
            kernel and pericarp.   Three ears segregating for purple or red color (A1) vs. colorless aleurone (a1/a1) on ears, respectively (top to bottom), with colorless pericarp (p1/p1); brown pericarp (with P1-rr/- and the A1-b allele); and red pericarp (P1-rr) with the common A1 allele.
        </div>
    </div>
    <BR/>
</html>

----

<html>
    <div class="figure">
        <a href="http://images.maizegdb.org/db_images/Variation/mgn/7099_3173_2577_58.jpg">
            <img src="http://images.maizegdb.org/db_images/Variation/mgn/480_w_ds/7099_3173_2577_58.jpg"/>
        </a>

        <div class="figcaption">
            <span class="caption_header">
                anthocyanin pheno name with spaces
            </span>
            kernel.  The aleurone color of three ears segregating A1 a1 (upper ear); a1-p a1, Dt1 dt1; and A1 a1-pm.
        </div>
    </div>
    <BR/>
</html>

----

<html>
    <div class="figure">
        <a href="http://mutants.maizegdb.org/lib/exe/fetch.php?media=dummy">
            <img src="http://mutants.maizegdb.org/lib/exe/fetch.php?media=dummy"/>
        </a>

        <div class="figcaption">
            <span class="caption_header">
                DUMMY
            </span>
            DUMMY
        </div>
    </div>
    <BR/>
</html>

----

[<>]
__[ input_brittle_stalk ]__
G019	bk2	brittle stalk	brittle stalk and leaves, shattered by moderate air movement	brittle stalk: Mature bk2 mutant plant showing shattered leaves.	Research Images\maize\WalMart CDs\7101-3161-2579\7101-3161-2579-78.jpg	http://images.maizegdb.org/db_images/Variation/mgn/7101_3161_2579_78.jpg

__[ expected_local_brittle_stalk ]__
~~NOTOC~~
[<>]

<html>
    <div class="phenotype_definition">
        <span class="phenotype_name">
            brittle stalk
        </span>
        brittle stalk and leaves, shattered by moderate air movement
    </div><a href="http://www.maizegdb.org/cgi-bin/displayphenorecord.cgi?id=64265">MaizeGDB reference</a>
</html>

<html>
    <div class="header_horizontal_rule">
        <HR>
    </div>
</html>

<html>
    <div class="figure">
        <a href="http://images.maizegdb.org/db_images/Variation/mgn/7101_3161_2579_78.jpg">
            <img src="http://images.maizegdb.org/db_images/Variation/mgn/480_w_ds/7101_3161_2579_78.jpg"/>
        </a>

        <div class="figcaption">
            <span class="caption_header">
                brittle stalk
            </span>
            Mature bk2 mutant plant showing shattered leaves.
        </div>
    </div>
    <BR/>
</html>

----

[<>]
__[ expected_brittle_stalk ]__
~~NOTOC~~
[<>]

<html>
    <div class="phenotype_definition">
        <span class="phenotype_name">
            brittle stalk
        </span>
        brittle stalk and leaves, shattered by moderate air movement
    </div><a href="http://www.maizegdb.org/cgi-bin/displayphenorecord.cgi?id=64265">MaizeGDB reference</a>
</html>

<html>
    <div class="header_horizontal_rule">
        <HR>
    </div>
</html>

<html>
    <div class="figure">
        <a href="http://images.maizegdb.org/db_images/Variation/mgn/7101_3161_2579_78.jpg">
            <img src="http://images.maizegdb.org/db_images/Variation/mgn/480_w_ds/7101_3161_2579_78.jpg"/>
        </a>

        <div class="figcaption">
            <span class="caption_header">
                brittle stalk
            </span>
            Mature bk2 mutant plant showing shattered leaves.
        </div>
    </div>
    <BR/>
</html>

----

[<>]
__[ input_booster_of_anthocyanin    ]__
G013	B1	Booster of anthocyanin	booster (sunlight requiring red pigment in exposed pl1 tissue and deep purple anthocyanin when Pl1 is present.	Booster of anthocyanin: Leaf sheath of a maturing B1/+, pl1/pl1 plant showing band of sunred (pl) pigment on older sheath tissue, above the previous night's still green emerging tissue, which will darken after sun exposure.  Had the Pl1 allele been present the sheath would be solid dark purple.	Research Images\maize\WalMart CDs\7101-3161-0706\7101-3161-0706-42.jpg	
__[ expected_local_booster_of_anthocyanin ]__
~~NOTOC~~
[<>]

<html>
    <div class="phenotype_definition">
        <span class="phenotype_name">
            Booster of anthocyanin
        </span>
        booster (sunlight requiring red pigment in exposed pl1 tissue and deep purple anthocyanin when Pl1 is present.
    </div><a href="http://www.maizegdb.org/cgi-bin/displayphenorecord.cgi?id=64260">MaizeGDB reference</a>
</html>

<html>
    <div class="header_horizontal_rule">
        <HR>
    </div>
</html>

<html>
    <div class="figure">
        <a href="http://images.maizegdb.org/db_images/Variation/cd7101-3161-0706/42.jpg">
            <img src="http://images.maizegdb.org/db_images/Variation/cd7101-3161-0706/42.jpg"/>
        </a>

        <div class="figcaption">
            <span class="caption_header">
                Booster of anthocyanin
            </span>
            Leaf sheath of a maturing B1/+, pl1/pl1 plant showing band of sunred (pl) pigment on older sheath tissue, above the previous night's still green emerging tissue, which will darken after sun exposure.  Had the Pl1 allele been present the sheath would be solid dark purple.
        </div>
    </div>
    <BR/>
</html>

----

[<>]
__[ expected_booster_of_anthocyanin ]__
~~NOTOC~~
[<>]

<html>
    <div class="phenotype_definition">
        <span class="phenotype_name">
            Booster of anthocyanin
        </span>
        Booster of sunlight requiring red pigment in exposed pl1 tissue and deep purple independent anthocyanin when the Pl1 allele is present.
    </div><a href="http://www.maizegdb.org/cgi-bin/displayphenorecord.cgi?id=64260">MaizeGDB reference</a>
</html>

<html>
    <div class="header_horizontal_rule">
        <HR>
    </div>
</html>

<html>
    <div class="figure">
        <a href="http://images.maizegdb.org/db_images/Variation/cd7101-3161-0706/42.jpg">
            <img src="http://images.maizegdb.org/db_images/Variation/cd7101-3161-0706/42.jpg"/>
        </a>

        <div class="figcaption">
            <span class="caption_header">
                Booster of anthocyanin
            </span>
            Leaf sheath of a maturing B1/+, pl1/pl1 plant showing band of sunred (pl) pigment on older sheath tissue, above the previous night's still green emerging tissue, which will darken after sun exposure.  Had the Pl1 allele been present the sheath would be solid dark purple.
        </div>
    </div>
    <BR/>
</html>

----

[<>]
__[ input_iojap ]__
G082	ij1	iojap	variable longitudinal white stripes on leaves at all stages; boldest at margins and at base.	iojap striping:  pale green iojap (ij1) plants showing occasional dark green sectors;  Extreme expression under cool growing conditions.  NOTE: surprising plant vigor; considering small amount of visible chlorophyll present, these plants should be tiny and weak.  Light harvesting properties of nearly white leaves is still quite efficient as long as there are tiny sectors of normal green tissue.	Research Images\maize\WalMart CDs\7099-3161-3560\7099-3161-3560-60.jpg	
G082	ij1	iojap	variable longitudinal white stripes on leaves at all stages; boldest at margins and at base.	iojap striping:  ij1 converged to K55 inbred, showing loss of margin tissue (narrow, midribs) and diminished plant (Coe photo)	http://images.maizegdb.org/db_images/Variation/coe9208-3663/54.jpg	
G082	ij1	iojap	variable longitudinal white stripes on leaves at all stages; boldest at margins and at base.	iojap striping: Leaf of an ij1 mutant plant in Oh51A background showing characteristic green on white transposon sectoring. (Coe photo)	http://images.maizegdb.org/db_images/Variation/coe0024-1413/96.jpg	
__[ expected_iojap ]__
~~NOTOC~~
[<>]

<html>
    <div class="phenotype_definition">
        <span class="phenotype_name">
            iojap
        </span>
        variable longitudinal white stripes on leaves at all stages; boldest at margins and at base.
    </div>
</html>

<html>
    <div class="header_horizontal_rule">
        <HR>
    </div>
</html>

<html>
    <div class="figure">
        <a href="http://images.maizegdb.org/db_images/Variation/mgn/7099_3161_3560_60.jpg">
            <img src="http://images.maizegdb.org/db_images/Variation/mgn/480_w_ds/7099_3161_3560_60.jpg"/>
        </a>

        <div class="figcaption">
            <span class="caption_header">
                iojap
            </span>
            iojap striping:  pale green iojap (ij1) plants showing occasional dark green sectors;  Extreme expression under cool growing conditions.  NOTE: surprising plant vigor; considering small amount of visible chlorophyll present, these plants should be tiny and weak.  Light harvesting properties of nearly white leaves is still quite efficient as long as there are tiny sectors of normal green tissue.
        </div>
    </div>
    <BR/>
</html>

----

<html>
    <div class="figure">
        <a href="http://images.maizegdb.org/db_images/Variation/coe9208-3663/54.jpg">
            <img src="http://images.maizegdb.org/db_images/Variation/coe9208-3663/54.jpg"/>
        </a>

        <div class="figcaption">
            <span class="caption_header">
                iojap
            </span>
            iojap striping:  ij1 converged to K55 inbred, showing loss of margin tissue (narrow, midribs) and diminished plant (Coe photo)
        </div>
    </div>
    <BR/>
</html>

----

<html>
    <div class="figure">
        <a href="http://images.maizegdb.org/db_images/Variation/coe0024-1413/96.jpg">
            <img src="http://images.maizegdb.org/db_images/Variation/coe0024-1413/96.jpg"/>
        </a>

        <div class="figcaption">
            <span class="caption_header">
                iojap
            </span>
            iojap striping: Leaf of an ij1 mutant plant in Oh51A background showing characteristic green on white transposon sectoring. (Coe photo)
        </div>
    </div>
    <BR/>
</html>

----

[<>]
__[ index_of_phenotypes ]__
| [[ :anthocyanin | anthocyanin ]] | blah blah Purple or red anthocyanin pigments in... |
| [[ :brittle stalk | brittle stalk ]] | brittle stalk and leaves, shattered by moderate... |
| [[ :booster of anthocyanin | Booster of anthocyanin ]] | booster (sunlight requiring red pigment in expo... |
