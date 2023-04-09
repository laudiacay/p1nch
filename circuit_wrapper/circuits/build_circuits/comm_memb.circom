pragma circom 2.1.0;

include "circuits/smt_processor.circom";

component main {
	public [
		comm,
		root
	]
} = VerifyCommMembership(10);