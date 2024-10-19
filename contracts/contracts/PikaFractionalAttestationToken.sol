// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./PikaPay.sol"; // Import the PikaPay contract

contract PikaFractionalAttestationToken is ERC20 {
    using SafeERC20 for ERC20;

    PikaPay public pikaPay;
    uint256 public batchId;

    constructor(
        PikaPay _pikaPay,
        uint256 _batchId,
        uint256 _initialSupply
    )
        ERC20(
            string.concat("PikaPay Fractional Batch #", Strings.toString(_batchId)),
            "PFAT" // Token symbol
        )
    {
        require(_initialSupply > 0, "Initial supply must be greater than 0");
        pikaPay = _pikaPay;
        batchId = _batchId;
        _mint(msg.sender, _initialSupply);
    }

    // Hook function to ensure only PikaPay can transfer this token type
    function _beforeTokenTransfer(address from) internal view  {
        require(from == address(pikaPay), "Only PikaPay can initiate transfers.");
    }
}
