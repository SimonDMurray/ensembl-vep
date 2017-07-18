=head1 LICENSE

Copyright [2016-2017] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

 Questions may also be sent to the Ensembl help desk at
 <http://www.ensembl.org/Help/Contact>.

=cut

# EnsEMBL module for Bio::EnsEMBL::VEP::IDTranslator
#
#

=head1 NAME

Bio::EnsEMBL::VEP::IDTranslator - IDTranslator runner class

=head1 SYNOPSIS

my $idt = Bio::EnsEMBL::VEP::IDTranslator->new();
my $translated = $idt->translate('rs699');

=head1 DESCRIPTION

The IDTranslator class serves as a wrapper for a number of
VEP classes that is used to "translate" variant identifiers
to all possible alternatives:

- variant IDs
- HGVS genomic (g.)
- HGVS coding (c.)
- HGVS protein (p.)

=head1 METHODS

=cut


use strict;
use warnings;

package Bio::EnsEMBL::VEP::IDTranslator;

use base qw(Bio::EnsEMBL::VEP::Runner);

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::VEP::Runner;
use Bio::EnsEMBL::VEP::Utils qw(find_in_ref merge_arrays);


=head2 new

  Arg 1      : hashref $config
  Example    : $runner = Bio::EnsEMBL::VEP::IDTranslator->new($config);
  Description: Creates a new IDTranslator object. The $config hash passed is
               used to create a Bio::EnsEMBL::VEP::Config object; see docs
               for this object and the id_translator script itself for allowed
               parameters.
  Returntype : Bio::EnsEMBL::VEP::IDTranslator
  Exceptions : throws on invalid configuration, see Bio::EnsEMBL::VEP::Config
  Caller     : haplo
  Status     : Stable

=cut

sub new {
  my $caller = shift;
  my $class = ref($caller) || $caller;

  my $config = shift || {};

  $config->{$_} = 1 for grep {!exists($config->{$_})} qw(
    database
    merged
    lrg
    check_existing
    failed
    no_prefetch
    ambiguous_hgvs
    hgvsg_use_accession
    no_stats
    json
    quiet
  );

  $config->{fields} ||= 'id,hgvsg,hgvsc,hgvsp';

  my %opt_map = ('id' => 'check_existing');
  my %set_fields = map {$_ => 1} split(',', $config->{fields});

  # do some trickery to make sure we're not running unnecessary code
  # this first one only switches on the HGVS options for the requested fields  
  $config->{$_} = 1 for grep {$_ =~ /^hgvs/} keys %set_fields;

  # and this one switches on check_existing if the user wants variant IDs
  $config->{$opt_map{$_}} = 1 for grep {$set_fields{$_}} keys %opt_map;
  
  my $self = $class->SUPER::new($config);

  return $self;
}

sub init {
  my $self = shift;

  return 1 if $self->{_initialized};

  $self->SUPER::init();

  $_->{cache_region_size} = 1 for @{$self->get_all_AnnotationSources};
  $self->internalise_warnings();

  return 1;
}

sub translate_all {
  my $self = shift;

  $self->init();

  my $results = $self->_get_all_results();

  $self->finish();

  return $results;
}

sub translate {
  my $self = shift;
  my $input = shift;

  throw("ERROR: No input data supplied") unless $input;

  $self->param('input_data', $input);

  $self->init();
  my $results = $self->_get_all_results();

  $self->reset();

  return $results;
}

sub reset {
  my $self = shift;

  delete($self->{$_}) for qw(parser input_buffer);
  $self->param('format', 'guess');
  $self->param('input_data', undef);
}

sub _get_all_results {
  my $self = shift;

  my $results = {};
  my $order   = [];

  my %want_keys = map {$_ => 1} @{$self->param('fields')};

  while(my $line = $self->next_output_line(1)) {
    delete($line->{id});
    my $line_id = $line->{input};
    
    merge_arrays($order, [$line_id]);
    find_in_ref($line, \%want_keys, $results->{$line_id} ||= {input => $line_id});
  }

  return [map {$results->{$_}} @$order];
}

1;