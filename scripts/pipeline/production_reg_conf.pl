# Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Release Coordinator, please update this file before starting every release
# and check the changes back into GIT for everyone's benefit.

# Things that normally need updating are:
#
# 1. Release number
# 2. Check the name prefix of all databases
# 3. Possibly add entries for core databases that are still on genebuilders' servers

use strict;
use Bio::EnsEMBL::Utils::ConfigRegistry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;


# ------------------------- CORE DATABASES: --------------------------------------

# The majority of core databases live on two staging servers:
Bio::EnsEMBL::Registry->load_registry_from_url(
  'mysql://ensro@ens-staging1/76');

Bio::EnsEMBL::Registry->load_registry_from_url(
  'mysql://ensro@ens-staging2/76');

# Extra core databases that live on genebuilders' servers:

#Bio::EnsEMBL::DBSQL::DBAdaptor->new(
#    -host => 'genebuild1',
#    -user => 'ensro',
#    -port => 3306,
#    -species => 'gorilla_gorilla',
#    -group => 'core',
#    -dbname => 'ba1_gorilla31_new',
#);


# ------------------------- COMPARA DATABASES: -----------------------------------

# Individual pipeline database for ProteinTrees:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'compara3',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_ptrees',
    -dbname => 'mm14_protein_trees_76b',
);

# Individual pipeline database for ncRNAtrees:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'compara4',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_nctrees',
    -dbname => 'mp12_compara_nctrees_76b',
);

# Individual pipeline database for Families:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'compara2',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_families',
    -dbname => 'lg4_families_76',
);


# Compara Master database:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'compara1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_master',
    -dbname => 'sf5_ensembl_compara_master',
);

# previous release database on one of Compara servers:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'compara5',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_prev',
    -dbname => 'lg4_ensembl_compara_75',
);

# current release database on one of Compara servers:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'compara5',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_curr',
    -dbname => 'mp12_ensembl_compara_76',
);

# previous ancestral database on one of Compara servers:
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'ens-livemirror',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'ancestral_prev',
    -dbname => 'ensembl_ancestral_75',
);

# current ancestral database on one of Compara servers:
Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host => 'compara5',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'ancestral_curr',
    -dbname => 'mp12_ensembl_ancestral_76',
);

# ensembl production:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'ens-staging',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'ensembl_production',
    -dbname => 'ensembl_production',
);

# NCBI taxonomy database (also maintained by production team):
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'ens-livemirror',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'ncbi_taxonomy',
    -dbname => 'ncbi_taxonomy',
);

# final compara on staging:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( ## HAS TO BE CREATED (FINAL DB)
    -host => 'ens-staging',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_staging',
    -dbname => 'ensembl_compara_76',
);


1;
