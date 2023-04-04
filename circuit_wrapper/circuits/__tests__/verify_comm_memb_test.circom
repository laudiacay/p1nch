pragma circom 2.1.0;

include "circuits/verify_comm_membership.circom";

component main {
	public [
		deposit_comm,
		root
	]
} = VerifyCommMembership(10);