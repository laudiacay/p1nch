# #!/bin/bash

# # cd circuits/build_circuits
REL_PATH=../smart-contracts/circuit_build
cd $REL_PATH
# pwd

POT_START=powersOfTau28_hez_final_18.ptau
if [ -f ./$POT_START ]; then
    echo "$POT_START already exists. Skipping."
else
    echo 'Getting powersOfTau28_hez_final_10.ptau'
    wget https://hermez.s3-eu-west-1.amazonaws.com/$POT_START
fi

cd ../../
# pwd

BUILD_PATH=smart-contracts/circuit_build

circom circuit_wrapper/circuits/build_circuits/comm_memb.circom --r1cs --wasm --sym -l "./circuit_wrapper" -o $BUILD_PATH
circom circuit_wrapper/circuits/build_circuits/p2skh_merge.circom --r1cs --wasm --sym -l "./circuit_wrapper" -o $BUILD_PATH
circom circuit_wrapper/circuits/build_circuits/p2skh_split.circom --r1cs --wasm --sym -l "./circuit_wrapper" -o $BUILD_PATH
circom circuit_wrapper/circuits/build_circuits/p2skh_well_formed.circom --r1cs --wasm --sym -l "./circuit_wrapper" -o $BUILD_PATH
circom circuit_wrapper/circuits/build_circuits/smt_processor.circom --r1cs --wasm --sym -l "./circuit_wrapper" -o $BUILD_PATH
circom circuit_wrapper/circuits/build_circuits/swap_resolve.circom --r1cs --wasm --sym -l "./circuit_wrapper" -o $BUILD_PATH
circom circuit_wrapper/circuits/build_circuits/swap_start.circom --r1cs --wasm --sym -l "./circuit_wrapper" -o $BUILD_PATH
circom circuit_wrapper/circuits/build_circuits/deactivator_well_formed.circom --r1cs --wasm --sym -l "./circuit_wrapper" -o $BUILD_PATH
circom circuit_wrapper/circuits/build_circuits/swap_event_format_verifier.circom --r1cs --wasm --sym -l "./circuit_wrapper" -o $BUILD_PATH

# # Set up the zkeys
POT_FINAL=$BUILD_PATH/pot18_final.ptau
snarkjs powersoftau prepare phase2 $BUILD_PATH/$POT_START $POT_FINAL -v
# # TODO: phase 2 cermony for trust if we are using groth 16...
snarkjs groth16 setup $BUILD_PATH/comm_memb.r1cs $POT_FINAL $BUILD_PATH/comm_memb.zkey
snarkjs groth16 setup $BUILD_PATH/p2skh_merge.r1cs $POT_FINAL $BUILD_PATH/p2skh_merge.zkey
snarkjs groth16 setup $BUILD_PATH/p2skh_split.r1cs $POT_FINAL $BUILD_PATH/p2skh_split.zkey
snarkjs groth16 setup $BUILD_PATH/p2skh_well_formed.r1cs $POT_FINAL $BUILD_PATH/p2skh_well_formed.zkey
snarkjs groth16 setup $BUILD_PATH/smt_processor.r1cs $POT_FINAL $BUILD_PATH/smt_processor.zkey
snarkjs groth16 setup $BUILD_PATH/swap_resolve.r1cs $POT_FINAL $BUILD_PATH/swap_resolve.zkey
snarkjs groth16 setup $BUILD_PATH/swap_start.r1cs $POT_FINAL $BUILD_PATH/swap_start.zkey
snarkjs groth16 setup $BUILD_PATH/deactivator_well_formed.r1cs $POT_FINAL $BUILD_PATH/deactivator_well_formed.zkey
snarkjs groth16 setup $BUILD_PATH/swap_event_format_verifier.r1cs $POT_FINAL $BUILD_PATH/swap_event_format_verifier.zkey

# # Setup the verifiation smart contracts
snarkjs zkey export solidityverifier $BUILD_PATH/comm_memb.zkey $BUILD_PATH/comm_memb_verify.sol
snarkjs zkey export solidityverifier $BUILD_PATH/p2skh_merge.zkey $BUILD_PATH/p2skh_merge_verify.sol
snarkjs zkey export solidityverifier $BUILD_PATH/p2skh_split.zkey $BUILD_PATH/p2skh_split_verify.sol
snarkjs zkey export solidityverifier $BUILD_PATH/p2skh_well_formed.zkey $BUILD_PATH/p2skh_well_formed_verify.sol
snarkjs zkey export solidityverifier $BUILD_PATH/smt_processor.zkey $BUILD_PATH/smt_processor_verify.sol
snarkjs zkey export solidityverifier $BUILD_PATH/swap_resolve.zkey  $BUILD_PATH/swap_resolve_verify.sol
snarkjs zkey export solidityverifier $BUILD_PATH/swap_start.zkey $BUILD_PATH/swap_start_verify.sol
snarkjs zkey export solidityverifier $BUILD_PATH/deactivator_well_formed.zkey $BUILD_PATH/deactivator_well_formed_verify.sol
snarkjs zkey export solidityverifier $BUILD_PATH/swap_event_format_verifier.zkey $BUILD_PATH/swap_event_format_verifier.sol

# Setup verification keys
snarkjs zkey export verificationkey $BUILD_PATH/comm_memb.zkey $BUILD_PATH/comm_memb_verification_key.json
snarkjs zkey export verificationkey $BUILD_PATH/p2skh_merge.zkey  $BUILD_PATH/p2skh_merge_verification_key.json
snarkjs zkey export verificationkey $BUILD_PATH/p2skh_split.zkey $BUILD_PATH/p2skh_splitverification_key.json
snarkjs zkey export verificationkey $BUILD_PATH/p2skh_well_formed.zkey $BUILD_PATH/p2skh_well_formed_verification_key.json
snarkjs zkey export verificationkey $BUILD_PATH/smt_processor.zkey $BUILD_PATH/smt_processor_verification_key.json
snarkjs zkey export verificationkey $BUILD_PATH/swap_resolve.zkey  $BUILD_PATH/swap_resolve_verification_key.json
snarkjs zkey export verificationkey $BUILD_PATH/swap_start.zkey  $BUILD_PATH/swap_start_verification_key.json
snarkjs zkey export verificationkey $BUILD_PATH/deactivator_well_formed.zkey  $BUILD_PATH/deactivator_well_formed_verification_key.json
snarkjs zkey export verificationkey $BUILD_PATH/swap_event_format_verifier.zkey  $BUILD_PATH/swap_event_format_verification_key.json


# Copy over build files from smart-contracts/circuit_build to the typescript folder while only including relevant files
rsync -r ../smart-contracts/circuit_build/* --exclude="*.sol" --exclude="*.r1cs" --exclude="*.sym" --exclude="*.ptau" packages/assets/src