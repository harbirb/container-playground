#!/bin/bash

DOCKERFILE="dockerfile.optimizedmusl"

docker build -f ./$DOCKERFILE . -t samtools-final

# dummy input SAM file (must use tab characters)
printf "@HD\tVN:1.6\tSO:coordinate\n" > input.sam

# run the container, mount current dir, run samtools view -b input.sam, write to output.bam
docker run --rm -v "$PWD":/data -w /data samtools-final samtools view -b input.sam > output.bam

# docker run --rm -v "$PWD":/data -w /data samtools-final cat input.sam

if [ -f output.bam ]; then
    echo "SUCCESS: BAM file created!"
else
    echo "FAILURE: No output file."
    exit 1
fi