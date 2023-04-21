// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import {SwapProofVerifier} from "./SwapProofVerifier.sol";
import {PinchSwapProxy} from "./PinchSwapProxy.sol";
import {HistoricalRoots} from "../HistoricalRoots.sol";

// TODO handle if the swap (or other operation) fails!
contract Swapper is AccessControl, PinchSwapProxy {
    bytes32 public constant STATE_ADMIN_ROLE = keccak256("STATE_ADMIN_ROLE");
    bytes32 public constant BOT_ROLE = keccak256("BOT_ROLE");

    // always sorted
    struct Pair {
        address token_src;
        address token_dest;
    }

    struct PairTokenAmount {
        uint256 token_src_amount_in;
        uint256 token_dest_amount_out;
    }

    // batch swap update proof
    struct Proof {
        uint256[2] pi_a;
        uint256[2][2] pi_b;
        uint256[2] pi_c;
    }

    // this contains the swap batch info. it is an SMT that contains:
    // (batch_num, token_src, token_dest, token_src_amount_in) => 0
    // users can look up the price of a token in a given batch and present it to the contract
    // the contract will verify the proof that the given swap UTXO *was* executed in that batch_num (per its timestamp)
    // and that the given token was swapped in that batch_num at that swap price
    HistoricalRoots batch_swap_root;

    // this is a list that registers when batches are swapped
    uint256[] batch_swap_timestamps;

    // this is the current batch number
    uint256 current_batch_number;

    SwapData current;
    SwapData last_and_needs_entry_to_root;

    struct SwapData {
        uint256 batchNumber;
        // a mapping that says how much of each vault should be net swapped into another token in this batch.
        // get the first half of the mapping from pairHash.
        // first entry in output is amount that goes from A to B, second entry is B to A. need to track separately because exchange rate is yet unknown.
        mapping(uint256 => PairTokenAmount) swap_amounts;
        // list of pairs in the current batch :)
        Pair[] swap_tokens;
        // prices... price of one tokenA in tokenB denomination
        // empty until swap happens.
        // get the first half of the mapping from pairHash
        mapping(uint256 => PairTokenAmount) prices;
    }

    // TODO i hereby invite you to put some thought into making the bot permissionless
    constructor(
        address governance_owner,
        address bot,
        address swap_router
    ) PinchSwapProxy(swap_router) {
        // TODO check this
        _grantRole(DEFAULT_ADMIN_ROLE, governance_owner);
        _grantRole(STATE_ADMIN_ROLE, msg.sender);
        _grantRole(BOT_ROLE, bot);
        current.batchNumber = 0;
        current_batch_number = 0;
        batch_swap_root = new HistoricalRoots();
    }

    function emptySwapData(SwapData storage data) internal {
        for (uint256 i = 0; i < data.swap_tokens.length; i++) {
            uint256 pairId = pairHash(data.swap_tokens[i]);
            delete data.swap_amounts[pairId];
            delete data.prices[pairId];
        }
        delete data.swap_tokens;
    }

    function swapDataIsEmpty(
        SwapData storage data
    ) internal view returns (bool) {
        return data.swap_tokens.length == 0;
    }

    function checkHistoricalRoot(uint256 swap_root) public view returns (bool) {
        return batch_swap_root.checkMembership(swap_root);
    }

    // TODO should be onlyOwner?? idk?- idk.
    function copyCurrentToLastAndClearCurrent() internal {
        require(
            swapDataIsEmpty(last_and_needs_entry_to_root),
            "last_and_needs_entry_to_root is not empty"
        );

        // Copy current to last_and_needs_entry_to_root
        last_and_needs_entry_to_root.swap_tokens = current.swap_tokens;
        for (uint256 i = 0; i < current.swap_tokens.length; i++) {
            uint256 pairId = pairHash(current.swap_tokens[i]);
            last_and_needs_entry_to_root.swap_amounts[pairId] = current
                .swap_amounts[pairId];
            last_and_needs_entry_to_root.prices[pairId] = current.prices[
                pairId
            ];
        }

        emptySwapData(current);
    }

    // pure function that just returns the current batch number
    function getBatchNumber() public view returns (uint256) {
        return current_batch_number;
    }

    function addTransaction(
        address from,
        address to,
        uint256 amount
    ) public onlyRole(STATE_ADMIN_ROLE) {
        uint256 pairid = pairHash(Pair({token_src: from, token_dest: to}));
        current.swap_amounts[pairid].token_src_amount_in += amount;
    }

    function pairHash(Pair memory pair) internal pure returns (uint256) {
        return
            uint256(
                keccak256(abi.encodePacked(pair.token_src, pair.token_dest))
            );
    }

    function doSwap() public onlyRole(BOT_ROLE) {
        // TODO add blocking logic if you haven't checked into the root yet
        require(
            swapDataIsEmpty(last_and_needs_entry_to_root),
            "last_and_needs_entry_to_root is not empty, you need to call updateRoot to get the last root into the SMT before you perform a swap batch."
        );
        // setup for the next batch!
        copyCurrentToLastAndClearCurrent();
        current_batch_number += 1;
        current.batchNumber = current_batch_number;
        batch_swap_timestamps.push(block.timestamp);

        // Perform swaps for last_and_needs_entry_to_root
        uint256 num_swaps = last_and_needs_entry_to_root.swap_tokens.length;
        for (uint256 i = 0; i < num_swaps; i++) {
            Pair memory pair = last_and_needs_entry_to_root.swap_tokens[i];
            uint256 pairid = pairHash(pair);

            // TODO: one day, you should do an internal matching step to make sure that you're satisfying demand first from within your own pools.
            // but not yet.
            PairTokenAmount memory swap_amounts = last_and_needs_entry_to_root
                .swap_amounts[pairid];

            // Perform the swap with ERC20 tokens owned by the contract
            // TODO: SAFE TRANSFER FROM EVERYWHERE!!!!!!
            // IERC20(pair.token_src).transferFrom(address(this), address(this), swap_amounts.token_src_amount_in);
            uint256 amount_out = super.swap(
                PinchSwapProxy.SwapDescription({
                    srcToken: pair.token_src,
                    dstToken: pair.token_dest,
                    amount: swap_amounts.token_src_amount_in,
                    minReturnAmount: 0, // TODO: min return amounts, see Trello
                    priceLimit: 0 // TODO: min return amount, see Trello
                })
            );

            current.swap_amounts[pairid].token_dest_amount_out += amount_out;
        }
    }

    // todo this is a rough one
    function updateRoot(
        SwapProofVerifier.Proof[] calldata updateProofs,
        SwapProofVerifier.Proof[] calldata swapWellFormedProofs,
        uint256[] calldata newRoots,
        uint256[] calldata swap_event_hashes
    ) public onlyRole(BOT_ROLE) {
        require(
            !swapDataIsEmpty(last_and_needs_entry_to_root),
            "last_and_needs_entry_to_root is empty, you need to call doSwap to get the last batch into the SMT before you update the root."
        );

        // check lengths of proofs and newRoots
        require(
            updateProofs.length ==
                last_and_needs_entry_to_root.swap_tokens.length &&
                newRoots.length ==
                last_and_needs_entry_to_root.swap_tokens.length &&
                swap_event_hashes.length == newRoots.length &&
                swapWellFormedProofs.length == newRoots.length,
            "updateProofs and newRoots must be the same length as num of swap pairs"
        );
        uint256 lastRoot = 0;

        // iterate over pairs
        for (
            uint256 i = 0;
            i < last_and_needs_entry_to_root.swap_tokens.length;
            i++
        ) {
            Pair memory pair = last_and_needs_entry_to_root.swap_tokens[i];
            uint256 pairid = pairHash(pair);
            PairTokenAmount memory prices = last_and_needs_entry_to_root.prices[
                pairid
            ];
            // validate that it's a valid update proof
            lastRoot = i == 0 ? batch_swap_root.getCurrent() : newRoots[i];
            require(
                SwapProofVerifier.updateProof(
                    updateProofs[i],
                    swapWellFormedProofs[i],
                    swap_event_hashes[i],
                    lastRoot,
                    newRoots[i],
                    last_and_needs_entry_to_root.batchNumber,
                    pair.token_src,
                    pair.token_dest,
                    prices.token_src_amount_in,
                    prices.token_dest_amount_out
                ),
                "you did not update the prices right :(, check your proofs"
            );

            lastRoot = newRoots[i];
        }

        emptySwapData(last_and_needs_entry_to_root);
        batch_swap_root.setRoot(newRoots[newRoots.length - 1]);
    }
}
