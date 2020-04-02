#!/bin/bash
trap ctrl_c INT

function ctrl_c() {
        echo "Requested to stop."
        exit 1
}

PREFIX="local"

while getopts ":2cfgp:" opt; do
case $opt in
2) OPT_SECOND_STAGE_ONLY="OPT_SECOND_STAGE_ONLY"
;; 
p) PREFIX="$OPTARG"
;; 
c) OPT_CPU="cpu"
;;
g) OPT_GPU="gpu"
;;
f) OPT_NOCACHE="--no-cache"
;;
\?) echo "Invalid option -$OPTARG" >&2
exit 1
;;
esac
done

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

ARCH=$(echo "$OPT_CPU $OPT_GPU")
echo "Preparing docker images for [$ARCH]"

## Second stage
if [[ -z "$OPT_SECOND_STAGE_ONLY" ]]; then

    cd $DIR/sagemaker-tensorflow-container/
    python setup.py sdist
    cp dist/*.tar.gz docker/build_artifacts/
    git apply $DIR/lib/dockerfile-1.11.patch
    cd docker/build_artifacts

    for arch in $ARCH; do
        docker build $OPT_NOCACHE . -t $PREFIX/sagemaker-tensorflow-container:$arch -f ../1.11.0/Dockerfile.$arch  --build-arg py_version=3 --build-arg framework_support_installable='sagemaker_tensorflow_*.tar.gz' 
    done
    rm *.tar.gz

    cd $DIR/sagemaker-tensorflow-container/
    git apply --reverse ../lib/dockerfile-1.11.patch

fi

## Second stage
cd $DIR
rm -rf $DIR/staging
mkdir -p $DIR/staging 

# cp -r robomaker-container/bundle/sagemaker_rl_agent/lib/python3.5/site-packages/markov staging/

for arch in $ARCH;
do
    docker build $OPT_NOCACHE -t $PREFIX/deepracer-sagemaker:$arch . --build-arg arch=$arch --build-arg prefix=$PREFIX
done
