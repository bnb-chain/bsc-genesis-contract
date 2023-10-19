const web3 = require('web3');
const init_holders = [
  {
    // private key is 0x9b28f36fbd67381120752d6172ecdcf10e06ab2d9a1367aac00cdcd6ac7855d3, only use in dev
    address: '0x9fB29AAc15b9A4B7F17c3385939b007540f4d791',
    balance: web3.utils.toBN('10000000000000000000000000').toString('hex'),
  },
];

exports = module.exports = init_holders;
