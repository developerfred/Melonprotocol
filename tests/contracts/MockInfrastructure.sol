pragma solidity 0.6.4;

import "main/fund/hub/Hub.sol";

/// @notice Mock infrastructure level-contract useful for testing
contract MockInfrastructure {
    uint public amguPrice;
    bool public isShutDown;

    function setAmguPrice(uint _price) public { amguPrice = _price; }
    function securityShutDown() external { isShutDown = true; }
    function shutDownFund(address _hub) external { Hub(_hub).shutDownFund(); }
    function getShutDownStatus() external view returns (bool) {return isShutDown;}
    function getAmguPrice() public view returns (uint) { return amguPrice; }
}
