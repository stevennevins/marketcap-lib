// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@uniswap/v3-periphery/libraries/OracleLibrary.sol";
import "@uniswap/v3-periphery/libraries/PoolAddress.sol";
import "forge-std/interfaces/IERC20.sol";

library MarketCapLib {
    address private constant FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint32 private constant PERIOD = 7 days;
    uint24 private constant FEE_TIER = 10000;

    function computePoolAddress(address token) internal pure returns (address pool) {
        pool = PoolAddress.computeAddress(FACTORY, PoolAddress.getPoolKey(token, WETH, FEE_TIER));
    }

    function computeTokenMarketCap(address token) internal view returns (uint256) {
        uint8 decimals = IERC20(token).decimals();
        address pool = computePoolAddress(token);
        (int24 tick, ) = OracleLibrary.consult(pool, PERIOD);
        uint256 price = OracleLibrary.getQuoteAtTick(tick, uint128(10 ** decimals), WETH, token);
        return ((price * IERC20(token).totalSupply()) / 10 ** decimals);
    }

    function computeTokenSqrtMarketCap(address token) internal view returns (uint256) {
        return sqrt(computeTokenMarketCap(token));
    }

    function computeTokenWeights(address[] memory tokens) internal view returns (uint256[] memory) {
        uint256 totalSqrtMarketCap = 0;
        uint256 len = tokens.length;
        uint256[] memory weights = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            weights[i] = computeTokenSqrtMarketCap(tokens[i]);
            totalSqrtMarketCap += weights[i];
        }

        if (totalSqrtMarketCap == 0) {
            return weights;
        }

        for (uint256 i = 0; i < len; i++) {
            weights[i] = (weights[i] * 1e18) / totalSqrtMarketCap;
        }

        return weights;
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
