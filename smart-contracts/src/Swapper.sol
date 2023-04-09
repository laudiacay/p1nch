// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";



contract Swapper {
    // always sorted.
    struct Pair {
        address token1;
        address token2;
    }

    // this contains the swap batch info. it is an SMT that contains:
    // (timestamp_of_prior_batch, timestamp_of_current_batch, batch_num, token1, token2, token1_price_in_token2) => 0
    // why does it contain timestamp_of_prior_batch? make sure that timestamp of swap ticket was actually inside the bounds
    // why does it contain timestamp_of_current_batch? same reason.
    // users can look up the price of a token in a given batch and present it to the contract
    // the contract will verify the proof that the given swap UTXO *was* executed in that batch_num (per its timestamp)
    // and that the given token was swapped in that batch_num at that swap price
    uint256 batch_swap_root;

    // this is a list that registers when batches are swapped- any swap UTXO timestamp in between these is in the latter batch
    uint256[] batch_swap_timestamps;

    SwapData public current;
    SwapData public last_and_needs_entry_to_root;

    struct SwapData {
        // a mapping that says how much of each vault should be net swapped into another token in this batch.
        // negative means you're getting more of first token
        // positive means you're getting more of second token
        mapping(Pair => int256) swap_amounts;
        // list of pairs in the current batch :)
        Pair[] swap_tokens;
        // prices... price of one tokenA in tokenB denomination
        // empty until swap happens.
        mapping(Pair => uint256) prices;
    }

    // TODO should be onlyOwner
    function addTransaction(address from, address to, uint128 amount) public {
        address token_a = max(from, to);
        address token_b = min(from, to);

        if (token_a == from) {
            current.swap_amounts[token_a][token_b] += amount;
        } else {
            current.swap_amounts[token_a][token_b] -= amount;
        }
    }

    function doSwap() public {
        last_and_needs_entry_to_root = current;
        current = SwapData({
            swap_tokens: new Pair[](0)
        });

        // Perform swaps for last_and_needs_entry_to_root
        uint256 num_swaps = last_and_needs_entry_to_root.swap_tokens.length;
        for (uint256 i = 0; i < num_swaps; i++) {
            Pair memory pair = last_and_needs_entry_to_root.swap_tokens[i];
            int256 swap_amount = last_and_needs_entry_to_root.swap_amounts[pair];

            // Perform the swap with ERC20 tokens owned by the contract
            if (swap_amount > 0) {
                // Swap tokenA for tokenB
                uint256 amount_tokenA = uint256(swap_amount);
                IERC20(pair.tokenA).transferFrom(address(this), address(this), amount_tokenA);
                // Add your swapping logic here, e.g., using a DEX or an aggregator
            } else if (swap_amount < 0) {
                // Swap tokenB for tokenA
                uint256 amount_tokenB = uint256(-swap_amount);
                IERC20(pair.tokenB).transferFrom(address(this), address(this), amount_tokenB);
                // Add your swapping logic here, e.g., using a DEX or an aggregator
            }
        }
    }

    function updateRoot(Proof updateProof, uint256 newRoot) public {
        if (!BatchPriceSMTRootPriceUpdateVerifier.updateProof(updateProof, batch_swap_root, newRoot, keccak(last_and_needs_entry_to_root))) {
            revert("you did not update the prices right :(");
        }

        // free the hell out of last_and_needs_entry_to_root
        uint256 num_swaps = last_and_needs_entry_to_root.swap_tokens.length;
        for (uint256 i = 0; i < num_swaps; i++) {
            Pair memory pair = last_and_needs_entry_to_root.swap_tokens[i];
            delete last_and_needs_entry_to_root.swap_amounts[pair];
            delete last_and_needs_entry_to_root.prices[pair];
            delete pair;
        }
        delete last_and_needs_entry_to_root;
        batch_swap_root = newRoot;
    }
}