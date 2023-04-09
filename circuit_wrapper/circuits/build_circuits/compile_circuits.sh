#!/bin/bash

cd circuits/build_circuits

if [ -f ./powersOfTau28_hez_final_10.ptau ]; then
    echo "powersOfTau28_hez_final_10.ptau already exists. Skipping."
else
    echo 'Getting powersOfTau28_hez_final_10.ptau'
    wget https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_10.ptau
fi

cd ../../
circom circuits/build_circuits/comm_memb.circom --r1cs --wasm --sym -l "." -o build
circom circuits/build_circuits/p2skh_merge.circom --r1cs --wasm --sym -l "." -o build
circom circuits/build_circuits/p2skh_split.circom --r1cs --wasm --sym -l "." -o build
circom circuits/build_circuits/p2skh_well_formed.circom --r1cs --wasm --sym -l "." -o build
circom circuits/build_circuits/smt_processor.circom --r1cs --wasm --sym -l "." -o build
circom circuits/build_circuits/swap_resolve.circom --r1cs --wasm --sym -l "." -o build
circom circuits/build_circuits/swap_start.circom --r1cs --wasm --sym -l "." -o build

