const BSCValidatorSetTool = artifacts.require("tool/BSCValidatorSetTool");
const Web3 = require('web3');
const truffleAssert = require('truffle-assertions');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

contract('Tool', (accounts) => {
  it('tool test', async () => {
    const toolInstance = await BSCValidatorSetTool.deployed();
    await toolInstance.verify(Buffer.from(web3.utils.hexToBytes("0x0000010002080000000000000000")),Buffer.from(web3.utils.hexToBytes("0x00a50381a86cd38ca23f6136556fc604329a054a855d2287739da12be1f3e3b1aeaf14f888e9d6379521d3edbf1bcfe239a7b47c756cdb0913a3079897000000e8d4a51000a5f6a270f60c83624dd1849038ee7c9e8a3e55fcc9ff491fd30c1026b24b975274cf3d4286d36fa1d98dbab2ddc67935996c0e51bd7e6f596485da24000000e8d4a510000dd11a413972d8b1e1367c4b9196f75348424e70c9c121c762d1e349dc3e38324d1c108c0b08abf9f2be3d724bf1bc39d86319c188af5158b3b9ccd4000000e8d4a51000")), 0);
    let k = await toolInstance.expectedKey.call();
    console.log(k)
  });
});

