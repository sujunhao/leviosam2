# gen_genomic_annotations.sh
# 
# Generate genomic annotations for the levioSAM2 pipeline
#
# Author: Nae-Chyun Chen
#
# Distributed under the MIT license
# https://github.com/milkschen/leviosam2
#

### BEGIN_EDIT -- Please edit the following fields for customized source/target references
# Please install the following software before running this pipeline
# python, samtools, bedtools, liftOver, winnowmap, genmap2
#

CHAIN="source_to_target.chain"
DIR_LEVIOSAM="/path/to/leviosam2/"
UCSC_LIFTOVER="liftOver"

SOURCE_REF="/path/to/source.fa"
TARGET_REF="/path/to/target.fa"
SOURCE_LABEL="source"
TARGET_LABEL="target"
PFX="${SOURCE_LABEL}-${TARGET_LABEL}"

K="100"
E="0.01"
L="0.98"

# Calculate mappability annotations
# genmap2 has not been released
# genmap2 -k ${K} -e ${E} -s 10 -bg ${SOURCE_REF}
# genmap2 -k ${K} -e ${E} -s 10 -bg ${TARGET_REF}
SOURCE_BG="/path/to/source_${K}_${E}_10_1.0.bedgraph"
TARGET_BG="/path/to/target_${K}_${E}_10_1.0.bedgraph"

MIN_SEG_SIZE="5000"

### END_EDIT

SOURCE_HIGHMAP="${SOURCE_LABEL}-k${K}_e${E}-high.bed"
# SOURCE_LOWMAP="${SOURCE_LABEL}-k${K}_e${E}-low.bed"
SOURCE_TO_TARGET_HIGHMAP="${SOURCE_LABEL}_to_${TARGET_LABEL}-k${K}_e${E}-high.bed"
TARGET_HIGHMAP="${TARGET_LABEL}-k${K}_e${E}-high.bed"
TARGET_LOWMAP="${TARGET_LABEL}-k${K}_e${E}-low.bed"

##############################################
#### Generate low-mappability annotations ####
##############################################

set -xp 

# Get low-identity chain segments
if [ ! -s ${PFX}.summary ]; then
    python ${DIR_LEVIOSAM}/scripts/verbosify_chain.py -c ${CHAIN} -o ${PFX}.verbose.chain \
        -b ${PFX} -s ${PFX}.summary -f1 ${SOURCE_REF} -f2 ${TARGET_REF}
fi
if [ ! -s ${PFX}-identity_lt${L}-${TARGET_LABEL}.bed ]; then
    python ${DIR_LEVIOSAM}/scripts/get_low_identity_regions.py -s ${PFX}.summary \
        -l ${L} -o ${PFX}-identity_lt${L}-${TARGET_LABEL}.bed
fi

if [ ! -s ${SOURCE_HIGHMAP} ]; then
    python ${DIR_LEVIOSAM}/scripts/get_mappable_regions.py -b ${SOURCE_BG} -k ${K} -o ${SOURCE_HIGHMAP}
fi
if [ ! -s ${SOURCE_TO_TARGET_HIGHMAP} ]; then
    ${UCSC_LIFTOVER} ${SOURCE_HIGHMAP} ${CHAIN} ${SOURCE_TO_TARGET_HIGHMAP} ${SOURCE_TO_TARGET_HIGHMAP}.unmapped
fi

if [ ! -s ${TARGET_HIGHMAP} ]; then
    python ${DIR_LEVIOSAM}/scripts/get_mappable_regions.py -b ${TARGET_BG} -k ${K} -o ${TARGET_HIGHMAP}
fi

if [ ! -s ${TARGET_REF}.fai ]; then
    samtools faidx ${TARGET_REF}
fi
if [ ! -s ${TARGET_LOWMAP} ]; then
    python ${DIR_LEVIOSAM}/scripts/fai_to_bed.py -f ${TARGET_REF}.fai -o ${TARGET_REF}.fai.bed
    bedtools subtract -a ${TARGET_REF}.fai.bed -b ${TARGET_HIGHMAP} > ${TARGET_LOWMAP}
fi

# Low-mappability in TARGET; high-mappability in SOURCE
# This is wrt the TARGET coordinates
if [ ! -s k${K}_e${E}-${SOURCE_LABEL}_highmap-${TARGET_LABEL}_lowmap-${TARGET_LABEL}.bed ]; then
    bedtools intersect -a ${SOURCE_TO_TARGET_HIGHMAP} -b ${TARGET_LOWMAP} > k${K}_e${E}-${SOURCE_LABEL}_highmap-${TARGET_LABEL}_lowmap-${TARGET_LABEL}.bed
fi


# Merge low-identity and mappability-reduced BED files
cat ${PFX}-identity_lt${L}-${TARGET_LABEL}.bed k${K}_e${E}-${SOURCE_LABEL}_highmap-${TARGET_LABEL}_lowmap-${TARGET_LABEL}.bed |\
    bedtools intersect -a stdin -b ${TARGET_REF}.fai.bed |\
    bedtools sort -i stdin |\
    bedtools merge -i stdin > ${SOURCE_LABEL}-${TARGET_LABEL}-lt${L}-map_reduction_k${K}_e${E}.bed


##########################################
#### Generate un-liftable annotations ####
##########################################

python ${DIR_LEVIOSAM}/scripts/fai_to_bed.py -f ${SOURCE_REF}.fai -o ${SOURCE_LABEL}.bed
bedtools sort -i ${PFX}-source.bed | \
    bedtools merge -i stdin | \
    bedtools subtract -a ${SOURCE_LABEL}.bed -b stdin > ${PFX}-source-unliftable.bed
python ${DIR_LEVIOSAM}/scripts/filter_bed_by_size.py -b ${PFX}-source-unliftable.bed \
    -o ${PFX}-source-unliftable-s_${MIN_SEG_SIZE}.bed -s ${MIN_SEG_SIZE}

python ${DIR_LEVIOSAM}/scripts/extract_seq_from_bed.py -f ${SOURCE_REF} \
    -b ${PFX}-source-unliftable-s_${MIN_SEG_SIZE}.bed \
    -o ${PFX}-source-unliftable-s_${MIN_SEG_SIZE}.fasta
winnowmap -t $(nproc) -ak 19 ${TARGET_REF} \
    ${PFX}-source-unliftable-s_${MIN_SEG_SIZE}.fasta > \
    ${PFX}-source-unliftable-s_${MIN_SEG_SIZE}-winnowmap2.sam

python ${DIR_LEVIOSAM}/scripts/sam_qname_to_bed.py -s ${PFX}-source-unliftable-s_${MIN_SEG_SIZE}-winnowmap2.sam \
    -m 1-1 -o ${PFX}-source-unliftable-s_${MIN_SEG_SIZE}-winnowmap2-exc_1.bed
