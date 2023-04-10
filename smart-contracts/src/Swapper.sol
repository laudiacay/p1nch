// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/access/AccessControl.sol";

import "./BatchPriceSMTVerifier.sol";
import "./HistoricalRoots.sol";

// TODO handle if the swap (or other operation) fails!
contract Swapper is AccessControl {
    bytes32 public constant STATE_ADMIN_ROLE = keccak256("STATE_ADMIN_ROLE");
    bytes32 public constant BOT_ROLE = keccak256("BOT_ROLE");

    // always sorted.
    struct Pair {
        address token1;
        address token2;
    }

    // batch swap update proof
    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    // this contains the swap batch info. it is an SMT that contains:
    // (timestamp_of_prior_batch, timestamp_of_current_batch, token1, token2, token1_price_in_token2) => 0
    // why does it contain timestamp_of_prior_batch? make sure that timestamp of swap ticket was actually inside the bounds
    // why does it contain timestamp_of_current_batch? same reason.
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
        // negative means you're getting more of first token
        // positive means you're getting more of second token
        // get the first half of the mapping from pairHash
        mapping(uint256 => int256) swap_amounts;
        // list of pairs in the current batch :)
        Pair[] swap_tokens;
        // prices... price of one tokenA in tokenB denomination
        // empty until swap happens.
        // get the first half of the mapping from pairHash
        mapping(uint256 => uint256) prices;
    }

    // TODO i hereby invite you to put some thought into making the bot permissionless
    constructor(address governance_owner, address bot) {
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

    function swapDataIsEmpty(SwapData storage data) internal view returns (bool) {
        return data.swap_tokens.length == 0;
    }

    function checkHistoricalRoot(uint256 swap_root) public view returns (bool) {
        return batch_swap_root.checkMembership(swap_root);
    }

    // TODO should be onlyOwner?? idk?- idk.
    function copyCurrentToLastAndClearCurrent() internal {
        require(swapDataIsEmpty(last_and_needs_entry_to_root), "last_and_needs_entry_to_root is not empty");

        // Copy current to last_and_needs_entry_to_root
        last_and_needs_entry_to_root.swap_tokens = current.swap_tokens;
        for (uint256 i = 0; i < current.swap_tokens.length; i++) {
            uint256 pairId = pairHash(current.swap_tokens[i]);
            last_and_needs_entry_to_root.swap_amounts[pairId] = current.swap_amounts[pairId];
            last_and_needs_entry_to_root.prices[pairId] = current.prices[pairId];
        }

        emptySwapData(current);
    }

    // pure function that just returns the current batch number
    function getBatchNumber() public view returns (uint256) {
        return current_batch_number;
    }

    function addTransaction(address from, address to, uint128 amount) public onlyRole(STATE_ADMIN_ROLE) {
        address token_a = from >= to ? from : to;
        address token_b = from < to ? from : to;

        uint256 pairid = pairHash(Pair({token1: token_a, token2: token_b}));

        if (token_a == from) {
            current.swap_amounts[pairid] += int256(uint256(amount));
        } else {
            current.swap_amounts[pairid] -= int256(uint256(amount)); // TODO BUG WRONG!!!!
        }
    }

    function pairHash(Pair memory pair) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(pair.token1, pair.token2)));
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
            // TODO hmm "pair storage pair"? optimize me
            Pair storage pair = last_and_needs_entry_to_root.swap_tokens[i];
            uint256 pairid = pairHash(pair);
            int256 swap_amount = last_and_needs_entry_to_root.swap_amounts[pairid];

            // Perform the swap with ERC20 tokens owned by the contract
            if (swap_amount > 0) {
                // Swap tokenA for tokenB
                uint256 amount_token1 = uint256(swap_amount);

                // TODO Add your swapping logic here, e.g., using a DEX or an aggregator
                IERC20(pair.token1).transferFrom(address(this), address(this), amount_token1);

                // TODO make this 1 into the right price
                last_and_needs_entry_to_root.prices[pairid] = 1;
            } else if (swap_amount < 0) {
                // Swap tokenB for tokenA
                // TODO this is a bug you cannot know the negative swap amount can you??? seems bad. seems pretty wrong to me. fix me
                uint256 amount_token2 = uint256(-swap_amount);

                // TODO Add your swapping logic here, e.g., using a DEX or an aggregator
                IERC20(pair.token2).transferFrom(address(this), address(this), amount_token2);

                // TODO make this 1 into the right price
                last_and_needs_entry_to_root.prices[pairid] = 1;
            }
            // TODO what happens if you had zero that needs to swap? do you need a price on that? what's that mean?
        }
    }

    // todo this is arough one
    function updateRoot(BatchPriceSMTVerifier.Proof[] calldata updateProofs, uint256[] calldata newRoots)
        public
        onlyRole(BOT_ROLE)
    {
        require(
            !swapDataIsEmpty(last_and_needs_entry_to_root),
            "last_and_needs_entry_to_root is empty, you need to call doSwap to get the last batch into the SMT before you update the root."
        );

        // check lengths of proofs and newRoots
        require(
            updateProofs.length == last_and_needs_entry_to_root.swap_tokens.length
                && newRoots.length == last_and_needs_entry_to_root.swap_tokens.length,
            "updateProofs and newRoots must be the same length as num of swap pairs"
        );
        // get the last and current batch timestamps (last two entries in the batch_swap_timestamps array)
        uint256 lastBatchTimestamp = batch_swap_timestamps[batch_swap_timestamps.length - 2];
        uint256 currentBatchTimestamp = batch_swap_timestamps[batch_swap_timestamps.length - 1];

        // iterate over pairs
        for (uint256 i = 0; i < last_and_needs_entry_to_root.swap_tokens.length; i++) {
            Pair storage pair = last_and_needs_entry_to_root.swap_tokens[i];
            uint256 pairid = pairHash(pair);
            uint256 price = last_and_needs_entry_to_root.prices[pairid];
            // validate that it's a valid proof
            uint256 lastRoot = i == 0 ? batch_swap_root.getCurrent() : newRoots[i - 1];
            require(
                BatchPriceSMTVerifier.updateProof(updateProofs[i], lastRoot, newRoots[i], last_and_needs_entry_to_root.batchNumber, pair.token1, pair.token2, price),
                "you did not update the prices right :(, check your proofs"
            );
        }

        emptySwapData(last_and_needs_entry_to_root);
        batch_swap_root.setRoot(newRoots[newRoots.length - 1]);
    }
}
