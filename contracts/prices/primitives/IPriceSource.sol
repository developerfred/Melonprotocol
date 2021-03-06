// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.8;

/// @title PriceSource Interface
/// @author Melon Council DAO <security@meloncoucil.io>
interface IPriceSource {
    function getCanonicalRate(address _baseAsset, address _quoteAsset)
        external
        view
        returns (uint256 rate, bool isValid, uint256 timestamp);
    function getLiveRate(address _baseAsset, address _quoteAsset)
        external
        view
        returns (uint256 rate, bool isValid);
    function hasValidPrice(address) external view returns (bool);
    function lastUpdate() external view returns (uint256);
    function VALIDITY_INTERVAL() external view returns (uint256);
}
