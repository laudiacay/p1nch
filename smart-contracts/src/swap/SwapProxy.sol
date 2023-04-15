// Inspred by: https://github.com/smye/1inch-swap/blob/master/contracts/SwapProxy.sol
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

contract SwapProxy {
    ISwapRouter public immutable swapRouter;
    // address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    // address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // TODO: ma ze?
    uint24 public constant feeTier = 3000;

    struct SwapDescription {
        address srcToken;
        address dstToken;
        // address srcReceiver;
        // address dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint160 priceLimit;
    }

    // address immutable AGGREGATION_ROUTER_V3;

    constructor(ISwapRouter _swapRouter) {
        swapRouter = _swapRouter;
    }

    function swap(
        SwapDescription memory swap_description
    ) internal returns (uint256 amountOut) {
        // Approve the router to spend srcToken.
        TransferHelper.safeApprove(
            swap_description.srcToken,
            address(swapRouter),
            swap_description.amount
        );
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: swap_description.srcToken,
                tokenOut: swap_description.dstToken,
                fee: feeTier,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: swap_description.amount,
                amountOutMinimum: swap_description.minReturnAmount,
                sqrtPriceLimitX96: swap_description.priceLimit
            });
        amountOut = swapRouter.exactInputSingle(params);
    }
}
