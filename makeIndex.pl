#!/usr/bin/perl

use strict;
use utf8;
use open qw(:utf8 :std);

use Getopt::Long;
use Pod::Usage;

binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $verbose;
my $help;
my $man;

my @indexFile;
my @output;
my @terms;
my @hypernRel;
my @synoRel;
#my $lexInclusion;
my @seeAlsoRel;
my $indexDepth;
my $filename;
my $output;
my $indexDepth = 2;
my $printTerms;

my %config = (
    "verbose" => 0,
    "print-short-label" => 0,
    );

my %termList = (
    'terms' => {},
    'indxterms' => {},
    'relations' => {
	'synonymes' => {},
	'hyperonymes' => {},
	'see-also' => {},
#	'lexical-inclusions' => {},
    },
    );

if (scalar(@ARGV) ==0) {
    $help = 1;
}

Getopt::Long::Configure ("bundling");

GetOptions('help|?'     => \$help,
	   'man'     => \$man,
	   'verbose|v'     => \$config{'verbose'},
	   'index|i=s' => \@indexFile,
	   'terms|t=s' => \@terms,
	   'hyperonymie|h=s' => \@hypernRel,
#	   'lexical-inclusion|I=s' => \$lexInclusion,
	   'synonymie|s=s' => \@synoRel,
	   'see-also|a=s' => \@seeAlsoRel,
	   'output|o=s' => \$output,
	   'depth|d=i' => \$indexDepth,
	   'print-short-label|S' => \$config{'print-short-label'},
	   'print-terms|T' => \$printTerms,
    );

pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

foreach $filename (@terms) {
    &loadTerms($filename, $termList{'terms'});
}

foreach $filename (@indexFile) {
    &loadIndex($filename, $termList{'indxterms'});
}

foreach $filename (@synoRel) {
    &loadSynonymes($filename, $termList{'relations'}->{'synonymes'}, $termList{'terms'});
}

foreach $filename (@hypernRel) {
    &loadHyperonymes($filename, $termList{'relations'}->{'hyperonymes'}, $termList{'terms'});
}

# if (defined $lexInclusion) {
#     &loadLexicalInclusion($lexInclusion, $termList{'terms'});
# }

foreach $filename (@seeAlsoRel) {
    &loadSeeAlso($filename, $termList{'relations'}->{'see-also'}, $termList{'terms'});
}

if (defined $printTerms) {
    &printTerms(\%termList);
    exit;
}

if (scalar(keys %{$termList{'indxterms'}}) == 0) {
    &makeIndexFromTerms(\%termList, \%config);
}

&printIndex([keys %{$termList{'indxterms'}}], \%termList, $indexDepth, "", "", \%config);

sub printTerms {
    my ($data) = @_;

    my $t;
    my $h;
    foreach $t (sort keys %{$data->{'terms'}}) {
	print "$t (" . $data->{'terms'}->{$t} . ")\n";
	foreach $h (keys %{$data->{'relations'}->{'hyperonymes'}->{$t}}) {
	    print "\t(h) $h (" . $data->{'terms'}->{$h} . ")\n";
	}
	if (exists $data->{'relations'}->{'synonymes'}->{$t}) {
	    foreach $h (@{$data->{'relations'}->{'synonymes'}->{$t}}) {
		print "\t(s) $h (" . $data->{'terms'}->{$h} . ")\n";
	    }
	}
	if (exists $data->{'relations'}->{'see-also'}->{$t}) {
	    foreach $h (@{$data->{'relations'}->{'see-also'}->{$t}}) {
		print "\t(a) $h (" . $data->{'terms'}->{$h} . ")\n";
	    }
	}
    }

}

sub printIndex {
    my ($list, $data, $depth, $strShift, $typeRel, $conf) = @_;
    my @sublist;
    my $t;
    my $rel;

    if ($conf->{'verbose'}) { warn "in printIndex ($depth)\n";};
    if ($depth > 0) {
	foreach $t (sort @$list) {
	    if (exists $data->{'terms'}->{lc($t)}) {
		print "$strShift$t$typeRel";
		if ($conf->{'verbose'}) {print " ($depth " . $conf->{'verbose'} . ")";}
		print "\n";
		@sublist = ();
		$rel = "hyperonymes";
		&makeSubListH(\@sublist, $data, $t, $rel, $conf);
		&printIndex(\@sublist, $data, $depth-1, $strShift . "\t", "", $conf);
		@sublist = ();
		$rel = "synonymes";
		&makeSubListS(\@sublist, $data, $t, $rel, $conf);
		&printIndex(\@sublist, $data, $depth-1, $strShift . "\t", " (variante)", $conf);
		@sublist = ();
		$rel = "see-also";
		&makeSubListSA(\@sublist, $data, $t, $rel, $conf);
		&printIndex(\@sublist, $data, $depth-1, $strShift . "\t", " (voir aussi)", $conf);
	    }
	}
    } 
}

sub makeSubListS {
    my ($sublist, $data, $t, $rel, $conf) = @_;
    my $s;
    my %sublst;

    if (exists $data->{'relations'}->{$rel}->{$t}) {
	foreach $s (@{$data->{'relations'}->{$rel}->{$t}}) {
	    if (exists $data->{'indxterms'}->{$s}) {
		$sublst{$s}++;
	    } 
	}
	@$sublist = keys %sublst;
	if ($conf->{'verbose'}) {
	    warn "$rel of $t: " . join(" / ", @$sublist) . "\n";
	}
    }
}

sub makeSubListSA {
    my ($sublist, $data, $t, $rel, $conf) = @_;
    my $s;
    my %sublst;

    if (exists $data->{'relations'}->{$rel}->{$t}) {
	foreach $s (@{$data->{'relations'}->{$rel}->{$t}}) {
	    if (exists $data->{'indxterms'}->{$s}) {
		$sublst{$s}++;
	    } 
	}
	@$sublist = keys %sublst;
	if ($conf->{'verbose'}) {
	    warn "$rel of $t: " . join(" / ", @$sublist) . "\n";
	}
    }
}

sub makeSubListH {
    my ($sublist, $data, $t, $rel, $conf) = @_;
    my $h;

    if ($conf->{'verbose'}) { warn "makeSubListH for $t (rel: $rel)\n";};
    foreach $h (keys %{$data->{'relations'}->{$rel}->{$t}}) {
	if ($conf->{'verbose'}) {warn "\t $h / $t\n";};
#	if (exists $data->{'indxterms'}->{$h}) {
	if ($conf->{'print-short-label'}) {
	    $h =~ s/\b$t\b//;
	    $h =~ s/^\s+//go;
	    $h =~ s/\s+$//go;
	}
	    push @$sublist, $h;
#	}
    }
    if ($conf->{'verbose'}) {
	warn "hyponymes of $t: " . join(" / ", @$sublist) . "\n";
    }
}


sub makeIndexFromTerms {
    my ($data, $conf) = @_;

    my $term;
    my $t;
    my $addIndex = 1;
    my $H;

    foreach $term (keys %{$data->{'terms'}}) {
	$addIndex = 1;
	# Synonymes
	if ((exists $data->{'relations'}->{'synonymes'}->{$t}) &&
	    ($t ne &maxOcc($data->{'terms'}, [$t, @{$data->{'relations'}->{'synonymes'}->{$t}}]))) {
	    $addIndex = 0;
	} else {
	    # Hyperonymes
	    # foreach $t (keys %{$data->{'terms'}}) {
	    # 	if (exists $data->{'relations'}->{'hyperonymes'}->{$t}) {
	    # 	    $addIndex = 0;
	    # 	    last;
	    # 	} else {
	    foreach $H (keys %{$data->{'relations'}->{'hyperonymes'}}) {
		if (exists $data->{'relations'}->{'hyperonymes'}->{$H}->{$term}) {
		    if ($conf->{'verbose'}) {warn "$term is_hyponyme_of $H\n";};
		    $addIndex = 0;
		    last;
		}
	    }
	    # }
	# }
	    if ($addIndex == 1) {
		# SeeAlso
		if ((exists $data->{'relations'}->{'see-also'}->{$t}) &&
		    ($t ne &maxOcc($data->{'terms'}, [$t, @{$data->{'relations'}->{'see-also'}->{$t}}]))) {
		    $addIndex = 0;
		}
	    }
	}
	if ($addIndex) {
	    if ($conf->{'verbose'}) {warn "=> keep $term in index\n";};
	    $data->{'indxterms'}->{$term}++;
	}
    }

}

sub maxOcc {
    my ($terms, $synTerms) = @_;

    my $maxOcc = 0;
    my $selectedTerm;
    my $t;

    foreach $t (@$synTerms) {
	if ($terms->{$t} > $maxOcc) {
	    $selectedTerm = $t;
	}
    }
    return($selectedTerm);
}

sub loadTerms {
    my ($file, $data) = @_;
    my $line;
    my @t;
    open FILE, $file or die "no such file $file";
    while($line = <FILE>) {
	chomp $line;
	if (($line !~ /^\s*#/) && ($line !~ /^\s*$/)) {
	    @t = split /\t/, lc($line);
	    if (scalar(@t) == 1) { # index
		$data->{$t[0]}++;
	    } elsif (scalar(@t) == 2) { # output .terms
		$data->{$t[1]}++;
	    } elsif (scalar(@t) == 3) { # output termlist.txt
		$data->{$t[0]} += $t[1];	    
	    }
	}
    }
    close FILE;
}

sub loadIndex {
    my ($file, $data) = @_;

    &loadTerms($file, $data);
}

sub loadRelations {
    my ($file, $data, $relationType) = @_;
    my $line;
    open FILE, $file or die "no such file $file";
    while($line = <FILE>) {
	chomp $line;

	# lexical-inclusion
        # T1 : T2
        # relHyperonymie-liste.txt
	# T1<TAB>T2
        # Var/Synonymes
	# NUM<TAB>T1<TAB>T2<TAB>typeRel
	# distrib
        # T1|POSTAG : T2|POSTAG : DIST
    }
    close FILE;
}

sub loadHyperonymes {
    my ($file, $data, $termList) = @_;
    my $line;
    my $h;
    my $H;

    # &loadRelations($file, $data, "hyperonymes");
    open FILE, $file or die "no such file $file";
    while($line = <FILE>) {
	chomp $line;
	if (($line !~ /^\s*#/) && ($line !~ /^\s*$/)) {
	    # relHyperonymie-liste.txt
	    # T1<TAB>T2
	    ($h, $H) = split /\t| : /, lc($line);
	    $termList->{$h}++;
	    $termList->{$H}++;
	    $data->{$H}->{$h}++;
	}
    }
    close FILE;
}


sub loadSynonymes {
    my ($file, $data, $termList) = @_;
    my $line;
    my $t1;
    my $t2;
    my $num;

    # &loadRelations($file, $data, "synonymes");
    open FILE, $file or die "no such file $file";
    while($line = <FILE>) {
	chomp $line;
	if (($line !~ /^\s*#/) && ($line !~ /^\s*$/)) {
	    # Var/Synonymes
	    # NUM<TAB>T1<TAB>T2<TAB>typeRel
	    ($num,$t1, $t2) = split / ?\t ?/, lc($line);
	    $termList->{$t1}++;
	    $termList->{$t2}++;

	    if (!exists $data->{$t1}) {
		$data->{$t1} = [];
	    }
	    push @{$data->{$t1}}, $t2;
	    if (!exists $data->{$t2}) {
		$data->{$t2} = [];
	    }
	    push @{$data->{$t2}}, $t1;
	}	
    }
    close FILE;
}

sub loadLexicalInclusion {
    my ($file, $data, $termList) = @_;
    my $t1;
    my $t2;
    my $line;

    # &loadRelations($file, $data, "lexical-inclusions");
    open FILE, $file or die "no such file $file";
    while($line = <FILE>) {
	chomp $line;
	if (($line !~ /^\s*#/) && ($line !~ /^\s*$/)) {
	    # lexical-inclusion
	    # T1 : T2
	    ($t1, $t2) = split /\s*:\s*/, lc($line);
	    $termList->{$t1}++;
	    $termList->{$t2}++;
	    if (!exists $data->{$t1}) {
		$data->{$t1} = [];
	    }
	    push @{$data->{$t1}}, $t2;
	}
    }
    close FILE;
}


sub loadSeeAlso {
    my ($file, $data, $termList) = @_;
    my $line;
    my $tp1;
    my $tp2;
    my $t1;
    my $t2;

    # &loadRelations($file, $data, "lexical-inclusions");
    open FILE, $file or die "no such file $file";
    while($line = <FILE>) {
	chomp $line;
	if (($line !~ /^\s*#/) && ($line !~ /^\s*$/)) {
	    # distrib
	    # T1|POSTAG : T2|POSTAG : DIST
	    ($tp1, $tp2) = split /\s*:\s*/, lc($line);
	    ($t1, ) = split /\|/, $tp1;
	    ($t2, ) = split /\|/, $tp2;
	    $termList->{$t1}++;
	    $termList->{$t2}++;

	    if (!exists $data->{$t1}) {
		$data->{$t1} = [];
	    }
	    push @{$data->{$t1}}, $t2;

	    if (!exists $data->{$t2}) {
		$data->{$t2} = [];
	    }
	    push @{$data->{$t2}}, $t1;
	}
    }
    close FILE;
}



########################################################################

=head1 NAME

makeIndex.pl - Perl script for generating a index of text collection


=head1 SYNOPSIS

makeIndex.pl [option] 

where option can be --help --man --verbose

=head1 OPTIONS AND ARGUMENTS

=over 4

=item --index <filename>, -i <filename>

Filename containing the index entries. This information is optional.

=item --terms <filename>, -t <filename>

Filename containing the terms. Several files can be specified.

=item --hyperonymie|h=s' => \@hypernRel,

Filename containing the hyperonymy relations. Several files can be specified.

=item --synonymie <filename>, --s <filename>

Filename containing the synonymy relations. Several files can be specified.

=item --see-also <filename>, --a <filename>

Filename containing the see-also relations. Several files can be specified.

=item --depth <filename>, --d <filename>

Depth of the index. The default is 2.

=item --print-short-label <filename>, --S <filename>

Print the label of the sub-entries but remove the string which is already in the index entry.

=item --print-terms <filename>, --T <filename>

Print the terms with the associated relations and exit.

=item --help

Print help message for using makeIndex.pl

=item --man

Print man page of makeIndex.pl

=item --verbose

Go into the verbose mode

=back

=head1 DESCRIPTION

The script generates the index of a text collection from the termes
and semantic relations (hyperonymy, synonymy, and see-also) which are
provided.

The list of the index entries can be provided through the option
C<--index>. Otherwise, the entries are selected among the terms
according several rules: the term is not hyponym of other terms, the
term is the most frequent in its synonym set, and the term is the most
frequent in its see-also set.

When load a relation, the related terms are added to the term list if
they not already in the list.

=head1 FORMAT OF THE FILES

=head2 TERMS

Three formats can be used to load terms:

=over 4

=item Format 1 column: Each line only contains a term.

=item Format 2 columns: Each line contains a term id and a term separated by a tabulation.

=item Format 3 columns: Each line contains a term, its frequency and other metrics separated by a tabulation.

=back


=head2 INDEX

Each line contains a index entry, e.i. a term.


=head2 HYPERONYMY RELATIONS

Each line contains the hypernym term and a hyponym term separated by a tabulation.

=head2 SYNONYMY RELATIONS

Each line contains the term and a synonym term separated by a tabulation.

=head2 SEE-ALSO RELATIONS

Each line contains the term and a synonym term separated by a tabulation.


=head1 SEE ALSO

Each line contans the related terms and a association metric
separated by the character ":". The Part-of-Speech may be associated
to each term (the separator is "|").


=head1 EXAMPLES

 Logiciels/makeIndex.pl -t resume-articles-2012.terms -h resume-articles-2012.lexinclusion 
    -h resume-articles-2012.relHyperonymie-liste.txt -s $HOME/Termino/Corpus/resume-articles-2012.FI.varTerm 
    -a $HOME/Termino/Corpus/articles-2012.DArel 


=head1 AUTHOR

Thierry Hamon, E<lt>hamon@limsi.frE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015 Thierry Hamon

This is free software; you can redistribute it and/or modify it under
the same terms as Perl itself, either Perl version 5.8.4 or, at your
option, any later version of Perl 5 you may have available.

=cut

