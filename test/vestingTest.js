const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("ICOTokenVestin Tests", function () {
  let vestingContract;
  let tokenName = "Vesting";
  let tokenSymbol = "ICOV";
  const aggregatorv3Goerli = "0xd4a33860578de61dbabdc8bfdb98fd742fa7028e";
  const maxSupply = 100;
  let ethPrice; // manually fill the ethPrice while testing

  beforeEach("It should deploy the contract", async function () {
    const contractFactory = await ethers.getContractFactory("ICOTokenVesting");
    vestingContract = await contractFactory.deploy(
      tokenName,
      tokenSymbol,
      aggregatorv3Goerli,
      maxSupply
    );
    vestingContract.deployed();
    console.log(`Vesting Contract Deployed at ${vestingContract.address}`);
  });

  it("Should check if the vesting contract is initalized", async function () {
    const [owner] = await ethers.getSigners();
    const contractOwner = await vestingContract.owner();
    assert.equal(owner.address, contractOwner);
  });

  it("Should check whether the chainlink data feed is working", async function () {
    const ethAmount = await vestingContract.getEthPrice();
    const formatEth = await ethers.utils.formatEther(ethAmount);
    ethPrice = 1300; // always put an int less than the market price to verify.
    console.log(`Current Eth Price is $${formatEth}`);
    assert.equal(formatEth > 1300, true);
  });

  it("Should verify the ETH conversion rate", async function () {
    const ethAmount = await vestingContract.getEthPrice();
    const formatEth = await ethers.utils.formatEther(ethAmount);
    console.log(`Current Eth Price is $${Math.trunc(formatEth)}`);
    const getEthToUSD = await vestingContract.getConversionRate(1);
    console.log(`Conversion rate for 1 ETH is $${getEthToUSD}`);
    assert.equal(Math.trunc(formatEth), getEthToUSD);
  });

  it("Should check if the vesting schedule per user is working", async function () {
    const tokenAmount = 10;
    const getEthToUSD = await vestingContract.getConversionRate(1);
    const ethToSpend = (1 / getEthToUSD) * tokenAmount;
    console.log(
      `To buy ${tokenAmount} tokens, you will spend ${ethToSpend} ETH`
    );

    const tx = await vestingContract.buyToken(tokenAmount, {
      value: ethers.utils.parseEther(ethToSpend.toString()),
    });
    const balance = await vestingContract.getBalance();
    console.log(`Current balance is ${balance}`);
    const parsedTokenAmount = await ethers.utils.parseUnits(
      tokenAmount.toString(),
      18
    );
    console.log(`Parsed Token Amount is ${parsedTokenAmount}`);
    expect(parsedTokenAmount).to.eql(balance);
  });

  it("Unlock date must be in the future i.e, after 30 days of contract deployment", async function () {
    const res = await vestingContract.unlockDate();
    const resToDate = new Date(res * 1000);
    console.log(`Next unlock date is ${resToDate}`);
    const unixTimestamp = Math.floor(new Date().getTime() / 1000);
    expect(unixTimestamp).to.lt(res);
  });

  it.only("Cannot buy more than Max Supply", async function () {
    const tokenAmount = 90;
    const getEthToUSD = await vestingContract.getConversionRate(1);
    const ethToSpend = (1 / getEthToUSD) * tokenAmount;
    console.log(
      `To buy ${tokenAmount} tokens, you will spend ${ethToSpend} ETH`
    );

    let txWentThrough;
    try {
      const tx = await vestingContract.buyToken(tokenAmount, {
        value: ethers.utils.parseEther(ethToSpend.toString()),
      });
      const balance = await vestingContract.getBalance();
      console.log(balance);
      txWentThrough = true;
    } catch (error) {
      txWentThrough = false;
    }
    assert.equal(txWentThrough, false);
  });
});
