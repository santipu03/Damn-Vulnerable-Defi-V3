// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";

contract BackdoorApproval {
    function approve(address spender, address token) external {
        DamnValuableToken(token).approve(spender, 10 ether);
    }
}
