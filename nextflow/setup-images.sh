mkdir -p singularity-images
singularity pull --name singularity-images/bcftools.sif docker://quay.io/biocontainers/bcftools:1.13--h3a49de5_0
singularity pull --name singularity-images/vep.sif docker://ensemblorg/ensembl-vep
