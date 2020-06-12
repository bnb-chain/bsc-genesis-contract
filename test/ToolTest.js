const BSCValidatorSetTool = artifacts.require("tool/BSCValidatorSetTool");

contract('Tool', (accounts) => {
  it('tool test', async () => {
    const toolInstance = await BSCValidatorSetTool.deployed();
    await toolInstance.init();
  });
});

