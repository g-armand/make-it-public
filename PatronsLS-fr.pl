#!/usr/bin/perl

# use strict;

# (.../PUN/.../[0-9]+)*

my $terme = "([^\/ ]+\/(N[^\/]+|ADJ[^/]?|DET|CON|PRP|SYM|PRP[^/]*|VER:pper)\/[^/]+\/[0-9]+ )+";
my $liste_terme = "$terme((,\/PUN\/,\/[0-9]+|[^/]+\/KON\/[^/]+\/[0-9]+)) ($terme((,\/PUN\/,\/[0-9]+|[^/]+\/KON\/[^/]+\/[0-9]+))?)+( ($terme))?";
my $ligne;
# my $tmp;
my $Hyperonyme;
my $liste_hypo;
my $Patron = "";

my $patronInfo;

my @Patrons;

my $nbPatrons = 0;

while($ligne=<STDIN>) {
    $Patron = "";
    @Patrons = ();

     &projectionPatron($ligne, "($terme)(\Q\(\E\/[^\/]+\/\Q\(\E\/[0-9]+ ($liste_terme))", "Patron SN ( LISTE )", 1, 4, \$nbPatrons);

     &projectionPatron($ligne, "($terme)(:\/[^\/]+\/:\/[0-9]+ ($liste_terme))", "Patron SN ( LISTE )", 1, 4, \$nbPatrons);
    &projectionPatron($ligne, "[^\/]+\/[^\/]+\/(deux|trois|quatre|2|3|4)\/[0-9]+ ($terme)(\Q\(\E\/[^\/]+\/\Q\(\E\/[0-9]+ ($liste_terme))", "Patron (deux|trois...|2|3|4...) SN ( LISTE )", 2, 5, \$nbPatrons);
    &projectionPatron($ligne, "[^\/]+\/[^\/]+\/(certain|quelque|de autre)\/[0-9]+ ($terme)(\Q\(\E\/[^\/]+\/\Q\(\E\/[0-9]+ ($liste_terme))", "Patron (certain|quelque|de autre) SN ( LISTE )", 2, 5, \$nbPatrons);
    &projectionPatron($ligne, "[^\/]+\/[^\/]+\/(deux|trois|quatre|2|3|4)\/[0-9]+ ($terme)(:\/[^\/]+\/:\/[0-9]+ ($liste_terme))", "Patron (deux|trois...|2|3|4...) SN : LISTE ", 2, 5, \$nbPatrons);
    &projectionPatron($ligne, "[^\/]+\/[^\/]+\/(certain|quelque|de autre)\/[0-9]+ ($terme)(:\/[^\/]+\/:\/[0-9]+ ($liste_terme))", "Patron (certain|quelque|de autre) SN : LISTE ", 2, 5, \$nbPatrons);
     &projectionPatron($ligne, "[^\/]+\/PRP\/de\/[0-9]+ [^\/]+\/ADJ\/autre\/[0-9]+ ($terme)[^\/]+\/PRO:DEM\/tel\/[0-9]+ que\/[^\/]+\/que\/[0-9]+ ($liste_terme)", "Patron de autre SN tel que LISTE", 1, 4, \$nbPatrons);

     &projectionPatron($ligne, "($terme)[^\/]+\/PRO:DEM\/tel\/[0-9]+ que\/[^\/]+\/que\/[0-9]+ ($liste_terme)", "Patron SN tel que LISTE", 1, 4, \$nbPatrons);
     &projectionPatron($ligne, "($terme),\/[^\/]+\/,\/[0-9]+ [^\/]+\/[^\/]+\/particulierement\/[0-9]+ ($terme)", "Patron (de autre)? SN, particulierement LISTE", 1, 4, \$nbPatrons);
     &projectionPatron($ligne, "[^\/]+\/PRP\/de\/[0-9]+ [^\/]+\/ADJ\/autre\/[0-9]+ ($terme)comme\/[^\/]+\/comme\/[0-9]+ ($liste_terme)", "Patron de autre SN comme LISTE", 1, 4, \$nbPatrons);

     &projectionPatron($ligne, "($terme)comme\/[^\/]+\/comme\/[0-9]+ ($liste_terme)", "Patron SN comme LISTE", 1, 4, \$nbPatrons);
     &projectionPatron($ligne, "($terme)[^\/]+\/PRO:DEM\/tel\/[0-9]+ ($liste_terme)", "Patron SN tel LISTE", 1, 4, \$nbPatrons);
     &projectionPatron($ligne, "($terme)[^\/]+\/[^\/]+\/(et|ou)\/[0-9]+ [^\/]+\/[^\/]+\/de\/[0-9]+ [^\/]+\/[^\/]+\/autre\/[0-9]+ ($liste_terme)", "Patron SN (et|ou) de autre LISTE", 1, 4, \$nbPatrons);
     &projectionPatron($ligne, "($terme)et\/[^\/]+\/et\/[0-9]+ [^\/]+\/[^\/]+\/notamment\/[0-9]+ ($terme)", "Patron (de autre)? SN et notamment LISTE", 1, 4, \$nbPatrons);
     &projectionPatron($ligne, "[^\/]+\/[^\/]+\/chez\/[0-9]+ ($terme),\/[^\/]+\/,\/[0-9]+ ($terme)", "Patron (de autre)? SN et notamment LISTE", 1, 4, \$nbPatrons);

    foreach $patronInfo (@Patrons) {
	$Patron = $patronInfo->{'Patron'};
	$Hyperonyme = $patronInfo->{'Hyperonyme'};
	$liste_hypo = $patronInfo->{'liste_hypo'};

	if ($ARGV[0] eq "-liste") {
	    while($liste_hypo =~ /($terme)/gc) {
		print &cleanBrillOutput($1) . "\t" . &cleanBrillOutput($Hyperonyme) . "\n";
	    }
#  	    print "\t$4\n";
	} else {
	    print $Patron;
	    print "Phrase: " . &cleanBrillOutput($ligne) . "\n";
	    print "Hyperonyme: " . &cleanBrillOutput($Hyperonyme) . "\n";
	    print "Hyponyme:\n";
	    while($liste_hypo =~ /($terme)/gc) {
		print "\t" . &cleanBrillOutput($1) . "\n";
	    }
#  	    print "\t$4\n";
	    print "\n";
	}
    }
}


print "# Nombre de patrons trouves: $nbPatrons\n";


sub cleanBrillOutput {
    my $in = $_[0];

    my $out ;

    while($in =~ /([^\/]+)\/[^\/]+\/[^\/]+\/[0-9]+/gc) {
	$out .= $1;
    }
#     $out =~ s/ $//g;
    return($out);
}


# (([^/ ]+/(N[^/]+|ADJ[^/]?|DET|CON|PRP|SYM|PRP[^/]*|VER:pper)/[^/]+/[0-9]+ )+)((/[^/]+/(/[0-9]+ (([^/ ]+/(N[^/]+|ADJ[^/]?|DET|CON|PRP|SYM|PRP[^/]*|VER:pper)/[^/]+/[0-9]+ )+((,/PUN/,/[0-9]+|[^/]+/KON/[^/]+/[0-9]+)) (([^/ ]+/(N[^/]+|ADJ[^/]?|DET|CON|PRP|SYM|PRP[^/]*|VER:pper)/[^/]+/[0-9]+ )+((,/PUN/,/[0-9]+|[^/]+/KON/[^/]+/[0-9]+)) )+))


sub projectionPatron {
    my ($ligne, $patron_regex, $patron_desc, $H, $L, $nbPatrons) = @_;

#    warn "$patron_regex\n";

    

    $ligne =~ /^./;
#     if ($ligne =~ /($terme) (\(\/[^\/]+\/\(\/[0-9]+ ($liste_terme) \)\/[^\/]+\/\)\/[0-9]+)/){ # 
    while ($ligne =~ m!$patron_regex!gc){ # 
	$Patron = "$patron_desc\n";
	$Hyperonyme = $$H;
	$liste_hypo = $$L;
	push @Patrons, { "Patron" => $Patron,
	                 "Hyperonyme" => $Hyperonyme,
	                 "liste_hypo" => $liste_hypo
	};
	$$nbPatrons++;
    }

}
