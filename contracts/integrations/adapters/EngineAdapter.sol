// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.8;

import "../../dependencies/WETH.sol";
import "../../engine/IEngine.sol";
import "../utils/AdapterBase.sol";

/// @title EngineAdapter Contract
/// @author Melon Council DAO <security@meloncoucil.io>
/// @notice Trading adapter to Melon Engine
contract EngineAdapter is AdapterBase {
    address immutable public EXCHANGE;

    constructor(address _registry, address _exchange) public AdapterBase(_registry) {
        EXCHANGE = _exchange;
    }

    /// @dev Needed to receive ETH from swap
    receive() external payable {}

    // EXTERNAL FUNCTIONS

    /// @notice Provides a constant string identifier for an adapter
    /// @return An identifier string
    function identifier() external pure override returns (string memory) {
        return "MELON_ENGINE";
    }

    /// @notice Parses the expected assets to receive from a call on integration 
    /// @param _selector The function selector for the callOnIntegration
    /// @param _encodedCallArgs The encoded parameters for the callOnIntegration
    /// @return spendAssets_ The assets to spend in the call
    /// @return spendAssetAmounts_ The max asset amounts to spend in the call
    /// @return incomingAssets_ The assets to receive in the call
    /// @return minIncomingAssetAmounts_ The min asset amounts to receive in the call
    function parseAssetsForMethod(bytes4 _selector, bytes calldata _encodedCallArgs)
        external
        view
        override
        returns (
            address[] memory spendAssets_,
            uint256[] memory spendAssetAmounts_,
            address[] memory incomingAssets_,
            uint256[] memory minIncomingAssetAmounts_
        )
    {
        if (_selector == TAKE_ORDER_SELECTOR) {
            (
                uint256 minNativeAssetAmount,
                uint256 mlnTokenAmount
            ) = __decodeCallArgs(_encodedCallArgs);
            Registry registry = Registry(__getRegistry());

            spendAssets_ = new address[](1);
            spendAssets_[0] = registry.mlnToken();
            spendAssetAmounts_ = new uint256[](1);
            spendAssetAmounts_[0] = mlnTokenAmount;

            incomingAssets_ = new address[](1);
            incomingAssets_[0] = registry.nativeAsset();
            minIncomingAssetAmounts_ = new uint256[](1);
            minIncomingAssetAmounts_[0] = minNativeAssetAmount;
        }
        else {
            revert("parseIncomingAssets: _selector invalid");
        }
    }

    /// @notice Trades assets on Kyber
    /// @param _encodedCallArgs Encoded order parameters
    /// @param _encodedAssetTransferArgs Encoded args for expected assets to spend and receive
    function takeOrder(bytes calldata _encodedCallArgs, bytes calldata _encodedAssetTransferArgs)
        external
        onlyVault
        fundAssetsTransferHandler(_encodedAssetTransferArgs)
    {
        (,uint256 mlnTokenAmount) = __decodeCallArgs(_encodedCallArgs);

        // Validate args
        require(mlnTokenAmount > 0, "takeOrder: mlnTokenAmount must be >0");

        // Execute fill
        Registry registry = Registry(__getRegistry());
        IERC20(registry.mlnToken()).approve(EXCHANGE, mlnTokenAmount);
        uint256 preEthBalance = payable(address(this)).balance;
        IEngine(EXCHANGE).sellAndBurnMln(mlnTokenAmount);
        uint256 ethFilledAmount = sub(payable(address(this)).balance, preEthBalance);

        // Return ETH to WETH
        WETH(payable(registry.nativeAsset())).deposit{value: ethFilledAmount}();
    }

    // PRIVATE FUNCTIONS

    /// @dev Helper to decode the encoded arguments
    function __decodeCallArgs(bytes memory _encodedCallArgs)
        private
        pure
        returns (
            uint256 minNativeAssetAmount_,
            uint256 mlnTokenAmount_
        )
    {
        return abi.decode(
            _encodedCallArgs,
            (
                uint256,
                uint256
            )
        );
    }
}
