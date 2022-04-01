[![Docker](https://img.shields.io/docker/v/naechyun/leviosam2?label=Docker)](https://hub.docker.com/r/naechyun/leviosam2)
[![Anaconda-Server Badge](https://anaconda.org/bioconda/leviosam2/badges/version.svg)](https://anaconda.org/bioconda/leviosam2)
[![Anaconda-Server Badge](https://anaconda.org/bioconda/leviosam2/badges/downloads.svg)](https://anaconda.org/bioconda/leviosam2)

# levioSAM2: Fast and accurate coordinate conversion between assemblies

LevioSAM2 lifts over alignments accurately and efficiently using a chain file.

## Features

- Converting aligned short and long reads records (in SAM/BAM format) from one reference to another
- The following alignment features are updated during coversion:
    - Reference name (`RNAME`), position (`POS`), alignmant flag (`FLAG`), and CIGAR alignment string (`CIGAR`)
    - Mate read information (`RNEXT`, `PNEXT`, `TLEN`)
    - (optional) Alignment tags (`MD:Z`, `NM:i`)
- Multithreading support
- Toolkit for "selective" pipelines which consider major changes between the source and target references
- (beta) Converting intervals (in BED format) from one reference to another

## Installation

LevioSAM2 can be installed using:

- [Conda](https://docs.conda.io/en/latest/)

```
conda install -c conda-forge -c bioconda leviosam2
```

- [Docker](https://hub.docker.com/r/milkschen/leviosam2)
```
docker pull naechyun/leviosam2:latest
```

- [Singularity](https://hub.docker.com/r/milkschen/leviosam2)
```
singularity pull docker://naechyun/leviosam2:latest
```

- Built from source using CMake. See [INSTALL.md](INSTALL.md) for details.


## Usage

### Prepare chain files

LevioSAM2 performs lift-over using a [chain file](http://hgw1.soe.ucsc.edu/goldenPath/help/chain.html) as the lift-over map.
Many chain files are provided by the UCSC Genome Browser, e.g. [GRCh38-related chains](https://hgdownload.soe.ucsc.edu/goldenPath/hg38/liftOver/).
For other reference pairs, common ways to generate chain files include using the [UCSC recipe](http://genomewiki.ucsc.edu/index.php/LiftOver_Howto) and [nf-LO](https://github.com/evotools/nf-LO).

### LevioSAM2-index

LevioSAM2 indexes a chain file for lift-over queries. The resulting index has a `.clft` extension.

```
leviosam2 index -c source_to_target.chain -p source_to_target -F target.fai
```

### LevioSAM2-lift

`LevioSAM2-lift` is the lift-over kernel of the levioSAM2 toolkit. 
The levioSAM2 ChainMap index will be saved to `source_to_target.clft`. The output will be saved to `lifted_from_source.bam`.

__We highly recommend to sort the input BAM by position prior to running levioSAM2-lift.__

```
leviosam2 lift -C source_to_target.clft -a aligned_to_source.bam -p lifted_from_source -O bam
```


### Full levioSAM2 pipeline with selective re-mapping

The levioSAM2 pipeline includes lift-over using the `leviosam2-lift` kernel and a selective re-mapping strategy. This approach can improve accuracy.

Example:
```
# You may skip the indexing step if you've already run it
leviosam2 index -c source_to_target.chain -p source_to_target -F target.fai
sh leviosam2.sh \
    -a bowtie2 -A -10 -q 10 -H 5 \
    -i aligned_to_source.bam \
    -o aligned_to_source-lifted \
    -f target.fna \
    -b bt2/target \
    -C source_to_target.clft \
    -t 16
```

See [this README](https://github.com/milkschen/leviosam2/blob/main/pipeline/README.md) to learn more about running the full levioSAM2
pipeline.


## Publication

- Preprint for levioSAM2 will come soon
- Taher Mun, Nae-Chyun Chen, Ben Langmead, LevioSAM: Fast lift-over of variant-aware reference alignments, _Bioinformatics_, 2021;, btab396, https://doi.org/10.1093/bioinformatics/btab396

_Last update: 3/30/2022_
