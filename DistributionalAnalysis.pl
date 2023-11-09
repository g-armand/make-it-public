#!/usr/bin/perl

use strict;

use utf8;
use Getopt::Long;
use Pod::Usage;

use File::Path 'rmtree';

use XML::Simple;
use Data::Dumper;

my $verbose=100;
my $help;
my $man;

my $yateaterms;
my %terms;
my $dependency;
my %gatheredDeps;

my %dep1ToNodes;
my @nodes;
my @nodes2links;
my %linkNodes;

my %similarity;

my $simplifyterms;
my $elementaryTermCheck;
my $relations = 0;

my $printCC;
my $semMeasure;
my $threshold;

my $dot;
my $maxid = 0;

my %CC;
my %CC_inv;
my %CC_edges;

my $minimumCtxt = 1;
my $minimumOccCtxt = 0;

my $distribution;

my $tagSize = 3;
my $keySelect = 0;
my $lemma;
my $lemmapos;
my $TermsAndNodes;
my $all;
my $veryall;

my %LemmaExceptions;
my %postagTermsAD;
my $MI;

my $postagTermsADFilename;

my $minimumFreq;

my $samepostag = 0;

my $maxocc = 0;
my $maxrel = 0;

my $exceptionfilename;
my $weight;

if (scalar(@ARGV) ==0) {
    $help = 1;
}

binmode(stdout, ":utf8");
binmode(stderr, ":utf8");

Getopt::Long::Configure ("bundling");

GetOptions('help|?'       => \$help,
	   'man'          => \$man,
	   'verbose|v:i'    => \$verbose,
	   'distribution|D=s' => \$distribution,
	   'terms|t:s'      => \$yateaterms,
	   'dependency|d:s' => \$dependency,
	   'simplifyterms|s' => \$simplifyterms,
	   'elementaryTermCheck|c' => \$elementaryTermCheck,
	   'relations|r'    => \$relations,
	   'dot:s'        => \$dot,
	   'printCC'      => \$printCC,
	   'semmeasure|S:s' => \$semMeasure,
	   'threshold|T=s%'   => \$threshold,
	   'lemma|l'  => sub { $keySelect = 1; },
	   'lemmapos|p'  => sub { $keySelect = 2; },,
	   'all|a'  => \$all,
	   'veryall|A'  => \$veryall,
	   'termsAndNodes|n' => \$TermsAndNodes,
	   'tagSize=i' => \$tagSize,
	   'minimumCtxt|m=i' => \$minimumCtxt,
	   'minimumOccCtxt|O=i' => \$minimumOccCtxt,
	   'minimumFreq|F=i' => \$minimumFreq,
	   'weight|w=s' => \$weight,
	   'samepostag' => \$samepostag,
	   'exceptions|e:s' => \$exceptionfilename,
	   'postagTermsAD|P=s' => \$postagTermsADFilename,
    );

pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

if (defined $postagTermsADFilename) {
    &loadExceptionFile($postagTermsADFilename, \%postagTermsAD);
}


if (defined $exceptionfilename) {
    &loadExceptionFile($exceptionfilename, \%LemmaExceptions);
}

# Word/Term + context
if (defined $distribution) {
    &loadDistribution($distribution, $keySelect, \%terms, \%gatheredDeps, \$maxocc, \$maxrel, \%LemmaExceptions, \%postagTermsAD);
    # warn "$maxocc / $maxrel";
    # exit;
}

# YATEA
if (defined $yateaterms) {
    if (&checkDependency($dependency)) {
	exit(-1);
    }
    &loadYaTeATerms($yateaterms, \%terms, \$maxid, $keySelect, $tagSize, \$maxocc, \$maxrel, $verbose);
# &printYaTeATerms(\%terms);

    if ($verbose == 0.5) {
	warn "\n";
	&printYaTeATerms(\%terms);
	exit;
    }


    if (defined $simplifyterms) {
	&computeSimplifyTerms(\%terms, \$maxid);
    }

    if ($verbose == 0.7) {
	warn "\n";
	&printYaTeATerms(\%terms);
	exit;
    }

    &gatherDependencyYatea($dependency, \%terms, \%gatheredDeps, $elementaryTermCheck);
}
if ($verbose == 1) {
    warn "\n";
    &printYaTeATerms(\%terms);
    &printGatheredDeps(\%gatheredDeps, \%terms);
    exit;
}

# compute mutual information
# if (defined $weight) {
&computeCtxtMeasures(\%terms, \%gatheredDeps, $maxocc, $maxrel);
# }
if ($verbose == 2) {
    warn "\n";
    &printGatheredDeps(\%gatheredDeps, \%terms);
    exit;
}

&makeDistributionalAnalysis(\%terms, \%gatheredDeps, \%dep1ToNodes, \@nodes, \@nodes2links, \%linkNodes, $minimumCtxt, $minimumOccCtxt, $minimumFreq, $samepostag, $verbose);

if ($verbose == 3) {
    &printNodes(\@nodes, \%terms, $verbose);
    &printNodes2Links(\%linkNodes, \%terms, \@nodes, \%similarity,  $verbose);
    exit;
}

&computeSimilarity(\@nodes, \%linkNodes, \%gatheredDeps, \%terms, \%similarity, $weight, $verbose);


# if (defined $semMeasure) {
#     if ($semMeasure eq "freqSharedCtxt") {
# 	&FreqSharedContexts(\@nodes, \%linkNodes, \%gatheredDeps, \%terms, \%similarity, $verbose);
#     } elsif ($semMeasure eq "Jaccard") {
# 	&JaccardMeasure(\@nodes, \%linkNodes, \%gatheredDeps, \%terms, \%similarity, $verbose);
#     } elsif ($semMeasure eq "Cosine") {
# 	&CosineMeasure(\@nodes, \%linkNodes, \%gatheredDeps, \%terms, \%similarity, $weight, $verbose);
#     } else {
# 	warn "sharedCtxt (default)\n";
# 	&nbSharedContexts(\@nodes, \%linkNodes, \%gatheredDeps, \%terms, \%similarity, $verbose);
#     }
if ($verbose == 4) {
    warn "\n";
    &printSimilarity(\@nodes, \%linkNodes, \%gatheredDeps, \%terms, \%similarity, $verbose);
    exit;
}

if ($verbose == 5) {
    warn "\n";
    &printNodes(\@nodes, \%terms, $verbose);
    &printNodes2Links(\%linkNodes, \%terms, \@nodes, \%similarity, $verbose);
#    &printNodes2LinksRelations(\%linkNodes, \@nodes, \%terms, \%similarity, \%gatheredDeps, $weight, $veryall, $verbose);
    exit;
}
# }

if (defined $threshold) {
    &postprune($threshold, \@nodes, \%linkNodes, \%gatheredDeps, \%terms, \%similarity, $semMeasure, $verbose);
}

if ($verbose == 6) {
    warn "\n";
    &printNodes(\@nodes, \%terms, $verbose);
    &printNodes2Links(\%linkNodes, \%terms, \@nodes, \%similarity, $verbose);
    &printNodes2LinksRelations(\%linkNodes, \@nodes, \%terms, \%similarity, \%gatheredDeps, $weight, $semMeasure, $veryall, $verbose);
    exit;
}
# }

&computeCC(\@nodes, \%linkNodes, \%terms, \%CC, \%CC_inv, \%CC_edges, $verbose);

if ($verbose == 7) {
    warn "\n";
    &printNodes2Links(\%linkNodes, \%terms, \@nodes, \%similarity, $verbose);
    &printCC(\@nodes, \%linkNodes, \%terms, \%CC, \%CC_inv, \%CC_edges, \%similarity, $semMeasure, $verbose);
#    &printNodeRelations(\@nodes, \%terms, $verbose);
    &printNodes2LinksRelations(\%linkNodes, \@nodes, \%terms, \%similarity, \%gatheredDeps, $weight, $semMeasure, $veryall, $verbose);
    exit;
}

if (($all) || ($TermsAndNodes) || ($veryall)) {
    # &printTerm2Nodes(\%dep1ToNodes, \%terms, $verbose);
    # &printNodes(\@nodes, \%terms, $verbose);
    print "\n";
    &printNodes2Links(\%linkNodes, \%terms, \@nodes, \%similarity, $verbose);
# } else {
}
if (($all) || ($relations) || ($veryall)) {
    # print "\n";
    # &printNodes2Links(\%linkNodes, \%terms, \@nodes, \%similarity, $verbose);
    print "\n";
    &printNodes2LinksRelations(\%linkNodes, \@nodes, \%terms, \%similarity, \%gatheredDeps, $weight, $semMeasure, $veryall, $verbose);
#    &printSimilarity(\@nodes, \%linkNodes, \%gatheredDeps, \%terms, \%similarity, $verbose);
}

if (defined $dot) {
    &DOToutput(\@nodes, \%linkNodes, \%terms, \%CC, \%CC_inv, \%CC_edges, $dot, $verbose);
}

if ((defined $printCC) || ($veryall)) {
    &printCC(\@nodes, \%linkNodes, \%terms, \%CC, \%CC_inv, \%CC_edges, \%similarity, $semMeasure, $verbose);
}

&statistics(\@nodes, \%linkNodes, \%terms, $elementaryTermCheck, \%CC);


########################################################################

sub loadExceptionFile {
    my ($exceptionFilename, $LemmaExceptions) = @_;

    my $line;

    # my %LemmaExceptions = ("avoir" => 1,
    # 		     "être" => 1,
    # 	);

    open (FILE, $exceptionFilename) or die "no such file $exceptionFilename\n";

    binmode(FILE, ":utf8");

    while ($line = <FILE>) {
	chomp $line;
	if (($line !~ /^\s*$/) && ($line !~ /^\s*#/)) {
	    $LemmaExceptions->{$line}++;
	}
    }

    close (FILE);
    
}

sub loadDistribution {
    my ($distribution, $keySelect, $terms, $gatheredDepList, $maxocc, $maxrel, $LemmaExceptions, $postagTermsAD) = @_;

    my $line;
    my $termid = 0;
    my @tmp;
    my $prev_headkey;
    my $headkey = undef;
    my $modifierkey;
    my $termkey;

    my $relationId = 0;

    open(FILE, "<:utf8", $distribution) or die "no such file $distribution\n";
    while($line = <FILE>) {
	chomp $line;
	if (($line =~ /^\s*$/o) && (defined $headkey)) {
	    $$maxocc++
	} else {
	    @tmp = split /\t/, $line;
	    if ((scalar(keys(%$postagTermsAD)) == 0) || (exists($postagTermsAD{$tmp[1]}) && !exists ($postagTermsAD{$tmp[4]}))) {
	    if ((scalar @tmp == 9) && (!exists $LemmaExceptions->{$tmp[5]}) && (!exists $LemmaExceptions->{$tmp[2]})) {
		if ($tmp[2] eq "") {
		    $tmp[2] = $tmp[0];
		}
		if ($tmp[5] eq "") {
		    $tmp[5] = $tmp[3];
		}
		if ($tmp[1] eq "term") {
		    $tmp[1] = "NOM";
		}
		if ($tmp[4] eq "term") {
		    $tmp[4] = "NOM";
		}

		$headkey = &addComponent($keySelect, $terms, $tmp[0], $tmp[1], $tmp[2], \$termid, undef, undef, undef, undef);
		$modifierkey = &addComponent($keySelect, $terms, $tmp[3], $tmp[4], $tmp[5], \$termid, undef, undef, undef, undef);
		$termkey = &addComponent($keySelect, $terms, $tmp[0] . " " . $tmp[3], $tmp[1] . " " . $tmp[4], $tmp[2] . " " . $tmp[5], \$termid, $headkey, $modifierkey, $tmp[6], $tmp[7]);

		$gatheredDepList->{$headkey}->{$modifierkey}->{$termkey}->{'freq'}++;

		$$maxrel++;
		
		if ($prev_headkey ne $headkey) {
		    $$maxocc++;
		    $terms->{$headkey}->{'nbocc'}++;
		}
		$terms->{$termkey}->{'nbocc'}++;
		$terms->{$modifierkey}->{'nbocc'}++;

		$prev_headkey = $headkey;
	    } else {
	    }
	    }
        }
    }
    close FILE;
}

sub addComponent {
    my ($keySelect, $terms, $termstr, $termPOStag, $termlemm, $termid, $headkey, $modifierkey, $position, $distance) = @_;

    my $termkey;
    my $mnp = 0;

    if (defined $headkey) {
	$mnp = 1;
    }
    if ($keySelect == 1) {
	$termkey = lc($termlemm);
    } elsif ($keySelect == 2) {
	$termkey = $termlemm . $termPOStag;
    } else {
	$termkey = $termstr;
    }
    if (!exists($terms->{$termkey})) {
	$$termid++;
	$terms->{$termkey} = {
	    "id" => $termkey,
	    "ID" => $$termid,
	    "form" => lc($termstr),
	    "headid" => $headkey,
	    "modifierid" => $modifierkey, 
	    "origin" => 'distribution',,
	    'MNP' => $mnp,
	    'nbocc' => 0,
	    'position' => $position,
	    'distance' => $distance,
	    'postag' => $termPOStag,
	    'lemma' => $termlemm,
	};
    }

    return($termkey);
}

sub makeDistributionalAnalysis {
    my ($terms, $gatheredDepList, $dep1ToNodes, $nodes, $nodes2links, $linkNodes, $minimumCtxt, $minimumOccCtxt, $minimumFreq, $samepostag, $verbose) = @_;
    
    my $i;
    my $j;
    my $dep2IntersectSize;
    my @dep1list = keys %$gatheredDepList;

    warn "# make distributional analysis ($minimumCtxt / $minimumOccCtxt / $samepostag / $minimumFreq)\n";
    
    my $lastNode = 0;
    for($i = 0; $i< scalar @dep1list; $i++) {
	for ($j = $i+1; $j< scalar @dep1list; $j++) {
	    if (((!defined($minimumFreq)) || (($terms->{$dep1list[$i]}->{'nbocc'} >= $minimumFreq ) && 
		 ($terms->{$dep1list[$j]}->{'nbocc'} >= $minimumFreq ))) &&
		((!$samepostag) || ($terms->{$dep1list[$i]}->{'postag'} eq $terms->{$dep1list[$j]}->{'postag'}) ||
		(uc($terms->{$dep1list[$i]}->{'postag'}) eq "TERM") || (uc($terms->{$dep1list[$j]}->{'postag'}) eq "TERM"))) {
		my @dep2Intersect = &ListDep2Intersect($gatheredDepList->{$dep1list[$i]},$gatheredDepList->{$dep1list[$j]}, $terms, $minimumOccCtxt);
		$dep2IntersectSize = scalar(@dep2Intersect);
		# warn "Intersection ($dep1list[$i] , $dep1list[$j]) : $dep2IntersectSize \n" if ($verbose < 3);
		
		if ($dep2IntersectSize == 0) {
		    warn "No common dependency between the two nodes\n" if ($verbose < 3);
		} else {
		    if ($dep2IntersectSize >= $minimumCtxt) {
			if (($dep2IntersectSize == scalar(keys %{$gatheredDepList->{$dep1list[$i]}})) && 
			    ($dep2IntersectSize == scalar(keys %{$gatheredDepList->{$dep1list[$j]}}))) {
			    # all the modifier are commons for the two word/terms
			    warn "All the dep2 are common between the two dep1\n" if ($verbose < 3);
			    # &mergeDep1InTheSameNode($dep1ToNodes, $nodes, $nodes2links, $linkNodes, $dep1list[$i], $dep1list[$j], \$lastNode);
			    &makeLinkBetweenNodes($dep1ToNodes, $nodes, $nodes2links, $linkNodes, $dep1list[$i], $dep1list[$j], \$lastNode, \@dep2Intersect);
			} else {
			    warn "At least one dep2 is common to the two dep1\n" if ($verbose < 3);
			    # the two dep1 words/terms share at least one dep2 (but not all)
			    &makeLinkBetweenNodes($dep1ToNodes, $nodes, $nodes2links, $linkNodes, $dep1list[$i], $dep1list[$j], \$lastNode, \@dep2Intersect);
			}
		    }
		}
	    }
	}
    }
}

# sub mergeDep1InTheSameNode {
#     my ($dep2nodes, $nodes, $nodes2links, $linkNodes, $dep1i, $dep1j, $lastNode) = @_;

#     my $oldNode;
#     my $link;

#     &makeNode($dep2nodes, $nodes, $dep1i, $dep1j, $lastNode);

#     if (!exists $dep2nodes->{$dep1j}) {
# 	$dep2nodes->{$dep1j} = $dep2nodes->{$dep1i};
# 	push @{$nodes->[$dep2nodes->{$dep1i}]}, $dep1j;
#     } else {
# 	if ($dep2nodes->{$dep1j} != $dep2nodes->{$dep1i}) {
# 	    $oldNode = $dep2nodes->{$dep1j};
# 	    $dep2nodes->{$dep1j} = $dep2nodes->{$dep1i};
# 	    push @{$nodes->[$dep2nodes->{$dep1i}]}, $dep1j;
# 	    @{$nodes->[$oldNode]} = ();
# 	    # 
# 	    foreach $link (@{$nodes2links->[$oldNode]}) {
# 		delete $linkNodes->{$link};
# 	    }
# 	}
#     }
# }

sub makeNode {
    my ($dep2nodes, $nodes, $dep1i, $dep1j, $lastNode) = @_;


    if (!exists $dep2nodes->{$dep1i}) {
	$dep2nodes->{$dep1i} = $$lastNode;
	if (defined $dep1j) {
	    $dep2nodes->{$dep1j} = $dep2nodes->{$dep1i};
	}

	$nodes->[$$lastNode] = $dep1i;
	# $nodes->[$$lastNode] = [];
	# push @{$nodes->[$$lastNode]}, $dep1i;
	# if (defined $dep1j) {
	#     push @{$nodes->[$$lastNode]}, $dep1j;
	# }
	$$lastNode++;
    }
}

# sub removeAndSplitFromNode {
#     my ($dep2nodes, $nodes, $dep1i, $dep1j, $lastNode) = @_;

# }

sub makeLinkBetweenNodes {
    my ($dep1ToNodes, $nodes, $nodes2links, $linkNodes, $dep1i, $dep1j, $lastNode, $dep2Intersect) = @_;

    my $key;

    &makeNode($dep1ToNodes, $nodes, $dep1j, undef, $lastNode);

    &makeNode($dep1ToNodes, $nodes, $dep1i, undef, $lastNode);

    if ($dep1ToNodes->{$dep1i} < $dep1ToNodes->{$dep1j}) {
	$key = $dep1ToNodes->{$dep1i} . "_" . $dep1ToNodes->{$dep1j};
    } else {
	$key = $dep1ToNodes->{$dep1j} . "_" . $dep1ToNodes->{$dep1i};
    }
    $linkNodes->{$key} = $dep2Intersect;
    if (!ref($nodes2links->[$dep1ToNodes->{$dep1i}])) {
	$nodes2links->[$dep1ToNodes->{$dep1i}] = [];
    }
    push @{$nodes2links->[$dep1ToNodes->{$dep1i}]}, $key;

    if (!ref($nodes2links->[$dep1ToNodes->{$dep1j}])) {
	$nodes2links->[$dep1ToNodes->{$dep1j}] = [];
    }
    push @{$nodes2links->[$dep1ToNodes->{$dep1j}]}, $key;
}

sub printTerm2Nodes {
    my ($dep1ToNodes, $terms, $verbose) = @_;

    my $dep;
    my $term;

    print "# List term -> Node\n";
    foreach $dep (keys %$dep1ToNodes) {
	print $terms->{$dep}->{'form'} . " : " . $dep1ToNodes->{$dep} . "\n";
    }
    print "\n";
}

sub printNodes {
    my ($nodes, $terms, $verbose) = @_;

    my $i;
    my $j;
    my $nodeSize;

    print "# Composition of the nodes\n";
    for($i=0;$i < scalar @$nodes;$i++) {
	# if (scalar @{$nodes->[$i]} != 0) {
	    $nodeSize++;
	    print "Node $i\n";
	    print "\t" . $terms->{$nodes->[$i]}->{'form'};
	    print " (" . $terms->{$nodes->[$i]}->{'nbocc'} . ")";
	    print "\n";
	    # for($j=0;$j< scalar @{$nodes->[$i]}; $j++) {
	    # 	print "\t" . $terms->{${$nodes->[$i]}[$j]}->{'form'};
	    # 	print " (" . $terms->{${$nodes->[$i]}[$j]}->{'nbocc'} . ")";
	    # 	print "\n";
	    # }
	# } 
    }
    print "\n";
}

sub printNodeRelations {
    my ($nodes, $terms, $verbose) = @_;

    my $i;
    my $j;
    my $k;
    my $nodeSize;

    print "# Composition of the nodes\n";
    for($i=0;$i < scalar @$nodes;$i++) {
	# if (scalar @{$nodes->[$i]} != 0) {
	    $nodeSize++;
	    print $terms->{$nodes->[$i]}->{'form'} . " : " . $terms->{$nodes->[$i]}->{'form'} . " : insideNode\n";

	    # for($j=0;$j < scalar @{$nodes->[$i]}; $j++) {
	    # 	for($k=$j+1;$k < scalar @{$nodes->[$i]}; $k++) {
	    # 	    if (${$nodes->[$i]}[$j] lt ${$nodes->[$i]}[$k]) {
	    # 		print $terms->{${$nodes->[$i]}[$j]}->{'form'} . " : " . $terms->{${$nodes->[$i]}[$k]}->{'form'} . " : insideNode\n";
	    # 	    } else {
	    # 		print $terms->{${$nodes->[$i]}[$k]}->{'form'} . " : " . $terms->{${$nodes->[$i]}[$j]}->{'form'} . " : insideNode\n";
	    # 	    }
	    # 	}
	    # }
	# } 
    }
    exit;
}

sub printNodes2LinksRelations {
    my ($linkNodes, $nodes, $terms, $similarity, $gatheredDeps, $weight, $semMeasure, $veryall, $verbose) = @_;

    my $link;
    my $i;
    my $j;
    my $dep2;
    my @tmp;
    my $termid1;
    my $termid2;

    my $sim = 0;
    my $k;
    my $l;

    my $str;

    print "# Link between nodes\n";
    foreach $link (keys %$linkNodes) {
	($i,$j) = split /_/, $link;

	$str =  $terms->{$nodes->[$i]}->{'lemma'} . "|" . $terms->{$nodes->[$i]}->{'postag'} . " : " . $terms->{$nodes->[$j]}->{'lemma'} . "|" . $terms->{$nodes->[$j]}->{'postag'} ;
	$sim = $similarity->{$link} ;
	# # $str .= " : betweenNodes : ";
	$str .= " : ";
	if (defined $semMeasure) {
	    $str .= $semMeasure . " = " . $similarity->{$link}->{$semMeasure} ;
	} else {
	    $str .= join(" : ", &getLinkSimilarity($link, $nodes, $linkNodes, $terms, $similarity, $verbose));
	}

	# for($k=0; $k < scalar(@{$nodes->[$i]}) ; $k++) {
	#     for($l=0; $l < scalar(@{$nodes->[$j]}) ; $l++) {
	# 	if (${$nodes->[$i]}[$k] lt ${$nodes->[$j]}[$l]) {
	# 	    $str =  $terms->{${$nodes->[$i]}[$k]}->{'lemma'} . "|" . $terms->{${$nodes->[$i]}[$k]}->{'postag'} . " : " . $terms->{${$nodes->[$j]}[$l]}->{'lemma'} . "|" . $terms->{${$nodes->[$j]}[$l]}->{'postag'} ;
	# 	    # if (${$nodes->[$i]}[$k] lt ${$nodes->[$j]}[$l]) {
	# 	    $sim = $similarity->{${$nodes->[$i]}[$k] . "_" . ${$nodes->[$j]}[$l]} ;
	# 	    # $str .= " : betweenNodes : ";
	# 	    $str .= " : ";
	# 	    $str .= $similarity->{${$nodes->[$i]}[$k] . "_" . ${$nodes->[$j]}[$l]} ;
	# 	    #  } else {
	# 	    #  	print " : betweenNodes3 : " . $similarity->{${$nodes->[$j]}[$l] . "_" . ${$nodes->[$i]}[$k]} . "\n";
	# 	    # }
	# 	} else {
	# 	    $str = $terms->{${$nodes->[$j]}[$l]}->{'lemma'} . "|" . $terms->{${$nodes->[$j]}[$l]}->{'postag'} . " : " . $terms->{${$nodes->[$i]}[$k]}->{'lemma'} . "|" . $terms->{${$nodes->[$i]}[$k]}->{'postag'};
	# 	    # if (${$nodes->[$j]}[$l] lt ${$nodes->[$i]}[$k]) {
	# 	    $sim = $similarity->{${$nodes->[$j]}[$l] . "_" . ${$nodes->[$i]}[$k]} ;
	# 	    # $str .= " : betweenNodes : ";
	# 	    $str .= " : ";
	# 	    $str .= $similarity->{${$nodes->[$j]}[$l] . "_" . ${$nodes->[$i]}[$k]} ;
	# 	    # } else {
	# 	    # 	print " : betweenNodes1 : " . $similarity->{${$nodes->[$i]}[$k] . "_" . ${$nodes->[$j]}[$l]} . "\n";
	# 	    # } 
	# 	}
	#     }
	# }
	# for($m=1;$m < scalar(@{$linkNodes{$edge}});$m++) {
	#     # foreach $dep2 (@{$linkNodes{$edge}}) {
	#     $edge_label .= ',' . $terms->{$linkNodes{$edge}->[$m]}->{'form'} . " (" . $linkNodes{$edge}->[$m] . ")";
	# }
	if (defined $veryall) {
	    $str .= " :";
	    foreach $dep2 (@{$linkNodes{$link}}) {
		$str .= " " . $terms->{$dep2}->{'form'} . " (" . $terms->{$dep2}->{'lemma'} . " / " ; 
		@tmp = values (%{$gatheredDeps->{$nodes->[$i]}->{$dep2}});
		$str .= $tmp[0]->{'freq'}. ")";
		$termid1 = $tmp[0]->{$weight};
		@tmp = values(%{$gatheredDeps->{$nodes->[$j]}->{$dep2}});
		$termid2 = $tmp[0]->{$weight};
		$str .= " / ( $termid1 / $termid2 )";
	    }
	}
	# if ($sim > 0) {
	    print  "$str\n";
	# }
    }
}

sub printNodes2Links {
    my ($linkNodes, $terms, $nodes, $similarity, $verbose) = @_;

    my $link;
    my $i;
    my $j;
    my $dep2;
    my $l;
    my $k;
    my $str;

    print "# Link between nodes\n";
    foreach $link (keys %$linkNodes) {
	($i,$j) = split /_/, $link;
	
	$str =  $terms->{$nodes->[$i]}->{'lemma'} . "|" . $terms->{$nodes->[$i]}->{'postag'} . " <--> " . $terms->{$nodes->[$j]}->{'lemma'} . "|" . $terms->{$nodes->[$j]}->{'postag'} ;

	print "\tNode $i <--> Node $j\n";
 	print "\t\t$str\n";

	print "\t\tList of similarity measures:\n";	
	print "\t\t\t" . join("\n\t\t\t", &getLinkSimilarity($link, $nodes, $linkNodes, $terms, $similarity, $verbose));
	print "\n";

	# for($k=0; $k < scalar(@{$nodes->[$i]}) ; $k++) {
	#     for($l=0; $l < scalar(@{$nodes->[$j]}) ; $l++) {
	# 	if (${$nodes->[$i]}[$k] lt ${$nodes->[$j]}[$l]) {
	# 	    $str =  $terms->{${$nodes->[$i]}[$k]}->{'lemma'} . "|" . $terms->{${$nodes->[$i]}[$k]}->{'postag'} . " <--> " . $terms->{${$nodes->[$j]}[$l]}->{'lemma'} . "|" . $terms->{${$nodes->[$j]}[$l]}->{'postag'} ;
	# 	} else {
	# 	    $str = $terms->{${$nodes->[$j]}[$l]}->{'lemma'} . "|" . $terms->{${$nodes->[$j]}[$l]}->{'postag'} . " <--> " . $terms->{${$nodes->[$i]}[$k]}->{'lemma'} . "|" . $terms->{${$nodes->[$i]}[$k]}->{'postag'};
	# 	}
	#     }
	# }
	print "\t\tList of the common dep2:\n";
	foreach $dep2 (@{$linkNodes->{$link}}) {
	    print "\t\t\t" . $terms->{$dep2}->{'form'} . "\n";
	}
    }
    print "\n";
}

sub computeCC {
    my ($nodes, $linkNodes, $terms, $CC, $CC_inv, $CC_edges, $verbose) = @_;

    my $link;
    my $i;
    my $j;    
    my $CC_id = 1;

    foreach $link (keys %$linkNodes) {
	($i,$j) = split /_/, $link;

	&addCC($i, $j, $link, $CC, $CC_inv, $CC_edges, \$CC_id);
    }    
}

sub printCC {
    my ($nodes, $linkNodes, $terms, $CC, $CC_inv, $CC_edges, $similaritu, $semMeasure, $verbose) = @_;

    my $CC_id;
    my $n = 1;

    foreach $CC_id (sort {(scalar(@{$CC->{$b}}) <=> scalar(@{$CC->{$a}}))} keys %$CC) {
	&printCConStdout($CC_id, $CC, $CC_inv, $CC_edges, $nodes, $linkNodes, $terms, $similaritu, $n, $semMeasure);
	$n++;
	print "\n";
    }

}

sub printCConStdout {
    my ($CC_id, $CC, $CC_inv, $CC_edges, $nodes, $linkNodes, $terms, $similarity, $n, $semMeasure) = @_;

    my $i;
    my $j;
    my $k;
    my $l;
    my $m;
    my $dep2;
    my $node_label;
    my $edge_label;
    my $node;
    my $node1;
    my $node2;
    my $edge;
    my $color;
    my $density;
    $density = &CC_density($CC_id, $CC, $CC_inv, $CC_edges);

    print "CC$CC_id ($n)\n";
    print "\tSize: " . scalar(@{$CC->{$CC_id}}) . " nodes\n";
    print "\t      " . scalar(@{$CC_edges->{$CC_id}}) . " edges\n";
    print "\tDensity: $density\n";
    
    print "\tNodes:\n";
    # print "\t   " . join(':', (@{$CC->{$CC_id}})) . "\n";
    for($i=0; $i < scalar(@{$CC->{$CC_id}}); $i++) {
	# foreach $node (@{$CC->{$CC_id}}) {
	$node1 = $CC->{$CC_id}->[$i];
	$node_label = $terms->{$nodes->[$node1]}->{'form'} . " (" . $nodes->[$node1] .  ")";
	# for($j = 1; $j < scalar @{$nodes->[$node1]}; $j++) {
	#     $node_label .= ', ' . $terms->{$nodes->[$node1]}->{'form'} . " (" . $nodes->[$node1] .  ")";
	# }
	print "\t    $node1: $node_label\n";
    }
    # for($i=0;$i < scalar(@{$CC->{$CC_id}});$i++) {
    # for($i=0; $i < scalar(@{$CC->{$CC_id}}); $i++) {
    # 	$node1 = $CC->{$CC_id}->[$i];
    # 	if (scalar(@{$nodes->[$node1]}) > 1) {
    # 	    print "\tsimilarity between nodes:\n";
    # 	    for($k=0; $k < scalar(@{$nodes->[$node1]}) ; $k++) {
    # 		for($l=$k+1; $l < scalar(@{$nodes->[$node1]}) ; $l++) {
    # 		    # print "\t    " . ${$nodes->[$node1]}[$k] . "/" . ${$nodes->[$node1]}[$l] . "\n";
    # 		    if (${$nodes->[$node1]}[$k] lt ${$nodes->[$node1]}[$l]) {
    # 			print "\t\tSimilarity: " . $terms->{${$nodes->[$node1]}[$k]}->{'form'} . " -- " .$terms->{${$nodes->[$node1]}[$l]}->{'form'} . ": " . $similarity->{${$nodes->[$node1]}[$k] . "_" . ${$nodes->[$node1]}[$l]} . "\n";
    # 		    } else {
    # 			print "\t\tSimilarity: " . $terms->{${$nodes->[$node1]}[$l]}->{'form'} . " -- " .$terms->{${$nodes->[$node1]}[$k]}->{'form'} . ": " . $similarity->{${$nodes->[$node1]}[$l] . "_" . ${$nodes->[$node1]}[$k]} . "\n";
    # 		    }
    # 		}
    # 	    }
    # 	}
    # }
    print "\tEdges:\n";
    foreach $edge (@{$CC_edges->{$CC_id}}) { 
	($i,$j) = split /_/, $edge;

	$edge_label = $terms->{$linkNodes{$edge}->[0]}->{'form'} . " (" . $linkNodes{$edge}->[0] . ")";
	for($m=1;$m < scalar(@{$linkNodes{$edge}});$m++) {
	    # foreach $dep2 (@{$linkNodes{$edge}}) {
	    $edge_label .= ',' . $terms->{$linkNodes{$edge}->[$m]}->{'form'} . " (" . $linkNodes{$edge}->[$m] . ")";
	}
	print "\t    $i -- $j:\n";
	print "\t\tContext: $edge_label\n";
	print "\t\tSimilarity: " . $terms->{$nodes->[$i]}->{'form'} . " -- " . $terms->{$nodes->[$j]}->{'form'} . " : "; # . $similarity->{$edge} . "\n";

	if (defined $semMeasure) {
	    print $similarity->{$edge}->{$semMeasure} ;
	} else {
	    print join(" : ", &getLinkSimilarity($edge, $nodes, $linkNodes, $terms, $similarity, $verbose));
	}
	print "\n";

	# for($k=0; $k < scalar(@{$nodes->[$i]}) ; $k++) {
	#     for($l=0; $l < scalar(@{$nodes->[$j]}) ; $l++) {
	# 	foreach $dep2 (@{$linkNodes{$edge}}) {
	# 	    if (${$nodes->[$i]}[$k] lt ${$nodes->[$j]}[$l]) {
	# 		print "\t\tSimilarity: " . $terms->{${$nodes->[$i]}[$k]}->{'form'} . " -- " . $terms->{${$nodes->[$j]}[$l]}->{'form'} . ": " . $similarity->{${$nodes->[$i]}[$k] . "_" . ${$nodes->[$j]}[$l]} . "\n";
	# 	    } else {
	# 		print "\t\tSimilarity: " . $terms->{${$nodes->[$j]}[$l]}->{'form'} . " -- " . $terms->{${$nodes->[$i]}[$k]}->{'form'} . ": " . $similarity->{${$nodes->[$j]}[$l] . "_" . ${$nodes->[$i]}[$k]} . "\n";
	# 	    }
	# 	}
	#     }
	# }
    }
}

sub DOToutput {
    my ($nodes, $linkNodes, $terms, $CC, $CC_inv, $CC_edges, $dotdir, $verbose) = @_;

    my $link;
    my $i;
    my $j;    
    my $CC_id = 1;
    # my %CC;
    # my %CC_inv;
    # my %CC_edges;

    print "In printCCDOT ($nodes, $linkNodes, $terms, $CC, $CC_inv, $CC_edges, $dotdir, $verbose)\n";


    if (-d $dotdir) {
	warn "delete $dotdir\n";
	rmtree($dotdir);
    }
    mkdir $dotdir;

    my $n = 1;
    foreach $CC_id (sort {(scalar(@{$CC->{$b}}) <=> scalar(@{$CC->{$a}}))} keys %$CC) {
	&printCCIntoDotfile($dotdir, $CC_id, $CC, $CC_inv, $CC_edges, $nodes, $linkNodes, $terms, $n);
	$n++;
    }
}

sub printCCIntoDotfile {
    my ($dotdir, $CC_id, $CC, $CC_inv, $CC_edges, $nodes, $linkNodes, $terms, $n) = @_;

#     my $n=1;
    my $i;
    my $j;
    my $dep2;
    my $node_label;
    my $edge_label;
    my $node;
    my $edge;
    my $color;

    print STDERR "Generating $CC_id (" . scalar(@{$CC->{$CC_id}}) . " nodes)\n";

    my $density;
    $density = &CC_density($CC_id, $CC, $CC_inv, $CC_edges);

    open GRAPHFILE, ">:utf8",  "$dotdir/$n-CC$CC_id.dot";
#     $n++;

    print GRAPHFILE "graph group {\n\n";
    print GRAPHFILE "  label=\"density=$density\\n#nodes=" . scalar(@{$CC->{$CC_id}}) . "\\n#edges=" . scalar(@{$CC_edges->{$CC_id}}) . "\"\n";
    print GRAPHFILE "  overlap=false\n";

    foreach $node (@{$CC->{$CC_id}}) {
	$node_label = $terms->{$nodes->[$node]}->{'form'} . '\n';
	# for($j=0;$j< scalar @{$nodes->[$node]}; $j++) {
	#     $node_label .= $terms->{${$nodes->[$node]}[$j]}->{'form'} . '\n';
	# }
	print GRAPHFILE "  $node [label=\"$node_label\"];\n";
    }

    print GRAPHFILE "\n";
    foreach $edge (@{$CC_edges->{$CC_id}}) { 
	($i,$j) = split /_/, $edge;

	$edge_label = "";
	foreach $dep2 (@{$linkNodes{$edge}}) {
	    $edge_label .= $terms->{$dep2}->{'form'} . '\n';
	}
	$color = "black";
	print GRAPHFILE "  $i -- $j [label=\"$edge_label\" color=\"$color\"];\n";
    }
    print GRAPHFILE "}\n";
    close GRAPHFILE;
}

sub CC_density {
    my ($CC_id, $CC, $CC_inv, $CC_edges) = @_;

#     warn "$CC_id $CC\n";

    my $CC_nodesize = scalar(@{$CC->{$CC_id}});
    my $CC_edgesize = scalar(@{$CC_edges->{$CC_id}});
    my $Complete_Graph_size = ($CC_nodesize * ( $CC_nodesize - 1) ) / 2;

    my $CC_density = $CC_edgesize / $Complete_Graph_size;

#     print STDERR "maximum edge number for $CC_id ($CC_nodesize): " ;
#     print STDERR $Complete_Graph_size;
#     print STDERR "\n";

#     print STDERR "Density for  $CC_id ($CC_edgesize): " ;
#     print STDERR $CC_density;
#     print STDERR "\n";

    return $CC_density;
}


sub addCC {
    my ($label1, $label2, $link, $CC, $CC_inv, $CC_edges, $CC_id) = @_;
    my $label;
    my $oldCC;
    my $edge;

    # print STDERR "add $label1 , $label2\n";
    if (exists $CC_inv->{$label1}) {
	if (exists $CC_inv->{$label2}) {
	    if ($CC_inv->{$label1} ne $CC_inv->{$label2}) {
# 		print STDERR "Merging " . $CC_inv->{$label1} . " and " . $CC_inv->{$label2} . "\n";
		push @{$CC->{$CC_inv->{$label1}}}, @{$CC->{$CC_inv->{$label2}}};

# 		print STDERR "Merge edges of " . $CC_inv->{$label1} . " and " . $CC_inv->{$label2} . "\n";
		foreach $edge (@{$CC_edges->{$CC_inv->{$label2}}}) {
		    push @{$CC_edges->{$CC_inv->{$label1}}}, $edge;
		}
		delete $CC_edges->{$CC_inv->{$label2}};

# 		print STDERR "Merge nodes of " . $CC_inv->{$label1} . " and " . $CC_inv->{$label2} . "\n";
		$oldCC = $CC_inv->{$label2};
		foreach $label (@{$CC->{$CC_inv->{$label2}}}) {
		    $CC_inv->{$label} = $CC_inv->{$label1};
		}

# 		print STDERR "Deleting CC $oldCC\n";
		delete $CC->{$oldCC};
	    }
# 	    print STDERR "Add edge $label1 -- $label2\n";
	    push @{$CC_edges->{$CC_inv->{$label1}}}, "$link";

	} else {
# 	    print STDERR "Adding $label2 in " . $CC_inv->{$label1} . "\n";
	    push @{$CC->{$CC_inv->{$label1}}}, $label2;
	    $CC_inv->{$label2} = $CC_inv->{$label1};
	    push @{$CC_edges->{$CC_inv->{$label1}}}, "$link";
	}
    } else {
	if (exists $CC_inv->{$label2}) {
# 	    print STDERR "Adding $label1 in " . $CC_inv->{$label2} . "\n";
	    push @{$CC->{$CC_inv->{$label2}}}, $label1;
	    $CC_inv->{$label1} = $CC_inv->{$label2};
	    push @{$CC_edges->{$CC_inv->{$label2}}}, "$link";
	} else {
# 	    print STDERR "Creating CC $$CC_id\n";
	    my @newCC = ($label1, $label2);

	    $CC->{$$CC_id} = \@newCC;
	    $CC_inv->{$label1} = $$CC_id;
	    $CC_inv->{$label2} = $$CC_id;
	    my @newCC_edges = ($link);
	    $CC_edges->{$$CC_id} = \@newCC_edges;
	    $$CC_id++;
	}	
    }
    return 0;
}


sub statistics {
    my ($nodes, $linkNodes, $terms, $elementaryTermCheck, $CC) = @_;
# Calcul l'intersection entre les listes de modifieurs de deux Termes

    my $nodeSize;
    my $i;
    my $elementaryTerms;
    my $termid;

    # for($i=0;$i < scalar @nodes;$i++) {
	# if (scalar @{$nodes->[$i]} != 0) {
	    # $nodeSize++;
	# }
    # }
    $nodeSize = scalar @nodes;
    print "# Number of terms: " . scalar(keys %$terms) . "\n";
    if ($elementaryTermCheck) {
	print "# Number of elementary terms: ";
	foreach $termid (keys %$terms) {
	    if (&isElementaryTerm($terms, $termid)) {
		$elementaryTerms++;
	    }
	}
	print "$elementaryTerms\n";
    }
    print "# Number of nodes: $nodeSize\n";
    print "# Number de edges: " . scalar(keys %$linkNodes) . "\n";
    print "# Number of CC: " . scalar(keys %$CC) . "\n";
    print "\n";
}


########################################################################

sub checkDependency {
    my ($dependency) = @_;

    if (($dependency ne "HM") &&
	($dependency ne "MH") && 
	($dependency ne "TM") && 
	($dependency ne "TH")) {
	warn "*** dependency $dependency is not recognized\n";
	warn "    (accepted values: HM, MH, TM, TH)\n";
	return(1);
    } 
    return(0);

}

sub gatherDependencyYatea {
    my ($dependency, $terms, $gatheredDepList, $elementaryTermCheck) = @_;

    # warn "$dependency\n";
    if ($dependency eq "HM") {
	&groupDependency($terms, $gatheredDepList, 'headid', 'modifierid', $elementaryTermCheck);
	return(0);
    }
    if ($dependency eq "MH") {
	&groupDependency($terms, $gatheredDepList, 'modifierid', 'headid', $elementaryTermCheck);
	return(0);
    }
}


sub groupDependency {
    my ($terms, $gatheredDepList, $id1, $id2, $elementaryTermCheck) = @_;

    my $termid;
    my $dep1;
    my $dep2;

    foreach $termid (keys %$terms) {
	# warn "$termid\n";
	if ((!$elementaryTermCheck) || (&isElementaryTerm($terms, $termid))) {
	    $dep1 = &getDep($terms, $termid, $id1);
	    $dep2 = &getDep($terms, $termid, $id2);
	    if ((defined $dep1) && (defined $dep2)) {
		$gatheredDepList->{$dep1}->{$dep2}->{$termid}->{'freq'}++;
	    }
	}
    }
}

sub isElementaryTerm {
    my ($terms, $termid) = @_;

    my $headid;
    my $modifierid;

    if ((defined $terms->{$termid}->{'headid'}) &&
	(defined $terms->{$termid}->{'modifierid'})) {
	$headid = $terms->{$termid}->{'headid'};
	$modifierid = $terms->{$termid}->{'modifierid'};
	if (!((defined $terms->{$headid}->{'headid'}) ||
	      (defined $terms->{$modifierid}->{'headid'}))) {
#	    warn $terms->{$termid}->{'form'} . " is an elementary term\n";

	    return(1);
	}
    }
    return(0);
}


sub getDep {
    my ($terms, $termid, $id) = @_;

    my $term = $terms->{$termid};
    if (defined $term->{$id}) {
	# $term->{$id} . "\t";
	return($terms->{$term->{$id}}->{'id'});
    }
    return(undef);
}

sub printGatheredDeps {
    my ($gatheredDepList, $terms) = @_;

    my $dep1;
    my $dep2;
    my $termid;
    my $messim;

    warn "Gathered Dependencies\n";

    foreach $dep1 (keys %$gatheredDepList) {
	print "$dep1: (" . $terms->{$dep1}->{'form'} . ")\n";
	foreach $dep2 (keys %{$gatheredDepList->{$dep1}}) {
	    print "\t$dep2: (" . $terms->{$dep2}->{'form'} . ")\n";
	    foreach $termid (keys %{$gatheredDepList->{$dep1}->{$dep2}}) {
		print "\t\t" . $terms->{$termid}->{'form'} . " ($termid) " .  $terms->{$termid}->{'nbocc'} . "\n";
		# warn "\t\t\tFreq: " . $gatheredDepList->{$dep1}->{$dep2}->{$termid}->{'freq'} . "\n";
		foreach $messim (keys %{$gatheredDepList->{$dep1}->{$dep2}->{$termid}}) {
		    print "\t\t\t$messim: " . $gatheredDepList->{$dep1}->{$dep2}->{$termid}->{$messim} . "\n";
		}
		# if (exists $gatheredDepList->{$dep1}->{$dep2}->{$termid}->{'MI'}) {
		#     warn "\t\t\tMI: " . $gatheredDepList->{$dep1}->{$dep2}->{$termid}->{'MI'} . "\n";
		# }
		# if (exists $gatheredDepList->{$dep1}->{$dep2}->{$termid}->{'PMI'}) {
		#     warn "\t\t\tPMI: " . $gatheredDepList->{$dep1}->{$dep2}->{$termid}->{'PMI'} . "\n";
		# }
	    }
	}
    }
}

sub ListDep2Intersect {
    my ($dep1List1, $dep1List2, $terms, $minimumOccCtxt) = @_;
    my $communDep2Size = 0; 
    my $dep2;
    my @intersect;
    my $i;
    my @depsT;

    # warn "----------\n";
    foreach $dep2 (keys %$dep1List1) {
	if (exists $dep1List2->{$dep2}) {
#	    warn join(':',keys(%{$dep1List2->{$dep2}})) . "\n";
	    $i = 0;
	    @depsT = keys(%{$dep1List1->{$dep2}});
	    # warn "$dep2 / " . $depsT[$i] . " : " . $terms->{$depsT[$i]}->{'form'} . " : " . $terms->{$depsT[$i]}->{'nbocc'} . "\n";
	    # warn "\t" . $dep1List1->{$dep2}->{$depsT[$i]} . "\n";
	    # warn "\t" . join(', ', keys (%{$dep1List1->{$dep2}->{$depsT[$i]}})) . "\n";
	    # warn "\t" . join(', ', values (%{$dep1List1->{$dep2}->{$depsT[$i]}})) . "\n";
	    # warn "\t" . $dep1List1->{$dep2}->{$depsT[$i]}->{'freq'} . "\n";
	    # while(($i < scalar(@depsT)) && ($terms->{$depsT[$i]}->{'nbocc'} < $minimumOccCtxt)) {
	    while(($i < scalar(@depsT)) && ($dep1List1->{$dep2}->{$depsT[$i]}->{'freq'} < $minimumOccCtxt)) {
		$i++;
	    } 
	    if ($i < scalar(@depsT)) {
		# warn "keep $dep2 (" . $dep1List1->{$dep2}->{$depsT[$i]}->{'freq'} . ")\n";
		$i = 0;
		@depsT = keys(%{$dep1List2->{$dep2}});
  	        # warn "\t" . $dep1List2->{$dep2}->{$depsT[$i]}->{'freq'} . "\n";
		# while(($i < scalar(@depsT)) && ($terms->{$depsT[$i]}->{'nbocc'} < $minimumOccCtxt)) {
		while(($i < scalar(@depsT)) && ($dep1List2->{$dep2}->{$depsT[$i]}->{'freq'} < $minimumOccCtxt)) {
		    $i++;
		} 
		if ($i < scalar(@depsT)) {
#	if (($minimumOccCtxt) && (exists $dep1List2->{$dep2})) {
		    # warn "keep $dep2 (" . $dep1List2->{$dep2}->{$depsT[$i]}->{'freq'} . ")\n";
		    push @intersect, $dep2;
		    $communDep2Size++;
		}
	    }
	}
    }
    # warn "===================\n";
    return(@intersect);

}


########################################################################

sub loadYaTeATerms {
    my ($filename, $terms, $maxtermid, $keySelect, $tagSize, $maxocc, $maxrel, $verbose) = @_;

    my $term;
    my $input = XMLin($filename);
    my %id2lemma;    
    my $termid;

    warn "Load YaTeA terms (XML file)\n";

    if ($verbose < 1) {
	print STDERR Dumper $input;
    }
    
    foreach $term (@{$input->{'LIST_TERM_CANDIDATES'}->{'TERM_CANDIDATE'}}) {
	$termid = &addterm($terms, $term, 'yatea', $maxtermid, $keySelect, $tagSize, \%id2lemma, $verbose);
	# &addterm($terms, $term->{'ID'}, $term->{'FORM'}, $term->{'SYNTACTIC_ANALYSIS'}->{'HEAD'},
	# 	 $term->{'SYNTACTIC_ANALYSIS'}->{'MODIFIER'}->{'content'}, 'yatea', $maxtermid);
	$$maxocc++;
	$$maxrel += $terms->{$termid}->{"nbocc"};
    }
    if ($keySelect > 0) {
	foreach $termid (keys %$terms) {
	    if (exists $id2lemma{$terms->{$termid}->{'headid'}}) {
		$terms->{$termid}->{'headid'} = lc($id2lemma{$terms->{$termid}->{'headid'}});
	    }
	    if (exists $id2lemma{$terms->{$termid}->{'modifierid'}}) {
		$terms->{$termid}->{'modifierid'} = lc($id2lemma{$terms->{$termid}->{'modifierid'}});
	    }
	}
    }
}

sub isMNP {
    my ($listocc) = @_;

    my $isMNP = 1;
    my $occ;

#     warn "$listocc\n";

#     print Dumper $listocc;

    if (ref($listocc) eq "ARRAY") {
	foreach $occ (@$listocc) {
# 	    warn $occ->{'MNP'} . "\n";
	    $isMNP = $isMNP && $occ->{'MNP'};
	}
    } else {
	$isMNP = $isMNP && $listocc->{'MNP'};
    }
#     warn "isMNP: $isMNP\n";
    return($isMNP);
}

sub addterm {
    my ($terms, $term, $origin, $maxtermid, $keySelect, $tagSize, $id2lemma, $verbose) = @_;

    my $termid = $term->{'ID'};
    my $headid = $term->{'SYNTACTIC_ANALYSIS'}->{'HEAD'};
    my $termstr =  $term->{'FORM'};
    my $termlemm = $term->{'LEMMA'};
    my $termstr =  $term->{'FORM'};
    my $termPOStag;
    if (defined $headid) {
	$termPOStag = "TERM";
    } else {
	$termPOStag =  substr($term->{'MORPHOSYNTACTIC_FEATURES'}->{'SYNTACTIC_CATEGORY'}, 0, $tagSize);
    }
    # warn "$termPOStag\n";

    # my $termlemm = $term->{'LEMMA'};
    # my $termnbocc =  $term->{'NUMBER_OCCURRENCES'};
    my $modifierid = $term->{'SYNTACTIC_ANALYSIS'}->{'MODIFIER'}->{'content'};
    my $termnbocc =  $term->{'NUMBER_OCCURRENCES'};
    my $termkey;
    my $headkey;
    my $modifierkey;

    my $position = $term->{'SYNTACTIC_ANALYSIS'}->{'MODIFIER'}->{'POSITION'};
    my $distance = 1;


    if (defined $headid) {
	# warn ">$headid\n" if ($verbose < 1);
	$headid =~ s/[\n\s]+//g;
	$modifierid =~ s/[\n\s]+//g;
	# warn ">>$headid\n" if ($verbose < 1);
    }

    if ($keySelect == 1) {
	$termkey = lc($termlemm);
	if (exists $id2lemma->{$headid}) {
	    $headkey = $id2lemma->{$headid};
	} else {
	    $headkey = $headid;
	}
#	$id2lemma->{$headid} = $headkey;
	if (exists $id2lemma->{$modifierid}) {
	    $modifierkey = $id2lemma->{$modifierid};
	} else {
	    $modifierkey = $modifierid;
	}
#	$id2lemma->{$modifierid} = $modifierkey;
	$id2lemma->{$termid} = $termlemm;
    } elsif ($keySelect == 2) {
	$termkey = $termlemm . $termPOStag;
	if (exists $id2lemma->{$headid}) {
	    $headkey = $id2lemma->{$headid};
	} else {
	    $headkey = $headid;
	}
#	$id2lemma->{$headid} = $headkey;
	if (exists $id2lemma->{$modifierid}) {
	    $modifierkey = $id2lemma->{$modifierid};
	} else {
	    $modifierkey = $modifierid;
	}
	$id2lemma->{$termid} = $termlemm . $termPOStag;

    } else {
	# $termkey = $termid;
	# $headkey = $headid;
	# $modifierkey = $modifierid;

	$termkey = $termstr;
	if (exists $id2lemma->{$headid}) {
	    $headkey = $id2lemma->{$headid};
	} else {
	    $headkey = $headid;
	}
	if (exists $id2lemma->{$modifierid}) {
	    $modifierkey = $id2lemma->{$modifierid};
	} else {
	    $modifierkey = $modifierid;
	}
	$id2lemma->{$termid} = $termstr;
    }
    # warn "$termkey\n";

    if (exists $terms->{$termkey}) {
	$terms->{$termkey}->{'nbocc'} += $termnbocc;
    } else {
	# warn "$termkey\n";
	$terms->{$termkey} = {
	    "id" => $termkey,
	    "ID" => $termid,
	    'lemma' => $termlemm,
	    "postag" => $termPOStag,
	    "form" => lc($termstr),
	    "headid" => $headkey,
	    "modifierid" => $modifierkey, 
	    "origin" => $origin,
	    'MNP' => &isMNP($term->{'LIST_OCCURRENCES'}->{'OCCURRENCE'}),
	    'nbocc' => $termnbocc,
	    'position' => $position,
	    'distance' => $distance,
	};
    }
    if ($verbose  < 1) {
	warn "++\n";
	warn $terms->{$termkey} . "\n";
	warn Dumper($terms->{$termkey}) . "\n";
	warn join(":",keys(%{$terms->{$termkey}})) . "\n";
	warn join(":",values(%{$terms->{$termkey}})) . "\n";
	warn $terms->{$termkey}->{'headid'} . "\n";
	warn "--\n";
    }

    my $id = $termkey;
    $id =~ s/^term//o;

#     warn "$termkey : $id : $maxtermid : $$maxtermid\n";

    if ($id > $$maxtermid) {
	$$maxtermid = $id;
    }
    return($termkey);
}

sub computeSimplifyTerms {
    my ($terms, $maxtermid) = @_;
    my $termid;
    my $headid;
    my $modifierid;

    warn "compute simplified terms\n";
    foreach $termid (keys %$terms) {
	if ((exists $terms->{$termid}->{'MNP'}) && 
	    ($terms->{$termid}->{'MNP'} == 1)) {

	    &simplifyTerm($terms, $termid, $maxtermid);
	}
    }
#    &printYaTeATerms($terms);
#    exit;
}

sub copyAndBranchTerm {
    my ($terms, $termid, $branchid, $maxtermid, $branchDestName, $branchCopyName, $origin) = @_;
    
    my $newtermid;

#     warn "$terms, $termid, $branchid, $maxtermid, $branchDestName, $branchCopyName, $origin\n";
#     warn $terms->{$termid}->{'form'} . " $termid, $branchid, " . $$maxtermid . ", $branchDestName, $branchCopyName, $origin\n";
    $$maxtermid++;
#     warn $$maxtermid . "\n";
    $newtermid = "term". $$maxtermid;
    $terms->{$newtermid} = {};
    %{$terms->{$newtermid}} = %{$terms->{$termid}};
    if (defined $branchCopyName) {
	$terms->{$newtermid}->{$branchDestName} = $terms->{$branchid}->{$branchCopyName};
    } else {
	$terms->{$newtermid}->{$branchDestName} = $branchid;
    }
    $terms->{$newtermid}->{'origin'} = $origin;
    $terms->{$newtermid}->{'id'} = $newtermid;
    $terms->{$newtermid}->{'form'} = $terms->{$terms->{$newtermid}->{'headid'}}->{'form'} . " " . $terms->{$terms->{$newtermid}->{'modifierid'}}->{'form'};
    return($newtermid);
}

sub simplifyTerm {
    my ($terms, $termid, $maxtermid) = @_;

    my @newterms;
    my @newtermsH;
    my @newtermsM;
    my @newterms2;
    my $newtermid;
    my $newtermid2;
    my $newtermidH;
    my $newtermidM;
    my $newtermidH2;
    my $headid;
    my $modifierid;

#    warn "$termid : $maxtermid : $$maxtermid\n";

    if (defined $terms->{$termid}->{'headid'}) {
	push @newterms, &simplifyTerm($terms, $terms->{$termid}->{'headid'}, $maxtermid);
	$headid = $terms->{$termid}->{'headid'};
	foreach $newtermid (@newterms) {
	    $newtermidH = &copyAndBranchTerm($terms, $termid, $newtermid, $maxtermid, 'headid', undef, 'split2a');
	    push @newtermsH, $newtermidH;
	}
    }
    @newterms = ();
    if (defined $terms->{$termid}->{'modifierid'}) {
	push @newterms, &simplifyTerm($terms, $terms->{$termid}->{'modifierid'}, $maxtermid);
	$modifierid = $terms->{$termid}->{'modifierid'};
	foreach $newtermid (@newterms) {
	    $newtermidM = &copyAndBranchTerm($terms, $termid, $newtermid, $maxtermid, 'modifierid', undef, 'split2b');
	    push @newtermsM, $newtermidM;
	    foreach $newtermidH2 (@newtermsH) {
		$newtermid2 = &copyAndBranchTerm($terms, $newtermidM, $newtermidH2, $maxtermid, 'modifierid', undef, 'split3');
		push @newterms2, $newtermid2;
	    }
	}
    }
    @newterms = ();
    push @newtermsH, &simplifyInHead($terms, $termid, $maxtermid);
    push @newtermsM, &simplifyInModifier($terms, $termid, $maxtermid);
    foreach $newtermid (@newtermsH) {
	push @newterms, &simplifyInModifier($terms, $newtermid, $maxtermid);
    }
    
    return(@newterms);
}

sub simplifyInHead {
    my ($terms, $termid, $maxtermid) = @_;

    my @newterms;
    my $newtermid;
    my $headid;

    if (defined $terms->{$termid}->{'headid'}) {
	$headid = $terms->{$termid}->{'headid'};
	if (defined $terms->{$headid}->{'headid'}) {
	    $newtermid = &copyAndBranchTerm($terms, $termid, $headid, $maxtermid, 'headid', 'headid', 'splitH');
	    push @newterms, $newtermid;
	}
    }
    return(@newterms);
}

sub simplifyInModifier {
    my ($terms, $termid, $maxtermid) = @_;

    my @newterms;
    my $newtermid;
    my $modifierid;

    if (defined $terms->{$termid}->{'modifierid'}) {
	$modifierid = $terms->{$termid}->{'modifierid'};
	if (defined $terms->{$modifierid}->{'headid'}) {
	    $newtermid = &copyAndBranchTerm($terms, $termid, $modifierid, $maxtermid, 'modifierid', 'headid', 'splitM');
	    push @newterms, $newtermid;
	}
    }

    return(@newterms);
}

sub printYaTeATerms {
    my ($terms) = @_;
    
    my $term;
    my $termid;

    binmode(stdout, ":utf8");

    foreach $termid (keys %$terms) {
	print $termid . "\t";
	$term = $terms->{$termid};
	print $term->{'id'} . "\t" . $term->{'form'};
	if (defined $term->{"headid"}) {
	    print "\t";
	    print $term->{'headid'} . "\t";
	    print $terms->{$term->{'headid'}}->{'form'} . "\t";
	    print $term->{'modifierid'} . "\t";
	    print $terms->{$term->{'modifierid'}}->{'form'} . "\t";
	    print $term->{'MNP'} . "\t";
	    print $term->{'origin'} . "\t"; # . "\t";
	    print $term->{'nbocc'}; # . "\t";
	} else {
	    print "\t";
	    print $term->{'MNP'} . "\t";
	    print $term->{'origin'} . "\t"; # . "\t";
	    print $term->{'nbocc'}; # . "\t";
	}
	print "\n";
    }
}


########################################################################

sub printSimilarity {
    my ($nodes, $linkNodes, $gatheredDepList, $terms, $similarity, $verbose) = @_;

    my $link;
    my $i;
    my $j;
    my $k;
    my $l;
    my $dep2;
    my $simmes;
    my @mes;

    print "Similarity: \n";
    foreach $link (keys %$linkNodes) {
	($i,$j) = split /_/, $link;
	print $terms->{$nodes->[$i]}->{'form'} . " : " . $terms->{$nodes->[$j]}->{'form'} . " ($link) : ";
	@mes = &getLinkSimilarity($link, $nodes, $linkNodes, $terms, $similarity, $verbose);
	print join(" : ", @mes);
	print "\n";
    }
}

sub getLinkSimilarity {
    my ($link, $nodes, $linkNodes, $terms, $similarity, $verbose) = @_;

    my $i;
    my $j;
    my $k;
    my $l;
    my $dep2;
    my $simmes;
    my $str;
    my @mes;

    ($i,$j) = split /_/, $link;

    push @mes, "FreqT1 = " . $terms->{$nodes->[$i]}->{'nbocc'};
    push @mes, "FreqT2 = " . $terms->{$nodes->[$j]}->{'nbocc'};
    foreach $simmes (keys %{$similarity->{$link}}) {
	push @mes, $simmes . " = " . $similarity->{$link}->{$simmes};
    }
    return(@mes);
}

sub computeSimilarity {
    my ($nodes, $linkNodes, $gatheredDepList, $terms, $similarity, $weight, $verbose) = @_;

    &nbSharedContexts($nodes, $linkNodes, $gatheredDepList, $terms, $similarity, $verbose);

    &FreqSharedContexts($nodes, $linkNodes, $gatheredDepList, $terms, $similarity, $verbose);

    &JaccardMeasure($nodes, $linkNodes, $gatheredDepList, $terms, $similarity, $weight, $verbose);

    if (!defined $weight) {
	$weight = "freq";
    }
    if ($weight !~ /sharedCtxt/i) {
	&CosineMeasure($nodes, $linkNodes, $gatheredDepList, $terms, $similarity, $weight, $verbose);
    }
}

sub nbSharedContexts {
    my ($nodes, $linkNodes, $gatheredDepList, $terms, $similarity, $verbose) = @_;

    my $link;
    my $i;
    my $j;
    my $k;
    my $l;
    my $dep2;
    my @dep1list = keys %$gatheredDepList;

    warn "nbSharedContexts Measure\n";

    foreach $link (keys %$linkNodes) {
	($i,$j) = split /_/, $link;

	$similarity->{$link}->{'sharedCtxt'} = scalar(@{$linkNodes->{$link}});
	
	
	# for($k=0; $k < scalar(@{$nodes->[$i]}) ; $k++) {
	#     for($l=0; $l < scalar(@{$nodes->[$j]}) ; $l++) {
	# 	if (${$nodes->[$i]}[$k] lt ${$nodes->[$j]}[$l]) {
	# 	    $similarity->{${$nodes->[$i]}[$k] . "_" . ${$nodes->[$j]}[$l]}->{'sharedCtxt'} = scalar(@{$linkNodes->{$link}});
	# 	} else {
	# 	    $similarity->{${$nodes->[$j]}[$l] . "_" . ${$nodes->[$i]}[$k]}->{'sharedCtxt'} = scalar(@{$linkNodes->{$link}});
	# 	}
	#     }
	# }
    }

    print "\n";
    
}

sub FreqSharedContexts {
    my ($nodes, $linkNodes, $gatheredDepList, $terms, $similarity, $verbose) = @_;

    my $link;
    my $i;
    my $j;
    my $k;
    my $l;
    my $dep2;
    my $sum;
    my @dep1list = keys %$gatheredDepList;

    warn "FreqSharedContexts Measure\n";

    foreach $link (keys %$linkNodes) {
	($i,$j) = split /_/, $link;

	foreach $dep2 (@{$linkNodes->{$link}}) {
	    $similarity->{$link}->{'freqSharedCtxt'} += &dep_min($gatheredDepList->{$nodes->[$i]}->{$dep2}, $gatheredDepList->{$nodes->[$j]}->{$dep2}, $terms);
	}
	# for($k=0; $k < scalar(@{$nodes->[$i]}) ; $k++) {
	#     for($l=0; $l < scalar(@{$nodes->[$j]}) ; $l++) {
	# 	foreach $dep2 (@{$linkNodes->{$link}}) {
	# 	    if (${$nodes->[$i]}[$k] lt ${$nodes->[$j]}[$l]) {
	# 		$similarity->{${$nodes->[$i]}[$k] . "_" . ${$nodes->[$j]}[$l]}->{'freqSharedCtxt'} += &dep_min($gatheredDepList->{${$nodes->[$i]}[$k]}->{$dep2}, $gatheredDepList->{${$nodes->[$j]}[$l]}->{$dep2}, $terms);
	# 	    } else {
	# 		$similarity->{${$nodes->[$j]}[$l] . "_" . ${$nodes->[$i]}[$k]}->{'freqSharedCtxt'} += &dep_min($gatheredDepList->{${$nodes->[$j]}[$l]}->{$dep2}, $gatheredDepList->{${$nodes->[$i]}[$k]}->{$dep2}, $terms);
	# 	    }
	# 	}
	#     }
	# }
    }
}

sub dep_min {
    my ($dep2_1, $dep2_2, $terms) = @_;

    my $termid;
    my $sumocc1 = 0;
    my $sumocc2 = 0;
    my $sum = 0 ;

    foreach $termid (keys %$dep2_1) {
	$sumocc1 += $terms->{$termid}->{'nbocc'};
	# warn "=>$termid (a) $sumocc1\n";
    }
    foreach $termid (keys %$dep2_2) {
	$sumocc2 += $terms->{$termid}->{'nbocc'};
	# warn "=>$termid (b) $sumocc2\n";
    }
    $sum = &min($sumocc1, $sumocc2);
    # warn "$termid ==>$sum\n";
    return($sum);
}

sub sum_min {
    my ($deps2_1, $deps2_2, $terms) = @_;

    my $sum = 0;
    my $termid;
    my $dep;

    foreach $dep (keys %{$deps2_1}) {
	$sum += &dep_min($deps2_1->{$dep}, $deps2_1->{$dep}, $terms)
    }
    return($sum);
}


sub min {
    my ($i, $j) = @_;

    if ($i < $j) {
	return($i);
    } else {
	return($j);
    }
}

sub JaccardMeasure {
    my ($nodes, $linkNodes, $gatheredDepList, $terms, $similarity, $weight, $verbose) = @_;

    my %mergedCtxt;
    my $ctxt;
    my $link;
    my $i;
    my $j;
    my $k;
    my $l;
    my $dep2;
    my $ctxts;
    my @dep1list = keys %$gatheredDepList;

    if (!defined $weight) {
	$weight = "sharedCtxt";
    }

    warn "Jaccard Measure\n";

    foreach $link (keys %$linkNodes) {
	($i,$j) = split /_/, $link;

	%mergedCtxt = ();
	foreach $ctxt (keys %{$gatheredDepList->{$nodes->[$i]}}) {
	    if ($weight eq "freqSharedCtxt") {
		$mergedCtxt{$ctxt} += $terms->{$ctxt}->{'nbocc'};
	    } else {
		# warn "==> $ctxt\n";
		# warn "=====> " . $terms->{$ctxt}->{'ID'} . "\n";
		# warn "========> " . $terms->{$ctxt}->{'nbocc'} . "\n";
		$mergedCtxt{$ctxt}++;
	    }
	}
	foreach $ctxt (keys %{$gatheredDepList->{$nodes->[$j]}}) {
	    if ($weight eq "freqSharedCtxt") {
		$mergedCtxt{$ctxt} += $terms->{$ctxt}->{'nbocc'};
	    } else {
		$mergedCtxt{$ctxt}++;
	    }
	}

	$ctxts = 0;
	
	foreach $ctxt (keys %mergedCtxt) {
	    $ctxts += $mergedCtxt{$ctxt};
	}
	# warn "$link : " . $similarity->{$link}->{$weight} . " : " . scalar(keys %mergedCtxt) . " : $ctxts\n";

	$ctxts -= $similarity->{$link}->{$weight};

	# warn "$link : " . $similarity->{$link}->{'sharedCtxt'} . " : " . scalar(keys %mergedCtxt) . " : $ctxts\n";

	$similarity->{$link}->{'Jaccard'} = $similarity->{$link}->{$weight};
	$similarity->{$link}->{'Jaccard'} /= $ctxts;



	# for($k=0; $k < scalar(@{$nodes->[$i]}) ; $k++) {
	#     for($l=0; $l < scalar(@{$nodes->[$j]}) ; $l++) {
	# 	if (${$nodes->[$i]}[$k] lt ${$nodes->[$j]}[$l]) {
	# 	    $similarity->{${$nodes->[$i]}[$k] . "_" . ${$nodes->[$j]}[$l]}->{'Jaccard'} = $similarity->{${$nodes->[$i]}[$k] . "_" . ${$nodes->[$j]}[$l]}->{'sharedCtxt'};
	# 		# scalar(@{$linkNodes{$link}});# . " : betweenNodes\n";
	# 	    $similarity->{${$nodes->[$i]}[$k] . "_" . ${$nodes->[$j]}[$l]}->{'Jaccard'} /= scalar(keys %mergedCtxt);
	# 	} else {
	# 	    $similarity->{${$nodes->[$j]}[$l] . "_" . ${$nodes->[$i]}[$k]}->{'Jaccard'} = $similarity->{${$nodes->[$j]}[$l] . "_" . ${$nodes->[$i]}[$k]}->{'sharedCtxt'};
	# 		# scalar(@{$linkNodes{$link}});
	# 	    $similarity->{${$nodes->[$j]}[$l] . "_" . ${$nodes->[$i]}[$k]}->{'Jaccard'} /= scalar(keys %mergedCtxt);
	# 	}
	#     }
	# }
    }
}

sub CosineMeasure {
    my ($nodes, $linkNodes, $gatheredDeps, $terms, $similarity, $weight, $verbose) = @_;

    my @tmp;
    my $termid1;
    my $termid2;
    my $link;
    my $i;
    my $j;
    my $k;
    my $l;
    my $sum;
    my $sum2;
    my $sum3;
    my $dep2;
    my @dep1list = keys %$gatheredDeps;
    my $elt;

    warn "Cosine Measure\n";

    foreach $link (keys %$linkNodes) {
	($i,$j) = split /_/, $link;
	$sum = 0;
	$sum2 = 0;
	$sum3 = 0;

	foreach $dep2 (@{$linkNodes->{$link}}) {
		@tmp = values (%{$gatheredDeps->{$nodes->[$i]}->{$dep2}});
		$termid1 = $tmp[0]->{$weight};
		foreach $elt (@tmp) {
		    # print STDERR "$elt (" . $elt->{'freq'}.  ") : ";
		    $sum2 += $elt->{$weight} * $elt->{$weight};
		}
		@tmp = values(%{$gatheredDeps->{$nodes->[$j]}->{$dep2}});
		$termid2 = $tmp[0]->{$weight};
		foreach $elt (@tmp) {
		    # print STDERR "$elt (" . $elt->{'freq'}.  ") : ";
		    $sum3 += $elt->{$weight} * $elt->{$weight};
		}
		$sum += ($termid1 * $termid2);
	}
	# warn "$sum : $sum2 : $sum3\n";

	$similarity->{$link}->{'Cosine'} = $sum / (sqrt($sum2 * $sum3));

	# for($k=0; $k < scalar(@{$nodes->[$i]}) ; $k++) {
	#     for($l=0; $l < scalar(@{$nodes->[$j]}) ; $l++) {
	# 	if (${$nodes->[$i]}[$k] lt ${$nodes->[$j]}[$l]) {
	# 	    $similarity->{${$nodes->[$i]}[$k] . "_" . ${$nodes->[$j]}[$l]}->{'Cosine'} = $sum / (sqrt($sum2 * $sum3));
	# 	} else {
	# 	    $similarity->{${$nodes->[$j]}[$l] . "_" . ${$nodes->[$i]}[$k]}->{'Cosine'} = $sum / (sqrt($sum2 * $sum3));
	# 	}
	#     }
	# }

    }    
#    exit;
}

sub postprune {
    my ($threshold, $nodes, $linkNodes, $gatheredDepList, $terms, $similarity, $semmeasure, $verbose) = @_;

    my $link;
    my $i;
    my $j;
    my $k;
    my $l;
    my $dep2;
    my @dep1list = keys %$gatheredDepList;

    warn "Prune graph\n";
    my @nodes2remove;
    @nodes2remove = ();


    foreach $link (keys %$linkNodes) {
    	($i,$j) = split /_/, $link;
	# warn $semmeasure . "\n";
	# warn $similarity->{$link}->{$semmeasure} . "\n";
	if ((exists $threshold->{'gt'}) && ($similarity->{$link}->{$semmeasure} <= $threshold->{'gt'}) ||
	    (exists $threshold->{'ge'}) && ($similarity->{$link}->{$semmeasure} < $threshold->{'ge'}) ||
	    (exists $threshold->{'lt'}) && ($similarity->{$link}->{$semmeasure} >= $threshold->{'lt'}) ||
	    (exists $threshold->{'le'}) && ($similarity->{$link}->{$semmeasure} > $threshold->{'le'})) {
	    push @nodes2remove, $link;
	}
	
    	# for($k=0; $k < scalar(@{$nodes->[$i]}) ; $k++) {
    	#     for($l=0; $l < scalar(@{$nodes->[$j]}) ; $l++) {
	# 	if (${$nodes->[$i]}[$k] lt ${$nodes->[$j]}[$l]) {
	# 	    if (((exists $threshold->{'gt'}) && ($similarity->{${$nodes->[$i]}[$k] . "_" . ${$nodes->[$j]}[$l]}->{$semmeasure} < $threshold->{'gt'})) ||
	# 		((exists $threshold->{'ge'}) && ($similarity->{${$nodes->[$i]}[$k] . "_" . ${$nodes->[$j]}[$l]}->{$semmeasure} <= $threshold->{'ge'})) ||
	# 		((exists $threshold->{'lt'}) && ($similarity->{${$nodes->[$i]}[$k] . "_" . ${$nodes->[$j]}[$l]}->{$semmeasure} > $threshold->{'lt'})) ||
	# 		((exists $threshold->{'le'}) && ($similarity->{${$nodes->[$i]}[$k] . "_" . ${$nodes->[$j]}[$l]}->{$semmeasure} >= $threshold->{'le'}))) {
	# 		push @nodes2remove, $link;
	# 	    }
	# 	} else {
	# 	    if (((exists $threshold->{'gt'}) && ($similarity->{${$nodes->[$j]}[$l] . "_" . ${$nodes->[$i]}[$k]}->{$semmeasure} < $threshold->{'gt'})) ||
	# 		((exists $threshold->{'ge'}) && ($similarity->{${$nodes->[$j]}[$l] . "_" . ${$nodes->[$i]}[$k]}->{$semmeasure} <= $threshold->{'ge'})) ||
	# 		((exists $threshold->{'lt'}) && ($similarity->{${$nodes->[$j]}[$l] . "_" . ${$nodes->[$i]}[$k]}->{$semmeasure} > $threshold->{'lt'})) ||
	# 		((exists $threshold->{'le'}) && ($similarity->{${$nodes->[$j]}[$l] . "_" . ${$nodes->[$i]}[$k]}->{$semmeasure} >= $threshold->{'le'}))) {
	# 		push @nodes2remove, $link;
	# 	    }
	# 	}
    	#     }
    	# }
    }
    foreach $link (@nodes2remove) {
    	delete $linkNodes->{$link};
    }

    # print "\n";
    
}

sub computeCtxtMeasures {
    my ($terms, $gatheredDepList, $maxocc, $maxrel) = @_;

    # warn "$maxocc, $maxrel\n";exit;

    my $dep1;
    my $dep2;
    my $termid;
    my $mi;
    my $pmi;
    my $freqrel;
    my $termsum;

    warn "# compute Mutual information\n";
    foreach $dep1 (keys %$gatheredDepList) {
	foreach $dep2 (keys %{$gatheredDepList->{$dep1}}) {
	    $termsum = 0;
	    foreach $termid (keys %{$gatheredDepList->{$dep1}->{$dep2}}) {
		$termsum += $gatheredDepList->{$dep1}->{$dep2}->{$termid}->{'freq'};
	    }

	    $freqrel = $termsum / $terms->{$dep1}->{'nbocc'};
	    $pmi = log(($termsum / $maxrel) / (($terms->{$dep1}->{'nbocc'} / $maxocc) * ($terms->{$dep2}->{'nbocc'} / $maxocc))) / log(2);
	    $mi = $pmi * ($termsum) ;
	    foreach $termid (keys %{$gatheredDepList->{$dep1}->{$dep2}}) {
		$gatheredDepList->{$dep1}->{$dep2}->{$termid}->{'PMI'} = $pmi;
		$gatheredDepList->{$dep1}->{$dep2}->{$termid}->{'MI'} = $mi;
		$gatheredDepList->{$dep1}->{$dep2}->{$termid}->{'freqrel'} = $freqrel;
	    }
	}
    }
}


# }

########################################################################

=head1 NAME

DistributionalAnalysis.pl - Performs a distributional analysis of a term list


=head1 SYNOPSIS

DistributionalAnalysis.pl [option] --terms <filename> --dot <DotDirectory> --distribution <filename>

where option can be --help --man --verbose 
                    --dependency (HM|MH) --simplifiyterms --elementaryTermCheck --relations 
                    --printCC --semmeasure (sharedCtxt|freqSharedCtxt|Jaccard) --threshold integer 
                    --lemma --lemmapos --all --termsAndNodes --tagSize --minimumCtxt --minimumOccCtxt
                    --minimumFreq --postagTermsAD --veryall --weight --samepostag --IM

=head1 OPTIONS AND ARGUMENTS

=over 4

=item --terms <filename>, -t <filename>

Set the term list to load. The term list must be in the YaTeA output format.

=item --distribution <filename>, -D <filename>

Set the list word sor terms with their contexts to load. Each line of
the list describes the word and its context. It is composed of nine
columns. The three first columns decribe the word (inflected form, POS
tag, lemma), the next three columns describe a context word (inflected
form, POS tag, lemma). The seventh column indicates the position of
the context word against the word (two values: C<After> and C<Before>)
and the eighth columns its distance (as a number of words). the ninth
column indicates if the word is a term (C<TERM>) or a word (C<WORD>).

=item --dependency (HM|MH), -d (HM|MH)

Consider the distribion of the component. 

If the value is HM, the distribution is performed according to the
modifiers, the heads can be grouped (into connected component or
gathered in the same node).

If the value is HM, the distribution is performed according to the
heads, the modifiers can be grouped (into connected component or
gathered in the same node).

=item --simplifyterms, -s

This option allows to compute simplied terms (as a preliminary step to
get elementary terms).

=item --elementaryTermCheck, -c

This option allows to only take into account elementary terms,
i.e. two word terms. Those terms can be computed by simplication with
the option C<--simplifyterms>.

=item --relations, -r

The output is a set of relations. The two first columns are the linked
terms. The third column indicates whether the relation is inside a
node C<insideNode> or between nodes C<betweenNode>.

=item --dot <DotDirectory>

This option outputs the connected components in the dot format. All
the connected components are recorded in different files in the
directory C<DotDirectory>.

=item --printCC

This option prints the connected components on the output. Each
connected component is separated by a empty line.

=item --semmeasure (sharedCtxt, freqSharedCtxt, Jaccard, Cosine), -S (sharedCtxt, freqSharedCtxt, Jaccard, Cosine)

This option specificy the semantic measure to apply for computing
similarity value of each distributional relation. The value
C<sharedCtxt> is used to define the semantic similarity as the number
of shared context of two words or terms. 

The value C<freqSharedCtxt> is used to define the semantic similarity
as the frequency of the of shared context of two words or terms. The
value CJaccard> is used to define the semantic similarity as the
Jaccard measure between two words or terms (i.e. the normalized number
of shared context). The value Cosine is used to compute the cosine of
the description of two words sharing contexts (avalaile with PMI, MI
and FreqRel weights).

=item --threshold (gt|lt)=value, -T (gt|lt)=value

This option specify the threshold to prune the graph according the
similarity measure associated to each distributional relation. The
hash table can have two keys C<gt> and C<lt>. The key C<gt> means that
the similarity has to be greater or equal to the corresponding
value. The key C<lt> means that the similarity has to be lesser or
equal to the corresponding value. Both keys can be combined to define
an interval.

=item --lemma, -l

With this option, lemma are used as keys of the terms. Distributional
analysis will be done by taking into account lemma (not inflected
forms).


=item --lemmapos, -p

With this option, the concatenation of lemma and Part-of-Speech tags
are used as keys of the terms. Distributional analysis will be done by
taking into account lemma and POS tags (not inflected forms).

=item --tagSize value

This option sets the size of the Part-of-Speech tags

=item --termsAndNodes, -n

The output is the list of terms, nodes, and links betweend nodes.

=item -all, -a

The output is combination of the --relation and --termsAndNodes options.

=item --minimumFreq value, -F value

This option sets the minimum of frequency (included) of the terms.

=item --minimumCtxt value, -m value

This option sets the minimum of the number of common contexts between
two terms that are used for the distributional analysis.

=item --minimumOccCtxt value, -O value

This option sets the minimum of the occurrences of common contexts
between two terms that are used for the distributional analysis.

=item --veryall, -A

Print additionnal statistical information with the relation output

=item --weight (freqrel, PMI, MI), -w  (freqrel, PMI, MI)

This option sets the weight to used with cosine measure (C<freqrel> -
relative frequency, C<PMI> point-wise mutual information, C<MI> mutual
information).

=item --samepostag

This option restricts the distributional analysis to words having the
same POS tag. Terms are considered as nouns.

=item --postagTermsAD, -P

This option sets the filename containing the list of POS tag for the
terms.

=item --exceptions, -e

This option sets the filename containing the list of word/term
exceptions


=item --help, -?

Print help message for using grepTerms.pl

=item --man

print man page of grepTerms.pl

=item --verbose, -v

Go into the verbose mode

=back

=head1 DESCRIPTION

This program performs the distributional analysis of the term list
according to syntactic dependencies. Terms have been extracted from a
corpus and parsed by YaTeA.

Two types of dependencies are taken into account: 

=over 2

=item 

modifiers (HM), that leads to group heads of the terms

=item 

heads (MH), that leads to group modifierss of the terms

=back

The output provides a representation of the resulting connected components:

=over 2

=item 

list of the terms and the related node

=item 

list of the nodes and the referred terms 

=item 

list of the edges between nodes with common dependencies.

=back

If two components share the same dependency components exactly, they
are gathered in the nodes.

If two components share at least a dependency component (but not all),
a edge is created between the two related nodes.

=head1 TODO

=over 2

=item 

Provide a dot output

=item 

Provide all the common dependencies shared by the terms of a same node

=item 

Provide statistics (frequency of the dependencies, of the terms)

=item 

Computed distances and thresholds for filtering the edges

=item 

Compute elementary terms

=back

=head1 SEE ALSO


Lingua::YaTeA

=head1 AUTHOR

Thierry Hamon, E<lt>thierry.hamon@univ-paris13.frE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 Thierry Hamon

This is free software; you can redistribute it and/or modify it under
the same terms as Perl itself, either Perl version 5.8.4 or, at your
option, any later version of Perl 5 you may have available.

=cut

