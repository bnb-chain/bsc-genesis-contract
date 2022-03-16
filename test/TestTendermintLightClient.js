const TendermintLightClient = artifacts.require("TendermintLightClient");

const Web3 = require("web3");
const web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));

contract("TendermintLightClient", (accounts) => {
  it("Init consensus state", async () => {
    const lightClient = await TendermintLightClient.deployed();

    let initialHeight = await lightClient.initialHeight.call();
    assert.equal(initialHeight.toNumber(), 2, "mismatched initial consensus height");
    const chainID = await lightClient.getChainID.call();
    assert.equal(chainID, "Binance-Chain-Nile", "mismatched chainID");

    const isHeaderSynced = await lightClient.isHeaderSynced.call(2);
    assert.equal(isHeaderSynced, true, "height already synced");
  });
});
