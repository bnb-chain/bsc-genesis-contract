

// Use to convert chainid to bscChainId
function formatChainID(chainid) {
    const hexString = (chainid >>> 0).toString(16); // Convert to hexadecimal and treat as unsigned
    return hexString.padStart(4, '0'); // Pad with leading zeros to a length of 4 characters
}

exports = module.exports = formatChainID;