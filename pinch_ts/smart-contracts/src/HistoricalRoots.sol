// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract HistoricalRoots is AccessControl {
    uint256 constant MAX_SIZE = 100;
    uint256 currentSize;
    uint256 startIndex;

    uint256[MAX_SIZE] elements;
    mapping(uint256 => bool) isMember;

    uint256 newest;

    bytes32 public constant STATE_ADMIN_ROLE = keccak256("STATE_ADMIN_ROLE");

    // TODO what do you do about newest being nonzero?
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(STATE_ADMIN_ROLE, msg.sender);
        currentSize = 0;
        startIndex = 0;
        newest = 0;
    }

    function setRoot(uint256 element) public onlyRole(STATE_ADMIN_ROLE) {
        require(!isMember[element], "Element is already in the collection");

        // If the collection is at capacity, evict the oldest member
        if (currentSize == MAX_SIZE) {
            uint256 oldest = elements[startIndex];
            delete isMember[oldest];
            startIndex = (startIndex + 1) % MAX_SIZE;
        } else {
            currentSize++;
        }

        // Add the new element
        elements[(startIndex + currentSize - 1) % MAX_SIZE] = element;
        isMember[element] = true;
        newest = element;
    }

    function checkMembership(uint256 element) public view returns (bool) {
        return isMember[element];
    }

    function getCurrent() public view returns (uint256) {
        return newest;
    }
}
