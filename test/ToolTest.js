const BSCValidatorSetTool = artifacts.require("tool/BSCValidatorSetTool");
const Web3 = require('web3');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

contract('Tool', (accounts) => {
  it('tool test', async () => {
    const toolInstance = await BSCValidatorSetTool.deployed();
    await toolInstance.init();
  });
  
  it('decode payload header', async () => {
    let payload = "0x00000000000000000000000000000000000000000000000000002386f26fc10000f85580a04142432d304237000000000000000000000000000000000000000000000000009450ee0de39df3b9c2bc8f8e33d9e4cd03dba9210c8b52b7d2dcc80cd2e40000008b31a17e847807b1bc00000012845f5efcc1"
    const toolInstance = await BSCValidatorSetTool.deployed();
    let x = await toolInstance.decodePayloadHeader.call(web3.utils.hexToBytes(payload));
    assert.equal(x[2].toString(), "10000000000000000");
  });
  
});

