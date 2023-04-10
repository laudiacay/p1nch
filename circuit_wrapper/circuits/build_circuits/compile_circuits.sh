#!/bin/bash

cd circuits/build_circuits

POT_START=powersOfTau28_hez_final_18.ptau
if [ -f ./$POT_START ]; then
    echo "$POT_START already exists. Skipping."
else
    echo 'Getting powersOfTau28_hez_final_10.ptau'
    wget https://hermez.s3-eu-west-1.amazonaws.com/$POT_START
fi

cd ../../
circom circuits/build_circuits/comm_memb.circom --r1cs --wasm --sym -l "." -o build
circom circuits/build_circuits/p2skh_merge.circom --r1cs --wasm --sym -l "." -o build
circom circuits/build_circuits/p2skh_split.circom --r1cs --wasm --sym -l "." -o build
circom circuits/build_circuits/p2skh_well_formed.circom --r1cs --wasm --sym -l "." -o build
circom circuits/build_circuits/smt_processor.circom --r1cs --wasm --sym -l "." -o build
circom circuits/build_circuits/swap_resolve.circom --r1cs --wasm --sym -l "." -o build
circom circuits/build_circuits/swap_start.circom --r1cs --wasm --sym -l "." -o build

# Set up the zkeys
POT_FINAL=build/pot18_final.ptau
snarkjs powersoftau prepare phase2 circuits/build_circuits/$POT_START $POT_FINAL -v
# TODO: phase 2 cermony for trust if we are using groth 16...
snarkjs groth16 setup ../smart-contract/circuit_build/comm_memb.r1cs $POT_FINAL ../smart-contract/circuit_build/comm_memb.zkey
snarkjs groth16 setup ../smart-contract/circuit_build/p2skh_merge.r1cs $POT_FINAL ../smart-contract/circuit_build/p2skh_merge.zkey
snarkjs groth16 setup ../smart-contract/circuit_build/p2skh_split.r1cs $POT_FINAL ../smart-contract/circuit_build/p2skh_split.zkey
snarkjs groth16 setup ../smart-contract/circuit_build/p2skh_well_formed.r1cs $POT_FINAL ../smart-contract/circuit_build/p2skh_well_formed.zkey
snarkjs groth16 setup ../smart-contract/circuit_build/smt_processor.r1cs $POT_FINAL ../smart-contract/circuit_build/smt_processor.zkey
snarkjs groth16 setup ../smart-contract/circuit_build/swap_resolve.r1cs $POT_FINAL ../smart-contract/circuit_build/swap_resolve.zkey
snarkjs groth16 setup ../smart-contract/circuit_build/swap_start.r1cs $POT_FINAL ../smart-contract/circuit_build/swap_start.zkey

# Setup the verifiation smart contracts
snarkjs zkey export solidityverifier ../smart-contract/circuit_build/comm_memb.zkey build/comm_memb_verify.sol
snarkjs zkey export solidityverifier ../smart-contract/circuit_build/p2skh_merge.zkey build/p2skh_merge_verify.sol
snarkjs zkey export solidityverifier ../smart-contract/circuit_build/p2skh_split.zkey build/p2skh_split_verify.sol
snarkjs zkey export solidityverifier ../smart-contract/circuit_build/p2skh_well_formed.zkey build/p2skh_well_formed_verify.sol
snarkjs zkey export solidityverifier ../smart-contract/circuit_build/smt_processor.zkey build/smt_processor_verify.sol
snarkjs zkey export solidityverifier ../smart-contract/circuit_build/swap_resolve.zkey build/swap_resolve_verify.sol
snarkjs zkey export solidityverifier ../smart-contract/circuit_build/swap_start.zkey build/swap_start_verify.sol

# https://docs.circom.io/getting-started/proving-circuits/#phase-2
# https://docs.circom.io/getting-started/proving-circuits/#powers-of-tau
