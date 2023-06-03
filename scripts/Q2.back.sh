#!/bin/bash
#--------------------------------------------------------------------------------
#  SBATCH CONFIG
#--------------------------------------------------------------------------------
#SBATCH --job-name=Q2.back        # name for the job
#SBATCH --cpus-per-task=1              # number of cores
#SBATCH --mem=100G                       # total memory
#SBATCH --nodes 1
#SBATCH --time 01:00:00                 # time limit in the form days-hours:minutes
#SBATCH --mail-user=zlmg2b@umsystem.edu    # email address for notifications
#SBATCH --mail-type=FAIL,END,BEGIN           # email types
#SBATCH --partition Lewis            # max of 1 node and 4 hours; use `Lewis` for larger jobs
#--------------------------------------------------------------------------------

echo "### Starting at: $(date) ###"

module load miniconda3
source activate qiime2-2021.8

## Generate core-metrics results
## sampling depth determined from Dada2_table.qzv (lowest feature count/sample > 10,000) - 1
qiime diversity core-metrics-phylogenetic \
  --i-table ./Dada2/dada2_table_filtered.qza \
  --i-phylogeny ./phylogeny/rooted-tree.qza \
  --m-metadata-file ./metadata*.txt \
  --p-sampling-depth $1 \
  --output-dir ./core-metrics-results_$1

## Enter core metrics directory for alpha diversity metric calculations
cd ./core-metrics-results_$1

## Shannon index calculated differently than in Past. Uses a log base 2 instead
## of nature log
## http://scikit-bio.org/docs/latest/generated/skbio.diversity.alpha.shannon.html#skbio.diversity.alpha.shannon
qiime diversity alpha \
  --i-table ./rarefied_table.qza \
  --p-metric 'shannon' \
  --o-alpha-diversity shannon.qza

## Chao1
qiime diversity alpha \
  --i-table ./rarefied_table.qza \
  --p-metric 'chao1' \
  --o-alpha-diversity chao1.qza

## Chao1 confidence interval
qiime diversity alpha \
  --i-table ./rarefied_table.qza \
  --p-metric 'chao1_ci' \
  --o-alpha-diversity chao1_ci.qza

## Simpson Index
qiime diversity alpha \
  --i-table ./rarefied_table.qza \
  --p-metric 'simpson' \
  --o-alpha-diversity simpson.qza

## Dominance (1 - Simpson)
qiime diversity alpha \
  --i-table ./rarefied_table.qza \
  --p-metric 'dominance' \
  --o-alpha-diversity dominance.qza

## Compiles alpha diversity metrics with metadata
qiime metadata tabulate \
  --m-input-file ../metadata*.txt \
  --m-input-file ./observed_features_vector.qza \
  --m-input-file ./chao1.qza \
  --m-input-file ./chao1_ci.qza \
  --m-input-file ./simpson.qza \
  --m-input-file ./dominance.qza \
  --m-input-file ./shannon.qza \
  --m-input-file ./evenness_vector.qza \
  --o-visualization ./alpha_diversity_metrics_$1.qzv


## Export alpha diversity metrics to TSV
qiime tools export \
  --input-path ./alpha_diversity_metrics_$1.qzv \
  --output-path ./
## Rename file
mv ./metadata.tsv ./alpha_diversities_$1.tsv

## Cleanup from exporting QZV
rm -r index.html
rm -r js
rm -r q2templateassets
rm -r css

## Exit core-metrics-results direcotry
cd ..

## Export rarefied feature table
qiime tools export \
  --input-path ./core-metrics-results_$1/rarefied_table.qza \
  --output-path ./core-metrics-results_$1/

## rename rarefied BIOM table 
mv ./core-metrics-results_$1/feature-table.biom \
   ./core-metrics-results_$1/rarefied-feature-table.biom

## Add metadata to .biom file
biom add-metadata \
  -i core-metrics-results_$1/rarefied-feature-table.biom \
  -o core-metrics-results_$1/rarefied-feature-table_taxa.biom \
  --observation-metadata-fp taxonomy/taxonomy.tsv \
  --observation-header="Feature ID,Taxon" \
  --sc-separated taxonomy

## Convert rarefied table w/ taxa to TSV
biom convert \
  -i core-metrics-results_$1/rarefied-feature-table_taxa.biom \
  -o core-metrics-results_$1/rarefied-feature-table_taxa.tsv \
  --to-tsv \
  --output-metadata-id=Taxon \
  --tsv-metadata-formatter=naive \
  --header-key=Taxon

## Generate Taxa Bar Plot
qiime taxa barplot \
  --i-table ./core-metrics-results_$1/rarefied_table.qza \
  --i-taxonomy ./taxonomy/taxonomy.qza \
  --m-metadata-file ./metadata*.txt \
  --o-visualization ./core-metrics-results_$1/taxa_barplot.qzv

echo 'Taxonomy visualized.'

cp -r ./core-metrics-results_$1 ./transfer/core-metrics-results_$1

echo "### Ending at: $(date) ###"

