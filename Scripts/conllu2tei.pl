#!/usr/bin/perl
# Convert CoNLL-U file to TEI <text>
use warnings;
use utf8;
binmode STDERR, 'utf8';
binmode STDIN,  'utf8';
binmode STDOUT, 'utf8';

# Extended TEI prefixes to use on annotation
$xpos_prefix = 'mte';    # We assume XPOS is MULTEXT-East MSD
$ud_prefix   = 'ud-syn'; # Prefix for syntactic roles
$ud_type     = 'UD-SYN'; # Type of syntatic dependencies

# ID prefixes
$doc_prefix  = 'doc';    # Prefix for document IDs, if they are numeric in source
$p_prefix    = 'p';      # Prefix for paragraph IDs, if they are numeric in source
$s_prefix    = 's';      # Prefix for sentence IDs, if they  are numeric or do not exist in source

print "<TEI xmlns=\"http://www.tei-c.org/ns/1.0\" xml:lang=\"sl\">\n";
undef $/;
print <DATA>;
print "<text>\n";
print "<body>\n";
$has_div = 0;
$has_p   = 0;
$has_s   = -1; #Means this is the first sentence
$doc_n   = 0;
$p_n     = 0;
$s_n     = 0;

$/ = "\n\n";
while (<>) {
    if (m|# newdoc id = (.+)|) {
        if (m|# newpar id|) {$has_p = 1}
        $doc_id = $1;
        $has_div = 1;
        $s_n = 0;
        if ($has_div) {
            if ($has_p) {print "</p>\n"}
            else {print "</ab>\n"}
            print "</div>\n";
        }
        if ($doc_id =~ /^\d/) {
            $doc_n = $doc_id;
            $doc_id = $doc_prefix . $doc_n
        }
        else {$doc_n++}
        print "<div xml:id=\"$doc_id\" n=\"$doc_n\">\n";
        unless ($has_p) {print "<ab>\n"}
        $has_p = 0;
    }
    if (m|# newpar id = (.+)|) {
        $p_id = $1;
        if ($has_p) {print "</p>\n"}
        $has_p = 1;
	$p_n++;
        $s_n = 0;
        if ($p_id =~ /^\d/) {
            $p_id = $p_prefix . $p_n
        }
        print "<p xml:id=\"$p_id\" n=\"$p_n\">\n";
    }
    if (m|# sent_id = (.+)|) {
        $has_s = 1;
        $s_id = $1;
        $s_n++;
        if ($s_id =~ /^\d/) {
            $s_id = "$p_id.$s_prefix$s_n";
        }
    }
    else {
        print "<ab>\n" if $has_s == -1;
        $has_s = 0;
        $s_n++;
        $s_id = "$s_prefix$s_n";
    }
    print conllu2tei($s_id, $s_n, $_);
}
if ($has_p) {print "</p>\n"}
else {print "</ab>\n"}
if ($has_div) {print "</div>\n"}
print "</body>\n";
print "</text>\n";
print "</TEI>\n";

#Convert one sentence into TEI
sub conllu2tei {
    my $id = shift;
    my $n  = shift;
    my $conllu = shift;
    my $tei;
    my $tag;
    my $element;
    my $space;
    my $ner_prev;
    my $ner;
    my @ids = ();
    my @toks = ();
    my @deps = ();
    $tei = "<s xml:id=\"$id\" n=\"$n\">\n";
    foreach my $line (split(/\n/, $conllu)) {
        next unless $line =~ /^\d+\t/;
        chomp;
        my ($n, $token, $lemma, $upos, $xpos, $ufeats, $link, $role, $extra, $local) 
            = split /\t/, $line;
        # Don't know how to do syntactic words yet
        # if ($n =~ m|(\d+)-(\d+)|) {
        #     $from = $1;
        #     $to = $2
        # }
        $xpos =~ s/-+$//;   # Get rid of trailing dashes sometimes introduced by Stanford NLP
        
        if ($token =~ /^[[:punct:]]+$/) {
            $tag = 'pc';
            if ($upos ne '_') {
                # print STDERR "WARN: changing PoS to punctuation for\n$line\n"
                #     unless ($xpos eq '_' or $xpos eq 'Z')
                #     and ($upos eq 'PUNCT' or $upos eq 'SYM');
                if ($token =~ /[$%§©+−×÷=<>]/) {$upos = 'SYM'}
                else {$upos = 'PUNCT'}
                $ufeats = '_';
            }
            $xpos = 'Z' unless $xpos eq '_';
        }
        else {$tag = 'w'}
        
        if ($upos !~ /_/) {
            $feats = "UPosTag=$upos";
            $feats .= "|$ufeats" if $ufeats ne '_';
        }
        
        #Bug in STANZA:
        if ($role eq '<PAD>') {$role = 'dep'}
        
        if (($ner) = $local =~ /NER=([A-Z-]+)/) {
            if (my ($type) = $ner =~ /^B-(.+)/) {
                if ($ner_prev and $ner_prev ne 'O') {
                    push(@toks, "</name>\n")
                }
                push(@toks, "<name type=\"$type\">\n");
            }
            elsif ($ner eq 'O' and $ner_prev and $ner_prev ne 'O') {
		push(@toks, "</name>\n")
            }
            $ner_prev = $ner
        }
        
        $space = $local !~ s/SpaceAfter=No//;
        $token = &xml_encode($token);
        $lemma = &xml_encode($lemma);
        if ($tag eq 'w') {$element = "<$tag>$token</$tag>"}
        elsif ($tag eq 'pc') {$element = "<$tag>$token</$tag>"}
        if ($xpos ne '_') {$element =~ s|>| ana=\"$xpos_prefix:$xpos\">|}
        if ($feats and $feats ne '_') {$element =~ s|>| msd=\"$feats\">|}
        if ($tag eq 'w' and $lemma ne '_') {$element =~ s|>| lemma=\"$lemma\">|}
        $element =~ s|>| join="right">| unless $space;
        push @ids, $id . '.t' . $n;
        push @toks, $element;
        push @deps, "$link\t$n\t$role" #Only if we have a parse
            if $role ne '_';
    }
    if ($ner_prev and $ner_prev ne 'O') {
        push(@toks, '</name>')
    }
    unless (@deps) {
        $tei .= join "\n", @toks;
    }
    else {
        #Give IDs to tokens as we have a parse
        foreach my $id (@ids) {
            $element = '';
            #We can have a <name> tags here, skip them
            while ($element !~ m|<w| and $element !~ m|<pc| and @toks) {
                $tei .= "$element";
                if (@toks) {$element = shift @toks}
                else {$element = ''}
            }
            $element =~ s| | xml:id="$id" |;
            $tei .= "$element\n" if $element;
        }
        # If we still have elements left over
        if (@toks) {
            $element = shift @toks;
            $tei .= "$element\n";
        }
        $tei .= "<linkGrp type=\"$ud_type\" targFunc=\"head argument\" corresp=\"#$id\">\n";
        foreach $dep (@deps) {
            my ($head, $arg, $role) = split /\t/, $dep;
            $head_id = $id;  #if 0 points to sentence id
            $head_id .= '.t' . $head if $head; 
            $arg_id = $id . '.t' . $arg;
            $tei .= "  <link ana=\"$ud_prefix:$role\" target=\"#$head_id #$arg_id\"/>\n";
        }
        $tei .=  "</linkGrp>";
    }
    $tei .= "\n</s>\n";
    return $tei
}

sub xml_encode {
    my $str = shift;
    $str =~ s|&|&amp;|g;
    $str =~ s|<|&lt;|g;
    $str =~ s|>|&gt;|g;
    #$str =~ s|"|&quot;|g;
    return $str
}
__DATA__
  <teiHeader>
    <fileDesc>
      <titleStmt>
        <title>CLARIN.SI TEI document converted from CoNLL-U</title>
      </titleStmt>
      <publicationStmt>
        <p>Unknown</p>
      </publicationStmt>
      <sourceDesc>
        <p>CoNNL-U file</p>
      </sourceDesc>
    </fileDesc>
    <encodingDesc>
      <classDecl>
        <taxonomy xml:id="UD-SYN">
          <desc xml:lang="en"><term>UD syntactic relations</term>
          </desc>
          <category xml:id="acl">
            <catDesc xml:lang="en"><term>acl</term>: Clausal modifier of noun (adjectival clause)</catDesc>
          </category>
          <category xml:id="advcl">
            <catDesc xml:lang="en"><term>advcl</term>: Adverbial clause modifier</catDesc>
          </category>
          <category xml:id="advmod">
            <catDesc xml:lang="en"><term>advmod</term>: Adverbial modifier</catDesc>
          </category>
          <category xml:id="amod">
            <catDesc xml:lang="en"><term>amod</term>: Adjectival modifier</catDesc>
          </category>
          <category xml:id="appos">
            <catDesc xml:lang="en"><term>appos</term>: Appositional modifier</catDesc>
          </category>
          <category xml:id="aux">
            <catDesc xml:lang="en"><term>aux</term>: Auxiliary</catDesc>
          </category>
          <category xml:id="case">
            <catDesc xml:lang="en"><term>case</term>: Case marking</catDesc>
          </category>
          <category xml:id="cc">
            <catDesc xml:lang="en"><term>cc</term>: Coordinating conjunction</catDesc>
          </category>
          <category xml:id="ccomp">
            <catDesc xml:lang="en"><term>ccomp</term>: Clausal complement</catDesc>
          </category>
          <category xml:id="cc_preconj">
            <catDesc xml:lang="en"><term>cc:preconj</term>: Preconjunct</catDesc>
          </category>
          <category xml:id="conj">
            <catDesc xml:lang="en"><term>conj</term>: Conjunct</catDesc>
          </category>
          <category xml:id="cop">
            <catDesc xml:lang="en"><term>cop</term>: Copula</catDesc>
          </category>
          <category xml:id="csubj">
            <catDesc xml:lang="en"><term>csubj</term>: Clausal subject</catDesc>
          </category>
          <category xml:id="dep">
            <catDesc xml:lang="en"><term>dep</term>: Unspecified dependency</catDesc>
          </category>
          <category xml:id="det">
            <catDesc xml:lang="en"><term>det</term>: Determiner</catDesc>
          </category>
          <category xml:id="discourse">
            <catDesc xml:lang="en"><term>discourse</term>: Discourse element</catDesc>
          </category>
          <category xml:id="expl">
            <catDesc xml:lang="en"><term>expl</term>: Expletive</catDesc>
          </category>
          <category xml:id="fixed">
            <catDesc xml:lang="en"><term>fixed</term>: Fixed multiword expression</catDesc>
          </category>
          <category xml:id="flat">
            <catDesc xml:lang="en"><term>flat</term>: Flat multiword expression</catDesc>
          </category>
          <category xml:id="flat_foreign">
            <catDesc xml:lang="en"><term>flat:foreign</term>: Flat multiword expression: foreign</catDesc>
          </category>
          <category xml:id="flat_name">
            <catDesc xml:lang="en"><term>flat:name</term>: Flat name</catDesc>
          </category>
          <category xml:id="iobj">
            <catDesc xml:lang="en"><term>iobj</term>: Indirect object</catDesc>
          </category>
          <category xml:id="mark">
            <catDesc xml:lang="en"><term>mark</term>: Marker</catDesc>
          </category>
          <category xml:id="nmod">
            <catDesc xml:lang="en"><term>nmod</term>: Nominal modifier</catDesc>
          </category>
          <category xml:id="nsubj">
            <catDesc xml:lang="en"><term>nsubj</term>: Nominal subject</catDesc>
          </category>
          <category xml:id="nummod">
            <catDesc xml:lang="en"><term>nummod</term>: Numeric modifier</catDesc>
          </category>
          <category xml:id="obj">
            <catDesc xml:lang="en"><term>obj</term>: Object</catDesc>
          </category>
          <category xml:id="obl">
            <catDesc xml:lang="en"><term>obl</term>: Oblique nominal</catDesc>
          </category>
          <category xml:id="parataxis">
            <catDesc xml:lang="en"><term>parataxis</term>: Parataxis</catDesc>
          </category>
          <category xml:id="punct">
            <catDesc xml:lang="en"><term>punct</term>: Punctuation</catDesc>
          </category>
          <category xml:id="root">
            <catDesc xml:lang="en"><term>root</term>: Root</catDesc>
          </category>
          <category xml:id="xcomp">
            <catDesc xml:lang="en"><term>xcomp</term>: Open clausal complement</catDesc>
          </category>
        </taxonomy>
        <taxonomy xml:id="NER">
          <desc xml:lang="en"><term>Named entities</term></desc>
          <desc xml:lang="sl"><term>Imenske entitete</term></desc>
          <category xml:id="PER">
            <catDesc xml:lang="sl"><term>oseba</term></catDesc>
            <catDesc xml:lang="en"><term>person</term></catDesc>
          </category>
          <category xml:id="LOC">
            <catDesc xml:lang="sl"><term>lokacija</term></catDesc>
            <catDesc xml:lang="en"><term>location</term></catDesc>
          </category>
          <category xml:id="ORG">
            <catDesc xml:lang="sl"><term>organizacija</term></catDesc>
            <catDesc xml:lang="en"><term>organization</term></catDesc>
          </category>
          <category xml:id="MISC">
            <catDesc xml:lang="sl"><term>drugo</term></catDesc>
            <catDesc xml:lang="en"><term>miscellaneous</term></catDesc>
          </category>
        </taxonomy>
      </classDecl>
      <listPrefixDef>
        <prefixDef ident="mte" 
		   matchPattern="(.+)"
		   replacementPattern="http://nl.ijs.si/ME/V6/msd/tables/msd-fslib-sl.xml#$1">
          <p xml:lang="en">Private URIs with this prefix point to feature-structure elements 
          defining the Slovenian MULTEXT-East Version 6 MSDs.</p>
        </prefixDef>
        <prefixDef ident="ud-syn" matchPattern="(.+)" replacementPattern="#$1">
          <p xml:lang="en">Private URIs with this prefix point to elements giving their name. 
          In this document they are simply local references into the UD-SYN taxonomy 
          categories in the corpus root TEI header.</p>
        </prefixDef>
      </listPrefixDef>
      <appInfo>
        <application version="1.0" ident="classla">
          <label>CLASSLA</label>
          <desc xml:lang="en">Linguistic annotation with CLASSLA tool-chaing trained for Slovene, 
          available from 
          <ref target="https://github.com/clarinsi/classla">https://github.com/clarinsi/classla</ref>.</desc>
        </application>
      </appInfo>
    </encodingDesc>
    <profileDesc>
      <langUsage>
        <language ident="sl">
          <term xml:lang="sl">slovenščina</term>
          <term xml:lang="en">Slovene</term>
        </language>
        <language ident="en">
          <term xml:lang="sl">angleščina</term>
          <term xml:lang="en">English</term>
        </language>
      </langUsage>
    </profileDesc>
  </teiHeader>
