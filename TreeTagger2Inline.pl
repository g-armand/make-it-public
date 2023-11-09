#!/usr/bin/perl

#######################################################################
#
# Last Update: 16/10/2002 (mm/dd/yyyy date format)
# 
# Copyright (C) 2002 Thierry Hamon
#
# Written by thierry.hamon@lipn.univ-paris13.fr
#
# Author : Thierry Hamon
# Email : thierry.hamon@lipn.univ-paris13.fr
# URL : http://www-lipn.univ-paris13.fr/~hamon
#
########################################################################

# Passage du format de sortie du TreeTagger
# au format d'entrée de Acabit
# 
# Au passage quelques corrections sur les sorties 
# (etiquetage specifique au domaine de la genomique)

# Lecture de la sortie du TreeTagger

# 
# ATTENTION (PROGRAMMATION) : Etant donne qu'on joue avec le nom des
# variable ($$CHMP2, par exemple), il faut faire attention a la
# declaration des variables (local ou my)
# 


# ./TreeTagger2AcabitIn.pl TreeTagger2AcabitIn.rules < ../Fichiers/932-formatBJ.treetagger > ../Fichiers/932-formatBJ-TT.lem 

my $cle;
my @tabCorpus;

$cle = 0;
while($ligne = <STDIN>) {
    chomp $ligne;
    push @tabligne, $ligne;
    ($FF, $TAG, $LM) = split /\t/, $ligne;
#      push @tabFF, $FF;
#      push @tabTAG, $TAG;
#      push @tabLM, $LM;
    push @tabCorpus, {"LM" => $LM, "FF" => $FF, "TAG" => $TAG};
    if (!exists $tabhLM{$FF}) {
	$tabhLM{$FF}=$cle;
	$cle++;
    }
}

# Lecture des regles

open FICHIER_REGLES, $ARGV[0];

while($ligne=<FICHIER_REGLES>) {
    chomp $ligne;
    if (($ligne !~ /#/) && ($ligne !~ /^\s*$/)) {
	 ($CHMP1, $VAL1, $CHMP2, $VAL2) = split /\t/, $ligne;
	 my $prem = {"CHMP" => $CHMP1, "VAL" => $VAL1};
	 my $conseq = {"CHMP" => $CHMP2, "VAL" => $VAL2};
	 my $regle = {"PREM" => $prem, "CONSEQ" => $conseq};
	 push @tabRegles, $regle;
     }
}


close FICHIER_REGLES;

# Transformation et Generation de chaque ligne

$comptphr=1;
$ligne = "<FIC NUM=\"932-formatBJ-TT-$comptphr\">\n\n";

for($i=0;$i<scalar @tabligne;$i++) {
    if (($i>0)&&(($tabCorpus[$i-1]->{"TAG"} eq "SENT")) || ($tabCorpus[$i-1]->{"TAG"} eq ".")) {
	print $ligne;
	$comptphr++;
	$ligne = "\n\n\n\n<FIC NUM=\"932-formatBJ-TT-$comptphr\">\n\n";
    }
    $FF = $tabCorpus[$i]->{"FF"};
    $TAG = $tabCorpus[$i]->{"TAG"};
    $LM = $tabCorpus[$i]->{"LM"};
    $CLE = $tabhLM{$tabCorpus[$i]->{"FF"}};
    foreach $regle (@tabRegles) {
	$CHMP1 = $regle->{"PREM"}->{"CHMP"};
	$VAL1 = $regle->{"PREM"}->{"VAL"};
	$CHMP2 = $regle->{"CONSEQ"}->{"CHMP"};
	$VAL2 = $regle->{"CONSEQ"}->{"VAL"};

	if ($CHMP1 !~ /\&/) {
	    ($FF, $TAG, $LM) = &AppliRegle($FF, $TAG, $LM, $CHMP1, quotemeta $VAL1, $CHMP2, $VAL2 );
   	} else { # cas des regles complexes
	    if ($CHMP1 =~ /\&/) {
		@tabCHMP1 = split / *& */, $CHMP1;
		@tabVAL1 = split / *& */, $VAL1;
		@tabCHMP2 = split / *& */, $CHMP2;
		@tabVAL2 = split / *& */, $VAL2;
		($FF, $TAG, $LM) = &AppliRegleComplexe($FF, $TAG, $LM, \@tabCHMP1, \@tabVAL1, \@tabCHMP2, \@tabVAL2 );

	    } else {
		print STDERR "****** Erreur dans la regle complexe\n";
	    }
	}
    }
    $ligne = $ligne . $FF;
    $ligne = $ligne .  "/";
    $ligne = $ligne . $TAG;
    $ligne = $ligne .  "/";
    $ligne = $ligne . $LM;
    $ligne = $ligne .  "/";
    $ligne = $ligne .  $CLE;
    $ligne = $ligne .  " ";
}

print "\n";

# Affichage

sub AppliRegle() {
    local ($FF, $TAG, $LM, $CHMP1, $VAL1, $CHMP2, $VAL2 ) = @_;
    
    if ($$CHMP1 =~ /^$VAL1$/) { # cas des regles simples
	if ($VAL2 !~ /^\$/) {
	    $$CHMP2 =~ s/^$VAL1$/$VAL2/;
	} else {
	    if ($VAL2 eq "\$FF") {
		$$CHMP2 = $FF;
	    }
	    if ($VAL2 eq "\$LM") {
		$$CHMP2 = $LM;
	    }
	    if ($VAL2 eq "\$TAG") {
		$$CHMP2 = $TAG;
	    }
	}
    }
    return ($FF, $TAG, $LM);
}

sub AppliRegleComplexe () {
    local ($FF, $TAG, $LM, $ref_tabCHMP1, $ref_tabVAL1, $ref_tabCHMP2, $ref_tabVAL2) = @_;
    my $i;

    local @tabCHMP1 = @$ref_tabCHMP1;
    local @tabVAL1 = @$ref_tabVAL1;
    local @tabCHMP2 = @$ref_tabCHMP2;
    local @tabVAL2 = @$ref_tabVAL2;

    # Test sur les premisses de la regle

    for($i=0;$i <scalar @tabCHMP1;$i++) {
	local $CHMP1 = $tabCHMP1[$i];
	local $VAL1 = quotemeta $tabVAL1[$i];

	if ($$CHMP1 !~ /^$VAL1$/) {
	    return ($FF, $TAG, $LM);
	}
    }

    # Consequence

    for($i=0;$i <scalar @tabCHMP2;$i++) {
	local $CHMP2 = $tabCHMP2[$i];
	local $VAL2 = $tabVAL2[$i];
	if ($VAL2 !~ /^\$/) {
	    $$CHMP2 = $VAL2;
	} else {
	    if ($VAL2 eq "\$FF") {
		$$CHMP2 = $FF;
	    }
	    if ($VAL2 eq "\$LM") {
		$$CHMP2 = $LM;
	    }
	    if ($VAL2 eq "\$TAG") {
		$$CHMP2 = $TAG;
	    }
	}
	
    }
    

    return ($FF, $TAG, $LM);;
    
}

sub min_max () {
    @tabtmp = sort {$a <=> $b} @_;
    return ($tabtmp[0], $tabtmp[$#tabtmp]);
}
