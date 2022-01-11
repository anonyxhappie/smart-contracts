// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "hardhat/console.sol";

contract Learn {
    function hello() public view {
        console.log('test1', block.timestamp);
        console.log('test2', block.timestamp + 1 days);
    }
}
