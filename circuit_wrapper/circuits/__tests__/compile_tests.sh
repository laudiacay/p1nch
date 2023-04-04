#!/bin/bash

cd circuits/__tests__

if [ -f ./powersOfTau28_hez_final_10.ptau ]; then
    echo "powersOfTau28_hez_final_10.ptau already exists. Skipping."
else
    echo 'Getting powersOfTau28_hez_final_10.ptau'
    wget https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_10.ptau
fi

cd ../../
circom circuits/__tests__/deposit_well_formed_test.circom --r1cs --wasm --sym -l "."
circom circuits/__tests__/smt_insert_test.circom --r1cs --wasm --sym -l "."


# circom <Path> --r1cs --wasm --sym
