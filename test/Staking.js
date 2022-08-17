const SystemReward = artifacts.require("SystemReward");
const RelayerIncentivize = artifacts.require("RelayerIncentivize");
const TokenHub = artifacts.require("TokenHub");
const LightClient = artifacts.require("MockLightClient");
const SlashIndicator = artifacts.require("SlashIndicator");
const TokenManager = artifacts.require("TokenManager");
const CrossChain = artifacts.require("CrossChain");
const RelayerHub = artifacts.require("RelayerHub");
const GovHub = artifacts.require("GovHub");
const Staking = artifacts.require("Staking");
const BSCValidatorSet = artifacts.require("BSCValidatorSet");

const RLP = require('rlp');
const Web3 = require('web3');
const truffleAssert = require('truffle-assertions');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

const EVENT_DELEGATE = 0x01;
const EVENT_UNDELEGATE = 0x02;
const EVENT_REDELEGATE = 0x03;
const EVENT_TRANSFER_IN_REWARD = 0x04;
const EVENT_TRANSFER_IN_UNDELEGATED = 0x05;
const GOV_CHANNEL_ID = 0x09;
const CROSS_STAKE_CHANNELID = 0x10;

contract('Staking', (accounts) => {
	it('Delegate', async () => {
		const govHubInstance = await GovHub.deployed();
		const crossChainInstance = await CrossChain.deployed();
		const stakingInstance = await Staking.deployed();

		const relayerAccount = accounts[8];
		await govHubInstance.handleSynPackage(GOV_CHANNEL_ID,
			serialize("addOrUpdateChannel",
				web3.utils.bytesToHex(Buffer.concat(
					[Buffer.from(web3.utils.hexToBytes("0x10")),
						Buffer.from(web3.utils.hexToBytes("0x01")),
						Buffer.from(web3.utils.hexToBytes(stakingInstance.address))])),
				crossChainInstance.address), {from: relayerAccount});

		const delegator = accounts[2];
		const validator = accounts[0];
		let amount = web3.utils.toBN(2e20);
		let relayFee = web3.utils.toBN(2e16);

		try {
			await stakingInstance.delegate(validator, amount, {
				from: delegator,
				value: amount.add(relayFee).add(web3.utils.toBN(1))
			});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("invalid msg value: precision loss in amount conversion"));
		}

		try {
			const wrongAmount = web3.utils.toBN(1e20).add(web3.utils.toBN(1));
			await stakingInstance.delegate(validator, wrongAmount, {from: delegator, value: amount.add(relayFee)});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("invalid amount: precision loss in amount conversion"));
		}

		try {
			const wrongAmount = web3.utils.toBN(1e18);
			await stakingInstance.delegate(validator, wrongAmount, {from: delegator, value: wrongAmount.add(relayFee)});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("the amount must not be less than minDelegationChange"));
		}

		try {
			await stakingInstance.delegate(validator, amount, {from: delegator, value: amount});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("the msg value should be no less than the sum of stake amount and minimum oracleRelayerFee"));
		}

		try {
			const wrongRelayFee = web3.utils.toBN(1e15);
			await stakingInstance.delegate(validator, amount, {from: delegator, value: amount.add(wrongRelayFee)});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("the msg value should be no less than the sum of stake amount and minimum oracleRelayerFee"));
		}

		let tx = await stakingInstance.delegate(validator, amount, {from: delegator, value: amount.add(relayFee)});
		truffleAssert.eventEmitted(tx, "delegateSubmitted", (ev) => {
			return ev.amount.eq(amount) && ev.oracleRelayerFee.eq(relayFee);
		});

		let delegated = await stakingInstance.getDelegated.call(delegator, validator);
		assert.equal(delegated.toString(), amount.toString());
	});

	it('Undelegate', async () => {
		const stakingInstance = await Staking.deployed();
		const delegator = accounts[2];
		const validator = accounts[0];

		let amount = web3.utils.toBN(1e20);
		let relayFee = web3.utils.toBN(2e16);
		try {
			await stakingInstance.undelegate(validator, amount, {from: delegator, value: relayFee.add(web3.utils.toBN(1))});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("invalid msg value: precision loss in amount conversion"));
		}

		try {
			const wrongAmount = web3.utils.toBN(1e20).add(web3.utils.toBN(1));
			await stakingInstance.undelegate(validator, wrongAmount, {from: delegator, value: relayFee});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("invalid amount: precision loss in amount conversion"));
		}

		try {
			const wrongAmount = web3.utils.toBN(1e18);
			await stakingInstance.undelegate(validator, wrongAmount, {from: delegator, value: relayFee});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("the amount must not be less than minDelegationChange, or else equal to the remaining delegation"));
		}

		try {
			const wrongRelayFee = web3.utils.toBN(1e15);
			await stakingInstance.undelegate(validator, amount, {from: delegator, value: wrongRelayFee});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("the msg value should be no less than the minimum oracleRelayerFee"));
		}

		try {
			await stakingInstance.undelegate(accounts[1], amount, {from: delegator, value: relayFee});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("not enough funds to undelegate"));
		}

		let tx = await stakingInstance.undelegate(validator, amount, {from: delegator, value: relayFee});
		truffleAssert.eventEmitted(tx, "undelegateSubmitted", (ev) => {
			return ev.amount.eq(amount) && ev.oracleRelayerFee.eq(relayFee); });

		let lockedUndelegated = await stakingInstance.getPendingUndelegated.call(delegator, validator);
		assert.equal(lockedUndelegated.toString(), amount.toString());

		try {
			await stakingInstance.undelegate(validator, amount, {from: delegator, value: relayFee});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("pending undelegation exist"));
		}
	});

	it('Redelegate', async () => {
		const stakingInstance = await Staking.deployed();
		const delegator = accounts[2];
		const validatorSrc = accounts[0];
		const validatorDst = accounts[1];

		let amount = web3.utils.toBN(2e20);
		let relayFee = web3.utils.toBN(2e16);
		await stakingInstance.delegate(validatorSrc, amount, {from: delegator, value: amount.add(relayFee)});

		try {
			await stakingInstance.redelegate(validatorSrc, validatorSrc, amount, {from: delegator, value: relayFee});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("invalid redelegation, source validator is the same as dest validator"));
		}

		try {
			await stakingInstance.redelegate(accounts[3], validatorDst, amount, {from: delegator, value: relayFee});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("not enough funds to redelegate"));
		}

		try {
			await stakingInstance.redelegate(validatorSrc, validatorDst, amount, { from: delegator, value: relayFee.add(web3.utils.toBN(1)) });
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("invalid msg value: precision loss in amount conversion"));
		}

		try {
			const wrongAmount = web3.utils.toBN(1e20).add(web3.utils.toBN(1));
			await stakingInstance.redelegate(validatorSrc, validatorDst, wrongAmount, {from: delegator, value: relayFee});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("invalid amount: precision loss in amount conversion"));
		}

		try {
			const wrongAmount = web3.utils.toBN(1e18);
			await stakingInstance.redelegate(validatorSrc, validatorDst, wrongAmount, {from: delegator, value: relayFee});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("the amount must not be less than minDelegationChange"));
		}

		try {
			const wrongRelayFee = web3.utils.toBN(1e15);
			await stakingInstance.redelegate(validatorSrc, validatorDst, amount, {from: delegator, value: wrongRelayFee});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("the msg value should be no less than the minimum oracleRelayerFee"));
		}

		amount = web3.utils.toBN(1e20);
		let tx = await stakingInstance.redelegate(validatorSrc, validatorDst, amount, {from: delegator, value: relayFee});
		truffleAssert.eventEmitted(tx, "redelegateSubmitted", (ev) => {
			return ev.amount.eq(amount) && ev.oracleRelayerFee.eq(relayFee);
		});

		try {
			await stakingInstance.redelegate(validatorSrc, validatorDst, amount, {from: delegator, value: relayFee});
			assert.fail();
		} catch (error) {
			assert.ok(error.toString().includes("conflicting redelegation from this source validator to this dest validator already exists, you must wait for it to finish"));
		}
	});
})

contract('Staking', (accounts) => {
	it('handleRewardSynPackage', async () => {
		const govHubInstance = await GovHub.deployed();
		const tokenHubInstance = await TokenHub.deployed();
		const crossChainInstance = await CrossChain.deployed();
		const stakingInstance = await Staking.deployed();
		const relayerAccount = accounts[8];

		await tokenHubInstance.send(web3.utils.toBN(1e20), {from: accounts[1]});
		await govHubInstance.handleSynPackage(GOV_CHANNEL_ID,
			serialize("addOrUpdateChannel", web3.utils.bytesToHex(Buffer.concat(
					[Buffer.from(web3.utils.hexToBytes("0x10")),
						Buffer.from(web3.utils.hexToBytes("0x00")),
						Buffer.from(web3.utils.hexToBytes(stakingInstance.address))])),
				crossChainInstance.address), {from: relayerAccount});

		const delegator = accounts[2];
		const validator = accounts[0];
		let amount = web3.utils.toBN(1e20);
		let relayFee = web3.utils.toBN(2e16);
		await stakingInstance.delegate(validator, amount, {from: delegator, value: amount.add(relayFee)});
		await stakingInstance.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address,
			LightClient.address, TokenHub.address, RelayerIncentivize.address, RelayerHub.address, GovHub.address,
			TokenManager.address, relayerAccount, Staking.address);

		let reward = web3.utils.toBN(1e18);
		let packageBytes = transferInRewardRlpEncode(EVENT_TRANSFER_IN_REWARD, reward, delegator);
		let tx = await stakingInstance.handleSynPackage(CROSS_STAKE_CHANNELID, packageBytes, {from: relayerAccount});
		truffleAssert.eventEmitted(tx, "rewardReceived", (ev) => {
			return ev.amount.eq(reward) && ev.delegator == delegator;
		});
	});

	it('ClaimReward', async () => {
		const stakingInstance = await Staking.deployed();

		const delegator = accounts[2];
		const expectedReward = web3.utils.toBN(1e18);

		let pendingReward = await stakingInstance.getDistributedReward.call(delegator);
		assert.equal(pendingReward.toString(), expectedReward.toString());

		let tx = await stakingInstance.claimReward({from: delegator});
		assert.equal(tx.logs[0].args.amount.toString(), expectedReward.toString());
		truffleAssert.eventEmitted(tx, "rewardClaimed", (ev) => {
			return ev.amount.eq(expectedReward) && ev.delegator == delegator;
		});

		pendingReward = await stakingInstance.getDistributedReward.call(delegator);
		assert.equal(pendingReward.toString(), web3.utils.toBN(0).toString());
	})

	it('handleUndelegatedSynPackage', async () => {
		const stakingInstance = await Staking.deployed();
		const relayerAccount = accounts[8];

		const undelegated = web3.utils.toBN(1e18);
		const delegator = accounts[2];

		let packageBytes = transferInUndelegatedRlpEncode(EVENT_TRANSFER_IN_UNDELEGATED, undelegated, delegator, accounts[0]);
		let tx = await stakingInstance.handleSynPackage(CROSS_STAKE_CHANNELID, packageBytes, {from: relayerAccount});
		truffleAssert.eventEmitted(tx, "undelegatedReceived", (ev) => {
			return ev.amount.eq(undelegated) && ev.delegator == delegator;
		});
	});

	it('ClaimUndelegated', async () => {
		const stakingInstance = await Staking.deployed();

		const delegator = accounts[2];
		const expectedUndelegated = web3.utils.toBN(1e18);

		let undelegated = await stakingInstance.getUndelegated.call(delegator);
		assert.equal(undelegated.toString(), expectedUndelegated.toString());

		let tx = await stakingInstance.claimUndeldegated({from: delegator});
		assert.equal(tx.logs[0].args.amount.toString(), expectedUndelegated.toString());
		truffleAssert.eventEmitted(tx, "undelegatedClaimed", (ev) => {
			return ev.amount.eq(undelegated) && ev.delegator == delegator;
		});

		undelegated = await stakingInstance.getUndelegated.call(delegator);
		assert.equal(undelegated.toString(), web3.utils.toBN(0).toString());
	})
})

contract('Staking', (accounts) => {
	it('handleDelegateAckPackage', async () => {
		const govHubInstance = await GovHub.deployed();
		const tokenHubInstance = await TokenHub.deployed();
		const crossChainInstance = await CrossChain.deployed();
		const stakingInstance = await Staking.deployed();
		const relayerAccount = accounts[8];

		await tokenHubInstance.send(web3.utils.toBN(1e20), {from: accounts[1]});
		await govHubInstance.handleSynPackage(GOV_CHANNEL_ID,
			serialize("addOrUpdateChannel", web3.utils.bytesToHex(Buffer.concat(
					[Buffer.from(web3.utils.hexToBytes("0x10")),
						Buffer.from(web3.utils.hexToBytes("0x00")),
						Buffer.from(web3.utils.hexToBytes(stakingInstance.address))])),
				crossChainInstance.address), {from: relayerAccount});

		const delegator = accounts[2];
		const validator = accounts[0];
		let amount = web3.utils.toBN(1e20);
		let relayFee = web3.utils.toBN(2e16);
		await stakingInstance.delegate(validator, amount, {from: delegator, value: amount.add(relayFee)});
		await stakingInstance.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address,
			LightClient.address, TokenHub.address, RelayerIncentivize.address, RelayerHub.address, GovHub.address,
			TokenManager.address, relayerAccount, Staking.address);

		let packageBytes = delegateRlpEncode(EVENT_DELEGATE, delegator, validator, amount, 0x01);
		let tx = await stakingInstance.handleAckPackage(CROSS_STAKE_CHANNELID, packageBytes, {from: relayerAccount});
		truffleAssert.eventEmitted(tx, "failedDelegate", (ev) => {
			return ev.amount.eq(amount) && ev.delegator === delegator;
		});
	});
})

contract('Staking', (accounts) => {
	it('handleUndelegateAckPackage', async () => {
		const govHubInstance = await GovHub.deployed();
		const tokenHubInstance = await TokenHub.deployed();
		const crossChainInstance = await CrossChain.deployed();
		const stakingInstance = await Staking.deployed();
		const relayerAccount = accounts[8];

		await tokenHubInstance.send(web3.utils.toBN(1e20), {from: accounts[1]});
		await govHubInstance.handleSynPackage(GOV_CHANNEL_ID,
			serialize("addOrUpdateChannel", web3.utils.bytesToHex(Buffer.concat(
					[Buffer.from(web3.utils.hexToBytes("0x10")),
						Buffer.from(web3.utils.hexToBytes("0x00")),
						Buffer.from(web3.utils.hexToBytes(stakingInstance.address))])),
				crossChainInstance.address), {from: relayerAccount});

		const delegator = accounts[2];
		const validator = accounts[0];
		let amount = web3.utils.toBN(1e20);
		let relayFee = web3.utils.toBN(2e16);
		await stakingInstance.delegate(validator, amount, {from: delegator, value: amount.add(relayFee)});
		await stakingInstance.undelegate(validator, amount, {from: delegator, value: relayFee});
		await stakingInstance.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address,
			LightClient.address, TokenHub.address, RelayerIncentivize.address, RelayerHub.address, GovHub.address,
			TokenManager.address, relayerAccount, Staking.address);

		let packageBytes = undelegateRlpEncode(EVENT_UNDELEGATE, delegator, validator, amount, 0x01);
		let tx = await stakingInstance.handleAckPackage(CROSS_STAKE_CHANNELID, packageBytes, {from: relayerAccount});
		truffleAssert.eventEmitted(tx, "failedUndelegate", (ev) => {
			return ev.amount.eq(amount) && ev.delegator === delegator;
		});
	});
})

contract('Staking', (accounts) => {
	it('handleRedelegateAckPackage', async () => {
		const govHubInstance = await GovHub.deployed();
		const tokenHubInstance = await TokenHub.deployed();
		const crossChainInstance = await CrossChain.deployed();
		const stakingInstance = await Staking.deployed();
		const relayerAccount = accounts[8];

		await tokenHubInstance.send(web3.utils.toBN(1e20), {from: accounts[1]});
		await govHubInstance.handleSynPackage(GOV_CHANNEL_ID,
			serialize("addOrUpdateChannel", web3.utils.bytesToHex(Buffer.concat(
					[Buffer.from(web3.utils.hexToBytes("0x10")),
						Buffer.from(web3.utils.hexToBytes("0x00")),
						Buffer.from(web3.utils.hexToBytes(stakingInstance.address))])),
				crossChainInstance.address), {from: relayerAccount});

		const delegator = accounts[2];
		const validatorSrc = accounts[0];
		const validatorDst = accounts[1];
		let amount = web3.utils.toBN(1e20);
		let relayFee = web3.utils.toBN(2e16);
		await stakingInstance.delegate(validatorSrc, amount, {from: delegator, value: amount.add(relayFee)});
		await stakingInstance.redelegate(validatorSrc, validatorDst, amount, {from: delegator, value: relayFee});
		await stakingInstance.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address,
			LightClient.address, TokenHub.address, RelayerIncentivize.address, RelayerHub.address, GovHub.address,
			TokenManager.address, relayerAccount, Staking.address);

		let packageBytes = redelegateRlpEncode(EVENT_REDELEGATE, delegator, validatorSrc, validatorDst, amount, 0x01);
		let tx = await stakingInstance.handleAckPackage(CROSS_STAKE_CHANNELID, packageBytes, {from: relayerAccount});
		truffleAssert.eventEmitted(tx, "failedRedelegate", (ev) => {
			return ev.amount.eq(amount) && ev.delegator === delegator;
		});
	});
})


function serialize(key, value, target, extra) {
	let pkg = [];
	pkg.push(key);
	pkg.push(value);
	pkg.push(target);
	if (extra != null) {
		pkg.push(extra);
	}
	return RLP.encode(pkg);
}

function transferInUndelegatedRlpEncode(eventCode, amount, recipient, validator) {
	let pkg = [];
	pkg.push(eventCode);
	pkg.push(amount);
	pkg.push(recipient);
	pkg.push(validator);
	return RLP.encode(pkg)
}

function transferInRewardRlpEncode(eventCode, reward, recipient) {
	let pkg = [];
	pkg.push(eventCode);
	pkg.push(reward);
	pkg.push(recipient);
	return RLP.encode(pkg)
}

function delegateRlpEncode(eventCode, delegator, validator, amount, errCode) {
	let pkg = [];
	pkg.push(eventCode);
	pkg.push(delegator);
	pkg.push(validator);
	pkg.push(amount);
	pkg.push(errCode);
	return RLP.encode(pkg)
}

function undelegateRlpEncode(eventCode, delegator, validator, amount, errCode) {
	let pkg = [];
	pkg.push(eventCode);
	pkg.push(delegator);
	pkg.push(validator);
	pkg.push(amount);
	pkg.push(errCode);
	return RLP.encode(pkg)
}

function redelegateRlpEncode(eventCode, delegator, valSrc, valDst, amount, errCode) {
	let pkg = [];
	pkg.push(eventCode);
	pkg.push(delegator);
	pkg.push(valSrc);
	pkg.push(valDst);
	pkg.push(amount);
	pkg.push(errCode);
	return RLP.encode(pkg)
}
