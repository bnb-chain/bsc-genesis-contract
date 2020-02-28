const web3 = require("web3")
const init_holders = [
  {
    address: "0x6c468CF8c9879006E22EC4029696E005C2319C9D",
    balance: web3.utils.toBN(1e18).toString("hex")
  }
  // {
  //   address: "0x6c468CF8c9879006E22EC4029696E005C2319C9D",
  //   balance: 10000 // without 10^18
  // }
];


exports = module.exports = init_holders
