// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AMMStrategyBase} from "./AMMStrategyBase.sol";
import {IAMMStrategy, TradeInfo} from "./IAMMStrategy.sol";

/// @title Undercut Strategy - Fixed fee below normalizer
/// @notice Simple baseline: 26 bps to undercut 30 bps normalizer and capture more retail.
///         No adaptation; use to compare vs adaptive strategies.
contract Strategy is AMMStrategyBase {
    uint256 private constant FEE_BPS = 26;

    function afterInitialize(uint256, uint256) external pure override returns (uint256, uint256) {
        uint256 fee = bpsToWad(FEE_BPS);
        return (fee, fee);
    }

    function afterSwap(TradeInfo calldata) external pure override returns (uint256, uint256) {
        return (bpsToWad(FEE_BPS), bpsToWad(FEE_BPS));
    }

    function getName() external pure override returns (string memory) {
        return "Undercut_26bps";
    }
}
