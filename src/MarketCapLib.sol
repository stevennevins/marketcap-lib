// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@uniswap/v3-periphery/libraries/OracleLibrary.sol";
import "@uniswap/v3-periphery/libraries/PoolAddress.sol";
import "forge-std/interfaces/IERC20.sol";

/// @title MarketCapLib
/// @notice Provides functions for calculating market capitalizations and weights of ERC20 tokens using Uniswap V3 pools.
library MarketCapLib {
    address private constant FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint32 private constant PERIOD = 7 days;
    uint24 private constant FEE_TIER = 10000;

    /// @notice Computes the Uniswap V3 pool address for a given token paired with WETH
    /// @param token The address of the ERC20 token
    /// @return pool The address of the Uniswap V3 pool
    function computePoolAddress(address token) internal pure returns (address pool) {
        pool = PoolAddress.computeAddress(FACTORY, PoolAddress.getPoolKey(token, WETH, FEE_TIER));
    }

    /// @notice Computes the market capitalization of a token using its Uniswap V3 pool
    /// @param token The address of the ERC20 token
    /// @return The market capitalization of the token
    function computeTokenMarketCap(address token) internal view returns (uint256) {
        uint8 decimals = IERC20(token).decimals();
        address pool = computePoolAddress(token);
        (int24 tick, ) = OracleLibrary.consult(pool, PERIOD);
        uint256 price = OracleLibrary.getQuoteAtTick(tick, uint128(10 ** decimals), WETH, token);
        return ((price * IERC20(token).totalSupply()) / 10 ** decimals);
    }

    /// @notice Computes the square root of the market capitalization of a token
    /// @dev Taking the square root of market capitalization helps to reduce the weight of larger tokens, promoting a more equitable distribution
    /// @param token The address of the ERC20 token
    /// @return The square root of the market capitalization of the token
    function computeTokenSqrtMarketCap(address token) internal view returns (uint256) {
        return sqrt(computeTokenMarketCap(token));
    }

    /// @notice Computes the weights of tokens based on the square root of their market capitalizations
    /// @dev This method is used to calculate weights for tokens in a way that aims to balance the influence of large and small cap tokens
    /// @param tokens An array of ERC20 token addresses
    /// @return weights An array of weights proportional to the square root of each token's market capitalization
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

    /// @notice Computes the square root of a given number using the Babylonian method
    /// @param y The number to compute the square root of
    /// @return z The computed square root
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
