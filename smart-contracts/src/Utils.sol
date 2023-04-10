pragma solidity ^0.8.13;

// a contract that verifies whether a ticket is well-formed
library Utils {
	function split_addr(address a) pure internal returns(uint256, uint256) {
		uint256 addr_uint = uint256(uint160(a));
		uint256 upper = addr_uint >> 128;
		uint256 lower = addr_uint % (2 ** 128);
	}
}
 