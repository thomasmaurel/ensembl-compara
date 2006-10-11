#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Pecan

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

This module acts as a layer between the Hive sysmem and the Bio::EnsEMBL::Analysis::Runnable::Pecan
module since the ensembl-analysis API does not know about ennembl-compara

Pecan wants the files to be provided in the same orer as in the tree string. This module starts
by getting all the DnaFragRegions of the SyntenyRegion and then use them to edit the tree (some
nodes must be removed and otehr one must be duplicated in order to cope with deletions and
duplications). The buid_tree_string methods numbers the sequences in order and changes the
order of the dnafrag_regions array accordingly. Last, the dumpFasta() method dumps the sequences
according to the tree_string order.

=cut

=head1 CONTACT

Javier Herrero <jherrero@ebi.ac.uk>

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Pecan;

use strict;
use Bio::EnsEMBL::Analysis::Runnable::Pecan;
use Bio::EnsEMBL::Compara::DnaFragRegion;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use Bio::EnsEMBL::Hive::Process;

our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'hiveDBA'} = Bio::EnsEMBL::Hive::DBSQL::DBAdaptor->new(-DBCONN => $self->{'comparaDBA'}->dbc);
  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  if (!$self->method_link_species_set_id) {
    throw("MethodLinkSpeciesSet->dbID is not defined for this Pecan job");
  }

  ## Store DnaFragRegions corresponding to the SyntenyRegion in $self->dnafrag_regions(). At this point the
  ## DnaFragRegions are in random order
  $self->_load_DnaFragRegions($self->synteny_region_id);
  if ($self->get_species_tree and $self->dnafrag_regions) {
    ## Get the tree string by taking into account duplications and deletions. Resort dnafrag_regions
    ## in order to match the name of the sequences in the tree string (seq1, seq2...)
    $self->_build_tree_string;
    ## Dumps fasta files for the DnaFragRegions. Fasta files order must match the entries in the
    ## newick tree. The order of the files will match the order of sequences in the tree_string.
    $self->_dump_fasta;
  } else {
    throw("Cannot start Pecan job because some information is missing");
  }

  return 1;
}

sub run
{
  my $self = shift;

  my $runnable = new Bio::EnsEMBL::Analysis::Runnable::Pecan(
      -workdir => $self->worker_temp_directory,
      -fasta_files => $self->fasta_files,
      -tree_string => $self->tree_string,
      -analysis => $self->analysis,
      -parameters => $self->{_java_options},
      -max_block_size => $self->{_max_block_size},
      );
  $self->{'_runnable'} = $runnable;
  $runnable->run_analysis;
}

sub write_output {
  my ($self) = @_;

  my $mlssa = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  my $mlss = $mlssa->fetch_by_dbID($self->method_link_species_set_id);
  my $gaba = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;
  $gaba->use_autoincrement(0);
  my $gaa = $self->{'comparaDBA'}->get_GenomicAlignAdaptor;
  $gaa->use_autoincrement(0);
  foreach my $gab (@{$self->{'_runnable'}->output}) {
    foreach my $ga (@{$gab->genomic_align_array}) {
      $ga->adaptor($gaa);
      $ga->method_link_species_set($mlss);
      $ga->level_id(1);
      unless (defined $gab->length) {
        $gab->length(length($ga->aligned_sequence));
      }
    }
    $gab->adaptor($gaba);
    $gab->method_link_species_set($mlss);
    $gaba->store($gab);
  }
  return 1;
}

##########################################
#
# getter/setter methods
# 
##########################################

#sub input_dir {
#  my $self = shift;
#  $self->{'_input_dir'} = shift if(@_);
#  return $self->{'_input_dir'};
#}

sub synteny_region_id {
  my $self = shift;
  $self->{'_synteny_region_id'} = shift if(@_);
  return $self->{'_synteny_region_id'};
}

sub dnafrag_regions {
  my $self = shift;
  $self->{'_dnafrag_regions'} = shift if(@_);
  return $self->{'_dnafrag_regions'};
}

sub fasta_files {
  my $self = shift;

  $self->{'_fasta_files'} = [] unless (defined $self->{'_fasta_files'});

  if (@_) {
    my $value = shift;
    push @{$self->{'_fasta_files'}}, $value;
  }

  return $self->{'_fasta_files'};
}

sub get_species_tree {
  my $self = shift;

  my $newick_species_tree;
  if (defined($self->{_species_tree})) {
    return $self->{_species_tree};
  } elsif ($self->{_tree_analysis_data_id}) {
    my $analysis_data_adaptor = $self->{hiveDBA}->get_AnalysisDataAdaptor();
    $newick_species_tree = $analysis_data_adaptor->fetch_by_dbID($self->{_tree_analysis_data_id});
  } elsif ($self->{_tree_file}) {
    open(TREE_FILE, $self->{_tree_file}) or throw("Cannot open file ".$self->{_tree_file});
    $newick_species_tree = join("", <TREE_FILE>);
    close(TREE_FILE);
  }

  if (!defined($newick_species_tree)) {
    throw("Cannot get the species tree");
  }

  $newick_species_tree =~ s/^\s*//;
  $newick_species_tree =~ s/\s*$//;
  $newick_species_tree =~ s/[\r\n]//g;

  $self->{'_species_tree'} =
      Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick_species_tree);

  return $self->{'_species_tree'};
}

sub tree_string {
  my $self = shift;
  $self->{'_tree_string'} = shift if(@_);
  return $self->{'_tree_string'};
}

sub method_link_species_set_id {
  my $self = shift;
  $self->{'_method_link_species_set_id'} = shift if(@_);
  return $self->{'_method_link_species_set_id'};
}

##########################################
#
# internal methods
#
##########################################

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  if(defined($params->{'synteny_region_id'})) {
    $self->synteny_region_id($params->{'synteny_region_id'});
  }
  if(defined($params->{'method_link_species_set_id'})) {
    $self->method_link_species_set_id($params->{'method_link_species_set_id'});
  }
  if(defined($params->{'java_options'})) {
    $self->{_java_options} = $params->{'java_options'};
  }
  if(defined($params->{'tree_file'})) {
    $self->{_tree_file} = $params->{'tree_file'};
  }
  if(defined($params->{'tree_analysis_data_id'})) {
    $self->{_tree_analysis_data_id} = $params->{'tree_analysis_data_id'};
  }
  if(defined($params->{'max_block_size'})) {
    $self->{_max_block_size} = $params->{'max_block_size'};
  }

  return 1;
}


=head2 _load_DnaFragRegions

  Arg [1]    : int syteny_region_id
  Example    : $self->_load_DnaFragRegions();
  Description: Gets the list of DnaFragRegions for this
               syteny_region_id. Resulting DnaFragRegions are
               stored using the dnafrag_regions getter/setter.
  Returntype : listref of Bio::EnsEMBL::Compara::DnaFragRegion objects
  Exception  :
  Warning    :

=cut

sub _load_DnaFragRegions {
  my ($self, $synteny_region_id) = @_;
  my $dnafrag_regions = [];

  # Fail if dbID has not been provided
  return $dnafrag_regions if (!$synteny_region_id);

  my $sra = $self->{'comparaDBA'}->get_SyntenyRegionAdaptor;
  my $sr = $sra->fetch_by_dbID($self->synteny_region_id);

  foreach my $dfr (@{$sr->children}) {  
    $dfr->disavow_parent;
    push(@{$dnafrag_regions}, $dfr);
  }

  $sr->release_tree;

  $self->dnafrag_regions($dnafrag_regions);
}


=head2 _dump_fasta

  Arg [1]    : -none-
  Example    : $self->_dump_fasta();
  Description: Dumps FASTA files in the order given by the tree
               string (needed by Pecan). Resulting file names are
               stored using the fasta_files getter/setter
  Returntype : 1
  Exception  :
  Warning    :

=cut

sub _dump_fasta {
  my $self = shift;

  my $all_dnafrag_regions = $self->dnafrag_regions;

  ## Dump FASTA files in the order given by the tree string (needed by Pecan)
  my @seqs = ($self->tree_string =~ /seq(\d+)/g);
  foreach my $seq_id (@seqs) {
    my $dfr = $all_dnafrag_regions->[$seq_id-1];
    my $file = $self->worker_temp_directory . "/seq" . $seq_id . ".fa";

    open F, ">$file" || throw("Couldn't open $file");

    print F ">DnaFrag", $dfr->dnafrag_id, "|", $dfr->dnafrag->name, ".",
        $dfr->dnafrag_start, "-", $dfr->dnafrag_end, ":", $dfr->dnafrag_strand,"\n";
    my $slice = $dfr->slice;
    throw("Cannot get slice for DnaFragRegion in DnaFrag #".$dfr->dnafrag_id) if (!$slice);
    my $seq = $slice->get_repeatmasked_seq(undef, 1)->seq;
    $seq =~ s/(.{80})/$1\n/g;
    chomp $seq;
    print F $seq,"\n";

    close F;

    push @{$self->fasta_files}, $file;
  }

  return 1;
}


=head2 _build_tree_string

  Arg [1]    : -none-
  Example    : $self->_build_tree_string();
  Description: This method sets the tree_string using the orginal
               species tree and the set of DnaFragRegions. The
               tree is edited by the _update_tree method which
               resort the DnaFragRegions (see _update_tree elsewwhere
               in this document)
  Returntype : -none-
  Exception  :
  Warning    :

=cut

sub _build_tree_string {
  my $self = shift;

  my $tree = $self->get_species_tree;
  return if (!$tree);

  $tree = $self->_update_tree($tree);

  my $tree_string = $tree->newick_simple_format;
  # Remove quotes around node labels
  $tree_string =~ s/"(seq\d+)"/$1/g;
  # Remove branch length if 0
  $tree_string =~ s/\:0\.0+(\D)/$1/g;
  $tree_string =~ s/\:0([^\.\d])/$1/g;

  $tree->release_tree;

  $self->tree_string($tree_string);
}


=head2 _update_tree

  Arg [1]    : Bio::EnsEMBL::Compara::NestedSet $tree_root
  Example    : $self->_update_nodes_names($tree);
  Description: This method updates the tree by removing or
               duplicating the leaves according to the orginal
               tree and the set of DnaFragRegions. The tree nodes
               will be renamed seq1, seq2, seq3 and so on and the
               DnaFragRegions will be resorted in order to match
               the names of the nodes (the first DnaFragRegion will
               correspond to seq1, the second to seq2 and so on).
  Returntype : Bio::EnsEMBL::Compara::NestedSet (a tree)
  Exception  :
  Warning    :

=cut

sub _update_tree {
  my $self = shift;
  my $tree = shift;

  my $all_dnafrag_regions = $self->dnafrag_regions();
  my $ordered_dnafrag_regions = [];

  my $idx = 1;
  foreach my $this_leaf (@{$tree->get_all_leaves}) {
    my $these_dnafrag_regions = [];
    ## Look for DnaFragRegions belonging to this genome_db_id
    foreach my $this_dnafrag_region (@$all_dnafrag_regions) {
      if ($this_dnafrag_region->dnafrag->genome_db_id == $this_leaf->name) {
        push (@$these_dnafrag_regions, $this_dnafrag_region);
      }
    }

    if (@$these_dnafrag_regions == 1) {
      ## If only 1 has been found...
      $this_leaf->name("seq".$idx++); #.".".$these_dnafrag_regions->[0]->dnafrag_id);
      push(@$ordered_dnafrag_regions, $these_dnafrag_regions->[0]);

    } elsif (@$these_dnafrag_regions > 1) {
      ## If more than 1 has been found...
      my $first_dnafrag_region = shift(@$these_dnafrag_regions);
      my $copy = $this_leaf->copy;
      $copy->name("seq".$idx++);
      push(@$ordered_dnafrag_regions, $first_dnafrag_region);
      $this_leaf->add_child($copy);
      $copy = $this_leaf->children->[0]->copy;
      foreach my $this_dnafrag_region (@$these_dnafrag_regions) {
        $copy->name("seq".$idx++);
        push(@$ordered_dnafrag_regions, $this_dnafrag_region);
        $this_leaf->add_child($copy);
      }

    } else {
      ## If none has been found...
      $this_leaf->disavow_parent;
      $tree = $tree->minimize_tree;
    }
  }
  $self->dnafrag_regions($ordered_dnafrag_regions);

  if (scalar(@$all_dnafrag_regions) != scalar(@$ordered_dnafrag_regions)) {
    throw("Tree has a wrong number of leaves after updating the node names");
  }

  if ($tree->get_child_count == 1) {
    my $child = $tree->children->[0];
    $child->parent->merge_children($child);
    $child->disavow_parent;
  }

  return $tree;
}

1;
