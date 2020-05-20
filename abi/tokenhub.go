// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package tokenhub

import (
	"math/big"
	"strings"

	ethereum "github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
)

// Reference imports to suppress errors if they are not otherwise used.
var (
	_ = big.NewInt
	_ = strings.NewReader
	_ = ethereum.NotFound
	_ = abi.U256
	_ = bind.Bind
	_ = common.Big1
	_ = types.BloomLookup
	_ = event.NewSubscription
)

// TokenhubABI is the input ABI used to generate the binding from.
const TokenhubABI = "[{\"inputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"constructor\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"sequence\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"uint256[]\",\"name\":\"amounts\",\"type\":\"uint256[]\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"bep2TokenSymbol\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"expireTime\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"relayFee\",\"type\":\"uint256\"}],\"name\":\"LogBatchTransferOut\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"sequence\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address[]\",\"name\":\"recipientAddrs\",\"type\":\"address[]\"},{\"indexed\":false,\"internalType\":\"address[]\",\"name\":\"refundAddrs\",\"type\":\"address[]\"}],\"name\":\"LogBatchTransferOutAddrs\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"sequence\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"bep2TokenSymbol\",\"type\":\"bytes32\"}],\"name\":\"LogBindInvalidParameter\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"sequence\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"bep2TokenSymbol\",\"type\":\"bytes32\"}],\"name\":\"LogBindRejected\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"bep2TokenSymbol\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"totalSupply\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"peggyAmount\",\"type\":\"uint256\"}],\"name\":\"LogBindRequest\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"sequence\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"bep2TokenSymbol\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"totalSupply\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"peggyAmount\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"decimals\",\"type\":\"uint256\"}],\"name\":\"LogBindSuccess\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"sequence\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"bep2TokenSymbol\",\"type\":\"bytes32\"}],\"name\":\"LogBindTimeout\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"refundAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"uint16\",\"name\":\"reason\",\"type\":\"uint16\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"actualBalance\",\"type\":\"uint256\"}],\"name\":\"LogRefundFailureInsufficientBalance\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"refundAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"uint16\",\"name\":\"reason\",\"type\":\"uint16\"}],\"name\":\"LogRefundFailureUnboundToken\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"refundAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"uint16\",\"name\":\"reason\",\"type\":\"uint16\"}],\"name\":\"LogRefundFailureUnknownReason\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"refundAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"uint16\",\"name\":\"reason\",\"type\":\"uint16\"}],\"name\":\"LogRefundSuccess\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"sequence\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"refundAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"recipient\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"bep2TokenAmount\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"bep2TokenSymbol\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"actualBalance\",\"type\":\"uint256\"}],\"name\":\"LogTransferInFailureInsufficientBalance\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"sequence\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"refundAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"recipient\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"bep2TokenAmount\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"bep2TokenSymbol\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"expireTime\",\"type\":\"uint256\"}],\"name\":\"LogTransferInFailureTimeout\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"sequence\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"refundAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"recipient\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"bep2TokenAmount\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"bep2TokenSymbol\",\"type\":\"bytes32\"}],\"name\":\"LogTransferInFailureUnboundToken\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"sequence\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"refundAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"recipient\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"bep2TokenAmount\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"bep2TokenSymbol\",\"type\":\"bytes32\"}],\"name\":\"LogTransferInFailureUnknownReason\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"sequence\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"recipient\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"}],\"name\":\"LogTransferInSuccess\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"sequence\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"refundAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"recipient\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"bep2TokenSymbol\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"expireTime\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"relayFee\",\"type\":\"uint256\"}],\"name\":\"LogTransferOut\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes\",\"name\":\"lowLevelData\",\"type\":\"bytes\"}],\"name\":\"LogUnexpectedFailureAssertionInBEP2E\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"string\",\"name\":\"reason\",\"type\":\"string\"}],\"name\":\"LogUnexpectedRevertInBEP2E\",\"type\":\"event\"},{\"constant\":true,\"inputs\":[],\"name\":\"BEP2_TOKEN_DECIMALS\",\"outputs\":[{\"internalType\":\"uint8\",\"name\":\"\",\"type\":\"uint8\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"BEP2_TOKEN_SYMBOL_FOR_BNB\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"BIND_CHANNEL_ID\",\"outputs\":[{\"internalType\":\"uint8\",\"name\":\"\",\"type\":\"uint8\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"GOV_HUB_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"INCENTIVIZE_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"LIGHT_CLIENT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"MAXIMUM_BEP2E_SYMBOL_LEN\",\"outputs\":[{\"internalType\":\"uint8\",\"name\":\"\",\"type\":\"uint8\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"MAX_BEP2_TOTAL_SUPPLY\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"MAX_GAS_FOR_CALLING_BEP2E\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"MINIMUM_BEP2E_SYMBOL_LEN\",\"outputs\":[{\"internalType\":\"uint8\",\"name\":\"\",\"type\":\"uint8\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"REFUND_CHANNEL_ID\",\"outputs\":[{\"internalType\":\"uint8\",\"name\":\"\",\"type\":\"uint8\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"RELAYERHUB_CONTRACT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"RELAYER_REWARD\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"SLASH_CONTRACT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"SYSTEM_REWARD_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"TOKEN_HUB_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"TRANSFER_IN_CHANNEL_ID\",\"outputs\":[{\"internalType\":\"uint8\",\"name\":\"\",\"type\":\"uint8\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"VALIDATOR_CONTRACT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"name\":\"_bep2SymbolToContractAddr\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"_bep2eContractDecimals\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"_bindChannelSequence\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"name\":\"_bindPackageRecord\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"bep2TokenSymbol\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"totalSupply\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"peggyAmount\",\"type\":\"uint256\"},{\"internalType\":\"uint8\",\"name\":\"bep2eDecimals\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"expireTime\",\"type\":\"uint64\"},{\"internalType\":\"uint256\",\"name\":\"relayFee\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"_bindResponseChannelSequence\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"_contractAddrToBEP2Symbol\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"_refundChannelSequence\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"_transferInChannelSequence\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"_transferInFailureChannelSequence\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"_transferOutChannelSequence\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"internalType\":\"string\",\"name\":\"bep2Symbol\",\"type\":\"string\"}],\"name\":\"approveBind\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"internalType\":\"address[]\",\"name\":\"recipientAddrs\",\"type\":\"address[]\"},{\"internalType\":\"uint256[]\",\"name\":\"amounts\",\"type\":\"uint256[]\"},{\"internalType\":\"address[]\",\"name\":\"refundAddrs\",\"type\":\"address[]\"},{\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"expireTime\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"relayFee\",\"type\":\"uint256\"}],\"name\":\"batchTransferOut\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"payable\":true,\"stateMutability\":\"payable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"internalType\":\"string\",\"name\":\"symbol\",\"type\":\"string\"}],\"name\":\"bep2TokenSymbolConvert\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"payable\":false,\"stateMutability\":\"pure\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"internalType\":\"string\",\"name\":\"bep2eSymbol\",\"type\":\"string\"},{\"internalType\":\"bytes32\",\"name\":\"bep2TokenSymbol\",\"type\":\"bytes32\"}],\"name\":\"checkSymbol\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"pure\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"bep2eTokenDecimals\",\"type\":\"uint256\"}],\"name\":\"convertToBep2Amount\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"pure\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"denominaroeHeaderRelayerSystemReward\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"internalType\":\"string\",\"name\":\"bep2Symbol\",\"type\":\"string\"}],\"name\":\"expireBind\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"internalType\":\"bytes\",\"name\":\"msgBytes\",\"type\":\"bytes\"},{\"internalType\":\"bytes\",\"name\":\"proof\",\"type\":\"bytes\"},{\"internalType\":\"uint64\",\"name\":\"height\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"packageSequence\",\"type\":\"uint64\"}],\"name\":\"handleBindPackage\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"internalType\":\"bytes\",\"name\":\"msgBytes\",\"type\":\"bytes\"},{\"internalType\":\"bytes\",\"name\":\"proof\",\"type\":\"bytes\"},{\"internalType\":\"uint64\",\"name\":\"height\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"packageSequence\",\"type\":\"uint64\"}],\"name\":\"handleRefundPackage\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"internalType\":\"bytes\",\"name\":\"msgBytes\",\"type\":\"bytes\"},{\"internalType\":\"bytes\",\"name\":\"proof\",\"type\":\"bytes\"},{\"internalType\":\"uint64\",\"name\":\"height\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"packageSequence\",\"type\":\"uint64\"}],\"name\":\"handleTransferInPackage\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"minimumRelayFee\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"moleculeHeaderRelayerSystemReward\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"refundRelayReward\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"internalType\":\"string\",\"name\":\"bep2Symbol\",\"type\":\"string\"}],\"name\":\"rejectBind\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"internalType\":\"address\",\"name\":\"contractAddr\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"recipient\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"expireTime\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"relayFee\",\"type\":\"uint256\"}],\"name\":\"transferOut\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"payable\":true,\"stateMutability\":\"payable\",\"type\":\"function\"}]"

// Tokenhub is an auto generated Go binding around an Ethereum contract.
type Tokenhub struct {
	TokenhubCaller     // Read-only binding to the contract
	TokenhubTransactor // Write-only binding to the contract
	TokenhubFilterer   // Log filterer for contract events
}

// TokenhubCaller is an auto generated read-only Go binding around an Ethereum contract.
type TokenhubCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TokenhubTransactor is an auto generated write-only Go binding around an Ethereum contract.
type TokenhubTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TokenhubFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type TokenhubFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TokenhubSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type TokenhubSession struct {
	Contract     *Tokenhub         // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// TokenhubCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type TokenhubCallerSession struct {
	Contract *TokenhubCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts   // Call options to use throughout this session
}

// TokenhubTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type TokenhubTransactorSession struct {
	Contract     *TokenhubTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts   // Transaction auth options to use throughout this session
}

// TokenhubRaw is an auto generated low-level Go binding around an Ethereum contract.
type TokenhubRaw struct {
	Contract *Tokenhub // Generic contract binding to access the raw methods on
}

// TokenhubCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type TokenhubCallerRaw struct {
	Contract *TokenhubCaller // Generic read-only contract binding to access the raw methods on
}

// TokenhubTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type TokenhubTransactorRaw struct {
	Contract *TokenhubTransactor // Generic write-only contract binding to access the raw methods on
}

// NewTokenhub creates a new instance of Tokenhub, bound to a specific deployed contract.
func NewTokenhub(address common.Address, backend bind.ContractBackend) (*Tokenhub, error) {
	contract, err := bindTokenhub(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &Tokenhub{TokenhubCaller: TokenhubCaller{contract: contract}, TokenhubTransactor: TokenhubTransactor{contract: contract}, TokenhubFilterer: TokenhubFilterer{contract: contract}}, nil
}

// NewTokenhubCaller creates a new read-only instance of Tokenhub, bound to a specific deployed contract.
func NewTokenhubCaller(address common.Address, caller bind.ContractCaller) (*TokenhubCaller, error) {
	contract, err := bindTokenhub(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &TokenhubCaller{contract: contract}, nil
}

// NewTokenhubTransactor creates a new write-only instance of Tokenhub, bound to a specific deployed contract.
func NewTokenhubTransactor(address common.Address, transactor bind.ContractTransactor) (*TokenhubTransactor, error) {
	contract, err := bindTokenhub(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &TokenhubTransactor{contract: contract}, nil
}

// NewTokenhubFilterer creates a new log filterer instance of Tokenhub, bound to a specific deployed contract.
func NewTokenhubFilterer(address common.Address, filterer bind.ContractFilterer) (*TokenhubFilterer, error) {
	contract, err := bindTokenhub(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &TokenhubFilterer{contract: contract}, nil
}

// bindTokenhub binds a generic wrapper to an already deployed contract.
func bindTokenhub(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := abi.JSON(strings.NewReader(TokenhubABI))
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Tokenhub *TokenhubRaw) Call(opts *bind.CallOpts, result interface{}, method string, params ...interface{}) error {
	return _Tokenhub.Contract.TokenhubCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Tokenhub *TokenhubRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Tokenhub.Contract.TokenhubTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Tokenhub *TokenhubRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Tokenhub.Contract.TokenhubTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Tokenhub *TokenhubCallerRaw) Call(opts *bind.CallOpts, result interface{}, method string, params ...interface{}) error {
	return _Tokenhub.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Tokenhub *TokenhubTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Tokenhub.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Tokenhub *TokenhubTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Tokenhub.Contract.contract.Transact(opts, method, params...)
}

// BEP2TOKENDECIMALS is a free data retrieval call binding the contract method 0x61368475.
//
// Solidity: function BEP2_TOKEN_DECIMALS() constant returns(uint8)
func (_Tokenhub *TokenhubCaller) BEP2TOKENDECIMALS(opts *bind.CallOpts) (uint8, error) {
	var (
		ret0 = new(uint8)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "BEP2_TOKEN_DECIMALS")
	return *ret0, err
}

// BEP2TOKENDECIMALS is a free data retrieval call binding the contract method 0x61368475.
//
// Solidity: function BEP2_TOKEN_DECIMALS() constant returns(uint8)
func (_Tokenhub *TokenhubSession) BEP2TOKENDECIMALS() (uint8, error) {
	return _Tokenhub.Contract.BEP2TOKENDECIMALS(&_Tokenhub.CallOpts)
}

// BEP2TOKENDECIMALS is a free data retrieval call binding the contract method 0x61368475.
//
// Solidity: function BEP2_TOKEN_DECIMALS() constant returns(uint8)
func (_Tokenhub *TokenhubCallerSession) BEP2TOKENDECIMALS() (uint8, error) {
	return _Tokenhub.Contract.BEP2TOKENDECIMALS(&_Tokenhub.CallOpts)
}

// BEP2TOKENSYMBOLFORBNB is a free data retrieval call binding the contract method 0xb9fd21e3.
//
// Solidity: function BEP2_TOKEN_SYMBOL_FOR_BNB() constant returns(bytes32)
func (_Tokenhub *TokenhubCaller) BEP2TOKENSYMBOLFORBNB(opts *bind.CallOpts) ([32]byte, error) {
	var (
		ret0 = new([32]byte)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "BEP2_TOKEN_SYMBOL_FOR_BNB")
	return *ret0, err
}

// BEP2TOKENSYMBOLFORBNB is a free data retrieval call binding the contract method 0xb9fd21e3.
//
// Solidity: function BEP2_TOKEN_SYMBOL_FOR_BNB() constant returns(bytes32)
func (_Tokenhub *TokenhubSession) BEP2TOKENSYMBOLFORBNB() ([32]byte, error) {
	return _Tokenhub.Contract.BEP2TOKENSYMBOLFORBNB(&_Tokenhub.CallOpts)
}

// BEP2TOKENSYMBOLFORBNB is a free data retrieval call binding the contract method 0xb9fd21e3.
//
// Solidity: function BEP2_TOKEN_SYMBOL_FOR_BNB() constant returns(bytes32)
func (_Tokenhub *TokenhubCallerSession) BEP2TOKENSYMBOLFORBNB() ([32]byte, error) {
	return _Tokenhub.Contract.BEP2TOKENSYMBOLFORBNB(&_Tokenhub.CallOpts)
}

// BINDCHANNELID is a free data retrieval call binding the contract method 0xc3dc4d9a.
//
// Solidity: function BIND_CHANNEL_ID() constant returns(uint8)
func (_Tokenhub *TokenhubCaller) BINDCHANNELID(opts *bind.CallOpts) (uint8, error) {
	var (
		ret0 = new(uint8)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "BIND_CHANNEL_ID")
	return *ret0, err
}

// BINDCHANNELID is a free data retrieval call binding the contract method 0xc3dc4d9a.
//
// Solidity: function BIND_CHANNEL_ID() constant returns(uint8)
func (_Tokenhub *TokenhubSession) BINDCHANNELID() (uint8, error) {
	return _Tokenhub.Contract.BINDCHANNELID(&_Tokenhub.CallOpts)
}

// BINDCHANNELID is a free data retrieval call binding the contract method 0xc3dc4d9a.
//
// Solidity: function BIND_CHANNEL_ID() constant returns(uint8)
func (_Tokenhub *TokenhubCallerSession) BINDCHANNELID() (uint8, error) {
	return _Tokenhub.Contract.BINDCHANNELID(&_Tokenhub.CallOpts)
}

// GOVHUBADDR is a free data retrieval call binding the contract method 0x9dc09262.
//
// Solidity: function GOV_HUB_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCaller) GOVHUBADDR(opts *bind.CallOpts) (common.Address, error) {
	var (
		ret0 = new(common.Address)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "GOV_HUB_ADDR")
	return *ret0, err
}

// GOVHUBADDR is a free data retrieval call binding the contract method 0x9dc09262.
//
// Solidity: function GOV_HUB_ADDR() constant returns(address)
func (_Tokenhub *TokenhubSession) GOVHUBADDR() (common.Address, error) {
	return _Tokenhub.Contract.GOVHUBADDR(&_Tokenhub.CallOpts)
}

// GOVHUBADDR is a free data retrieval call binding the contract method 0x9dc09262.
//
// Solidity: function GOV_HUB_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCallerSession) GOVHUBADDR() (common.Address, error) {
	return _Tokenhub.Contract.GOVHUBADDR(&_Tokenhub.CallOpts)
}

// INCENTIVIZEADDR is a free data retrieval call binding the contract method 0x6e47b482.
//
// Solidity: function INCENTIVIZE_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCaller) INCENTIVIZEADDR(opts *bind.CallOpts) (common.Address, error) {
	var (
		ret0 = new(common.Address)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "INCENTIVIZE_ADDR")
	return *ret0, err
}

// INCENTIVIZEADDR is a free data retrieval call binding the contract method 0x6e47b482.
//
// Solidity: function INCENTIVIZE_ADDR() constant returns(address)
func (_Tokenhub *TokenhubSession) INCENTIVIZEADDR() (common.Address, error) {
	return _Tokenhub.Contract.INCENTIVIZEADDR(&_Tokenhub.CallOpts)
}

// INCENTIVIZEADDR is a free data retrieval call binding the contract method 0x6e47b482.
//
// Solidity: function INCENTIVIZE_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCallerSession) INCENTIVIZEADDR() (common.Address, error) {
	return _Tokenhub.Contract.INCENTIVIZEADDR(&_Tokenhub.CallOpts)
}

// LIGHTCLIENTADDR is a free data retrieval call binding the contract method 0xdc927faf.
//
// Solidity: function LIGHT_CLIENT_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCaller) LIGHTCLIENTADDR(opts *bind.CallOpts) (common.Address, error) {
	var (
		ret0 = new(common.Address)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "LIGHT_CLIENT_ADDR")
	return *ret0, err
}

// LIGHTCLIENTADDR is a free data retrieval call binding the contract method 0xdc927faf.
//
// Solidity: function LIGHT_CLIENT_ADDR() constant returns(address)
func (_Tokenhub *TokenhubSession) LIGHTCLIENTADDR() (common.Address, error) {
	return _Tokenhub.Contract.LIGHTCLIENTADDR(&_Tokenhub.CallOpts)
}

// LIGHTCLIENTADDR is a free data retrieval call binding the contract method 0xdc927faf.
//
// Solidity: function LIGHT_CLIENT_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCallerSession) LIGHTCLIENTADDR() (common.Address, error) {
	return _Tokenhub.Contract.LIGHTCLIENTADDR(&_Tokenhub.CallOpts)
}

// MAXIMUMBEP2ESYMBOLLEN is a free data retrieval call binding the contract method 0x077b8f35.
//
// Solidity: function MAXIMUM_BEP2E_SYMBOL_LEN() constant returns(uint8)
func (_Tokenhub *TokenhubCaller) MAXIMUMBEP2ESYMBOLLEN(opts *bind.CallOpts) (uint8, error) {
	var (
		ret0 = new(uint8)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "MAXIMUM_BEP2E_SYMBOL_LEN")
	return *ret0, err
}

// MAXIMUMBEP2ESYMBOLLEN is a free data retrieval call binding the contract method 0x077b8f35.
//
// Solidity: function MAXIMUM_BEP2E_SYMBOL_LEN() constant returns(uint8)
func (_Tokenhub *TokenhubSession) MAXIMUMBEP2ESYMBOLLEN() (uint8, error) {
	return _Tokenhub.Contract.MAXIMUMBEP2ESYMBOLLEN(&_Tokenhub.CallOpts)
}

// MAXIMUMBEP2ESYMBOLLEN is a free data retrieval call binding the contract method 0x077b8f35.
//
// Solidity: function MAXIMUM_BEP2E_SYMBOL_LEN() constant returns(uint8)
func (_Tokenhub *TokenhubCallerSession) MAXIMUMBEP2ESYMBOLLEN() (uint8, error) {
	return _Tokenhub.Contract.MAXIMUMBEP2ESYMBOLLEN(&_Tokenhub.CallOpts)
}

// MAXBEP2TOTALSUPPLY is a free data retrieval call binding the contract method 0x9a854bbd.
//
// Solidity: function MAX_BEP2_TOTAL_SUPPLY() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) MAXBEP2TOTALSUPPLY(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "MAX_BEP2_TOTAL_SUPPLY")
	return *ret0, err
}

// MAXBEP2TOTALSUPPLY is a free data retrieval call binding the contract method 0x9a854bbd.
//
// Solidity: function MAX_BEP2_TOTAL_SUPPLY() constant returns(uint256)
func (_Tokenhub *TokenhubSession) MAXBEP2TOTALSUPPLY() (*big.Int, error) {
	return _Tokenhub.Contract.MAXBEP2TOTALSUPPLY(&_Tokenhub.CallOpts)
}

// MAXBEP2TOTALSUPPLY is a free data retrieval call binding the contract method 0x9a854bbd.
//
// Solidity: function MAX_BEP2_TOTAL_SUPPLY() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) MAXBEP2TOTALSUPPLY() (*big.Int, error) {
	return _Tokenhub.Contract.MAXBEP2TOTALSUPPLY(&_Tokenhub.CallOpts)
}

// MAXGASFORCALLINGBEP2E is a free data retrieval call binding the contract method 0xb7701861.
//
// Solidity: function MAX_GAS_FOR_CALLING_BEP2E() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) MAXGASFORCALLINGBEP2E(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "MAX_GAS_FOR_CALLING_BEP2E")
	return *ret0, err
}

// MAXGASFORCALLINGBEP2E is a free data retrieval call binding the contract method 0xb7701861.
//
// Solidity: function MAX_GAS_FOR_CALLING_BEP2E() constant returns(uint256)
func (_Tokenhub *TokenhubSession) MAXGASFORCALLINGBEP2E() (*big.Int, error) {
	return _Tokenhub.Contract.MAXGASFORCALLINGBEP2E(&_Tokenhub.CallOpts)
}

// MAXGASFORCALLINGBEP2E is a free data retrieval call binding the contract method 0xb7701861.
//
// Solidity: function MAX_GAS_FOR_CALLING_BEP2E() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) MAXGASFORCALLINGBEP2E() (*big.Int, error) {
	return _Tokenhub.Contract.MAXGASFORCALLINGBEP2E(&_Tokenhub.CallOpts)
}

// MINIMUMBEP2ESYMBOLLEN is a free data retrieval call binding the contract method 0xdc6f5e90.
//
// Solidity: function MINIMUM_BEP2E_SYMBOL_LEN() constant returns(uint8)
func (_Tokenhub *TokenhubCaller) MINIMUMBEP2ESYMBOLLEN(opts *bind.CallOpts) (uint8, error) {
	var (
		ret0 = new(uint8)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "MINIMUM_BEP2E_SYMBOL_LEN")
	return *ret0, err
}

// MINIMUMBEP2ESYMBOLLEN is a free data retrieval call binding the contract method 0xdc6f5e90.
//
// Solidity: function MINIMUM_BEP2E_SYMBOL_LEN() constant returns(uint8)
func (_Tokenhub *TokenhubSession) MINIMUMBEP2ESYMBOLLEN() (uint8, error) {
	return _Tokenhub.Contract.MINIMUMBEP2ESYMBOLLEN(&_Tokenhub.CallOpts)
}

// MINIMUMBEP2ESYMBOLLEN is a free data retrieval call binding the contract method 0xdc6f5e90.
//
// Solidity: function MINIMUM_BEP2E_SYMBOL_LEN() constant returns(uint8)
func (_Tokenhub *TokenhubCallerSession) MINIMUMBEP2ESYMBOLLEN() (uint8, error) {
	return _Tokenhub.Contract.MINIMUMBEP2ESYMBOLLEN(&_Tokenhub.CallOpts)
}

// REFUNDCHANNELID is a free data retrieval call binding the contract method 0x6bc2ecdb.
//
// Solidity: function REFUND_CHANNEL_ID() constant returns(uint8)
func (_Tokenhub *TokenhubCaller) REFUNDCHANNELID(opts *bind.CallOpts) (uint8, error) {
	var (
		ret0 = new(uint8)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "REFUND_CHANNEL_ID")
	return *ret0, err
}

// REFUNDCHANNELID is a free data retrieval call binding the contract method 0x6bc2ecdb.
//
// Solidity: function REFUND_CHANNEL_ID() constant returns(uint8)
func (_Tokenhub *TokenhubSession) REFUNDCHANNELID() (uint8, error) {
	return _Tokenhub.Contract.REFUNDCHANNELID(&_Tokenhub.CallOpts)
}

// REFUNDCHANNELID is a free data retrieval call binding the contract method 0x6bc2ecdb.
//
// Solidity: function REFUND_CHANNEL_ID() constant returns(uint8)
func (_Tokenhub *TokenhubCallerSession) REFUNDCHANNELID() (uint8, error) {
	return _Tokenhub.Contract.REFUNDCHANNELID(&_Tokenhub.CallOpts)
}

// RELAYERHUBCONTRACTADDR is a free data retrieval call binding the contract method 0xa1a11bf5.
//
// Solidity: function RELAYERHUB_CONTRACT_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCaller) RELAYERHUBCONTRACTADDR(opts *bind.CallOpts) (common.Address, error) {
	var (
		ret0 = new(common.Address)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "RELAYERHUB_CONTRACT_ADDR")
	return *ret0, err
}

// RELAYERHUBCONTRACTADDR is a free data retrieval call binding the contract method 0xa1a11bf5.
//
// Solidity: function RELAYERHUB_CONTRACT_ADDR() constant returns(address)
func (_Tokenhub *TokenhubSession) RELAYERHUBCONTRACTADDR() (common.Address, error) {
	return _Tokenhub.Contract.RELAYERHUBCONTRACTADDR(&_Tokenhub.CallOpts)
}

// RELAYERHUBCONTRACTADDR is a free data retrieval call binding the contract method 0xa1a11bf5.
//
// Solidity: function RELAYERHUB_CONTRACT_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCallerSession) RELAYERHUBCONTRACTADDR() (common.Address, error) {
	return _Tokenhub.Contract.RELAYERHUBCONTRACTADDR(&_Tokenhub.CallOpts)
}

// RELAYERREWARD is a free data retrieval call binding the contract method 0x75405d0d.
//
// Solidity: function RELAYER_REWARD() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) RELAYERREWARD(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "RELAYER_REWARD")
	return *ret0, err
}

// RELAYERREWARD is a free data retrieval call binding the contract method 0x75405d0d.
//
// Solidity: function RELAYER_REWARD() constant returns(uint256)
func (_Tokenhub *TokenhubSession) RELAYERREWARD() (*big.Int, error) {
	return _Tokenhub.Contract.RELAYERREWARD(&_Tokenhub.CallOpts)
}

// RELAYERREWARD is a free data retrieval call binding the contract method 0x75405d0d.
//
// Solidity: function RELAYER_REWARD() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) RELAYERREWARD() (*big.Int, error) {
	return _Tokenhub.Contract.RELAYERREWARD(&_Tokenhub.CallOpts)
}

// SLASHCONTRACTADDR is a free data retrieval call binding the contract method 0x43756e5c.
//
// Solidity: function SLASH_CONTRACT_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCaller) SLASHCONTRACTADDR(opts *bind.CallOpts) (common.Address, error) {
	var (
		ret0 = new(common.Address)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "SLASH_CONTRACT_ADDR")
	return *ret0, err
}

// SLASHCONTRACTADDR is a free data retrieval call binding the contract method 0x43756e5c.
//
// Solidity: function SLASH_CONTRACT_ADDR() constant returns(address)
func (_Tokenhub *TokenhubSession) SLASHCONTRACTADDR() (common.Address, error) {
	return _Tokenhub.Contract.SLASHCONTRACTADDR(&_Tokenhub.CallOpts)
}

// SLASHCONTRACTADDR is a free data retrieval call binding the contract method 0x43756e5c.
//
// Solidity: function SLASH_CONTRACT_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCallerSession) SLASHCONTRACTADDR() (common.Address, error) {
	return _Tokenhub.Contract.SLASHCONTRACTADDR(&_Tokenhub.CallOpts)
}

// SYSTEMREWARDADDR is a free data retrieval call binding the contract method 0xc81b1662.
//
// Solidity: function SYSTEM_REWARD_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCaller) SYSTEMREWARDADDR(opts *bind.CallOpts) (common.Address, error) {
	var (
		ret0 = new(common.Address)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "SYSTEM_REWARD_ADDR")
	return *ret0, err
}

// SYSTEMREWARDADDR is a free data retrieval call binding the contract method 0xc81b1662.
//
// Solidity: function SYSTEM_REWARD_ADDR() constant returns(address)
func (_Tokenhub *TokenhubSession) SYSTEMREWARDADDR() (common.Address, error) {
	return _Tokenhub.Contract.SYSTEMREWARDADDR(&_Tokenhub.CallOpts)
}

// SYSTEMREWARDADDR is a free data retrieval call binding the contract method 0xc81b1662.
//
// Solidity: function SYSTEM_REWARD_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCallerSession) SYSTEMREWARDADDR() (common.Address, error) {
	return _Tokenhub.Contract.SYSTEMREWARDADDR(&_Tokenhub.CallOpts)
}

// TOKENHUBADDR is a free data retrieval call binding the contract method 0xfd6a6879.
//
// Solidity: function TOKEN_HUB_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCaller) TOKENHUBADDR(opts *bind.CallOpts) (common.Address, error) {
	var (
		ret0 = new(common.Address)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "TOKEN_HUB_ADDR")
	return *ret0, err
}

// TOKENHUBADDR is a free data retrieval call binding the contract method 0xfd6a6879.
//
// Solidity: function TOKEN_HUB_ADDR() constant returns(address)
func (_Tokenhub *TokenhubSession) TOKENHUBADDR() (common.Address, error) {
	return _Tokenhub.Contract.TOKENHUBADDR(&_Tokenhub.CallOpts)
}

// TOKENHUBADDR is a free data retrieval call binding the contract method 0xfd6a6879.
//
// Solidity: function TOKEN_HUB_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCallerSession) TOKENHUBADDR() (common.Address, error) {
	return _Tokenhub.Contract.TOKENHUBADDR(&_Tokenhub.CallOpts)
}

// TRANSFERINCHANNELID is a free data retrieval call binding the contract method 0xcc12eabc.
//
// Solidity: function TRANSFER_IN_CHANNEL_ID() constant returns(uint8)
func (_Tokenhub *TokenhubCaller) TRANSFERINCHANNELID(opts *bind.CallOpts) (uint8, error) {
	var (
		ret0 = new(uint8)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "TRANSFER_IN_CHANNEL_ID")
	return *ret0, err
}

// TRANSFERINCHANNELID is a free data retrieval call binding the contract method 0xcc12eabc.
//
// Solidity: function TRANSFER_IN_CHANNEL_ID() constant returns(uint8)
func (_Tokenhub *TokenhubSession) TRANSFERINCHANNELID() (uint8, error) {
	return _Tokenhub.Contract.TRANSFERINCHANNELID(&_Tokenhub.CallOpts)
}

// TRANSFERINCHANNELID is a free data retrieval call binding the contract method 0xcc12eabc.
//
// Solidity: function TRANSFER_IN_CHANNEL_ID() constant returns(uint8)
func (_Tokenhub *TokenhubCallerSession) TRANSFERINCHANNELID() (uint8, error) {
	return _Tokenhub.Contract.TRANSFERINCHANNELID(&_Tokenhub.CallOpts)
}

// VALIDATORCONTRACTADDR is a free data retrieval call binding the contract method 0xf9a2bbc7.
//
// Solidity: function VALIDATOR_CONTRACT_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCaller) VALIDATORCONTRACTADDR(opts *bind.CallOpts) (common.Address, error) {
	var (
		ret0 = new(common.Address)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "VALIDATOR_CONTRACT_ADDR")
	return *ret0, err
}

// VALIDATORCONTRACTADDR is a free data retrieval call binding the contract method 0xf9a2bbc7.
//
// Solidity: function VALIDATOR_CONTRACT_ADDR() constant returns(address)
func (_Tokenhub *TokenhubSession) VALIDATORCONTRACTADDR() (common.Address, error) {
	return _Tokenhub.Contract.VALIDATORCONTRACTADDR(&_Tokenhub.CallOpts)
}

// VALIDATORCONTRACTADDR is a free data retrieval call binding the contract method 0xf9a2bbc7.
//
// Solidity: function VALIDATOR_CONTRACT_ADDR() constant returns(address)
func (_Tokenhub *TokenhubCallerSession) VALIDATORCONTRACTADDR() (common.Address, error) {
	return _Tokenhub.Contract.VALIDATORCONTRACTADDR(&_Tokenhub.CallOpts)
}

// Bep2SymbolToContractAddr is a free data retrieval call binding the contract method 0x66be7945.
//
// Solidity: function _bep2SymbolToContractAddr(bytes32 ) constant returns(address)
func (_Tokenhub *TokenhubCaller) Bep2SymbolToContractAddr(opts *bind.CallOpts, arg0 [32]byte) (common.Address, error) {
	var (
		ret0 = new(common.Address)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "_bep2SymbolToContractAddr", arg0)
	return *ret0, err
}

// Bep2SymbolToContractAddr is a free data retrieval call binding the contract method 0x66be7945.
//
// Solidity: function _bep2SymbolToContractAddr(bytes32 ) constant returns(address)
func (_Tokenhub *TokenhubSession) Bep2SymbolToContractAddr(arg0 [32]byte) (common.Address, error) {
	return _Tokenhub.Contract.Bep2SymbolToContractAddr(&_Tokenhub.CallOpts, arg0)
}

// Bep2SymbolToContractAddr is a free data retrieval call binding the contract method 0x66be7945.
//
// Solidity: function _bep2SymbolToContractAddr(bytes32 ) constant returns(address)
func (_Tokenhub *TokenhubCallerSession) Bep2SymbolToContractAddr(arg0 [32]byte) (common.Address, error) {
	return _Tokenhub.Contract.Bep2SymbolToContractAddr(&_Tokenhub.CallOpts, arg0)
}

// Bep2eContractDecimals is a free data retrieval call binding the contract method 0x7f6a7a9e.
//
// Solidity: function _bep2eContractDecimals(address ) constant returns(uint256)
func (_Tokenhub *TokenhubCaller) Bep2eContractDecimals(opts *bind.CallOpts, arg0 common.Address) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "_bep2eContractDecimals", arg0)
	return *ret0, err
}

// Bep2eContractDecimals is a free data retrieval call binding the contract method 0x7f6a7a9e.
//
// Solidity: function _bep2eContractDecimals(address ) constant returns(uint256)
func (_Tokenhub *TokenhubSession) Bep2eContractDecimals(arg0 common.Address) (*big.Int, error) {
	return _Tokenhub.Contract.Bep2eContractDecimals(&_Tokenhub.CallOpts, arg0)
}

// Bep2eContractDecimals is a free data retrieval call binding the contract method 0x7f6a7a9e.
//
// Solidity: function _bep2eContractDecimals(address ) constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) Bep2eContractDecimals(arg0 common.Address) (*big.Int, error) {
	return _Tokenhub.Contract.Bep2eContractDecimals(&_Tokenhub.CallOpts, arg0)
}

// BindChannelSequence is a free data retrieval call binding the contract method 0xd891ccb2.
//
// Solidity: function _bindChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubCaller) BindChannelSequence(opts *bind.CallOpts) (uint64, error) {
	var (
		ret0 = new(uint64)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "_bindChannelSequence")
	return *ret0, err
}

// BindChannelSequence is a free data retrieval call binding the contract method 0xd891ccb2.
//
// Solidity: function _bindChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubSession) BindChannelSequence() (uint64, error) {
	return _Tokenhub.Contract.BindChannelSequence(&_Tokenhub.CallOpts)
}

// BindChannelSequence is a free data retrieval call binding the contract method 0xd891ccb2.
//
// Solidity: function _bindChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubCallerSession) BindChannelSequence() (uint64, error) {
	return _Tokenhub.Contract.BindChannelSequence(&_Tokenhub.CallOpts)
}

// BindPackageRecord is a free data retrieval call binding the contract method 0xdf014119.
//
// Solidity: function _bindPackageRecord(bytes32 ) constant returns(bytes32 bep2TokenSymbol, address contractAddr, uint256 totalSupply, uint256 peggyAmount, uint8 bep2eDecimals, uint64 expireTime, uint256 relayFee)
func (_Tokenhub *TokenhubCaller) BindPackageRecord(opts *bind.CallOpts, arg0 [32]byte) (struct {
	Bep2TokenSymbol [32]byte
	ContractAddr    common.Address
	TotalSupply     *big.Int
	PeggyAmount     *big.Int
	Bep2eDecimals   uint8
	ExpireTime      uint64
	RelayFee        *big.Int
}, error) {
	ret := new(struct {
		Bep2TokenSymbol [32]byte
		ContractAddr    common.Address
		TotalSupply     *big.Int
		PeggyAmount     *big.Int
		Bep2eDecimals   uint8
		ExpireTime      uint64
		RelayFee        *big.Int
	})
	out := ret
	err := _Tokenhub.contract.Call(opts, out, "_bindPackageRecord", arg0)
	return *ret, err
}

// BindPackageRecord is a free data retrieval call binding the contract method 0xdf014119.
//
// Solidity: function _bindPackageRecord(bytes32 ) constant returns(bytes32 bep2TokenSymbol, address contractAddr, uint256 totalSupply, uint256 peggyAmount, uint8 bep2eDecimals, uint64 expireTime, uint256 relayFee)
func (_Tokenhub *TokenhubSession) BindPackageRecord(arg0 [32]byte) (struct {
	Bep2TokenSymbol [32]byte
	ContractAddr    common.Address
	TotalSupply     *big.Int
	PeggyAmount     *big.Int
	Bep2eDecimals   uint8
	ExpireTime      uint64
	RelayFee        *big.Int
}, error) {
	return _Tokenhub.Contract.BindPackageRecord(&_Tokenhub.CallOpts, arg0)
}

// BindPackageRecord is a free data retrieval call binding the contract method 0xdf014119.
//
// Solidity: function _bindPackageRecord(bytes32 ) constant returns(bytes32 bep2TokenSymbol, address contractAddr, uint256 totalSupply, uint256 peggyAmount, uint8 bep2eDecimals, uint64 expireTime, uint256 relayFee)
func (_Tokenhub *TokenhubCallerSession) BindPackageRecord(arg0 [32]byte) (struct {
	Bep2TokenSymbol [32]byte
	ContractAddr    common.Address
	TotalSupply     *big.Int
	PeggyAmount     *big.Int
	Bep2eDecimals   uint8
	ExpireTime      uint64
	RelayFee        *big.Int
}, error) {
	return _Tokenhub.Contract.BindPackageRecord(&_Tokenhub.CallOpts, arg0)
}

// BindResponseChannelSequence is a free data retrieval call binding the contract method 0x716c9dd5.
//
// Solidity: function _bindResponseChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubCaller) BindResponseChannelSequence(opts *bind.CallOpts) (uint64, error) {
	var (
		ret0 = new(uint64)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "_bindResponseChannelSequence")
	return *ret0, err
}

// BindResponseChannelSequence is a free data retrieval call binding the contract method 0x716c9dd5.
//
// Solidity: function _bindResponseChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubSession) BindResponseChannelSequence() (uint64, error) {
	return _Tokenhub.Contract.BindResponseChannelSequence(&_Tokenhub.CallOpts)
}

// BindResponseChannelSequence is a free data retrieval call binding the contract method 0x716c9dd5.
//
// Solidity: function _bindResponseChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubCallerSession) BindResponseChannelSequence() (uint64, error) {
	return _Tokenhub.Contract.BindResponseChannelSequence(&_Tokenhub.CallOpts)
}

// ContractAddrToBEP2Symbol is a free data retrieval call binding the contract method 0x9710e7f6.
//
// Solidity: function _contractAddrToBEP2Symbol(address ) constant returns(bytes32)
func (_Tokenhub *TokenhubCaller) ContractAddrToBEP2Symbol(opts *bind.CallOpts, arg0 common.Address) ([32]byte, error) {
	var (
		ret0 = new([32]byte)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "_contractAddrToBEP2Symbol", arg0)
	return *ret0, err
}

// ContractAddrToBEP2Symbol is a free data retrieval call binding the contract method 0x9710e7f6.
//
// Solidity: function _contractAddrToBEP2Symbol(address ) constant returns(bytes32)
func (_Tokenhub *TokenhubSession) ContractAddrToBEP2Symbol(arg0 common.Address) ([32]byte, error) {
	return _Tokenhub.Contract.ContractAddrToBEP2Symbol(&_Tokenhub.CallOpts, arg0)
}

// ContractAddrToBEP2Symbol is a free data retrieval call binding the contract method 0x9710e7f6.
//
// Solidity: function _contractAddrToBEP2Symbol(address ) constant returns(bytes32)
func (_Tokenhub *TokenhubCallerSession) ContractAddrToBEP2Symbol(arg0 common.Address) ([32]byte, error) {
	return _Tokenhub.Contract.ContractAddrToBEP2Symbol(&_Tokenhub.CallOpts, arg0)
}

// RefundChannelSequence is a free data retrieval call binding the contract method 0x4e4a70e6.
//
// Solidity: function _refundChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubCaller) RefundChannelSequence(opts *bind.CallOpts) (uint64, error) {
	var (
		ret0 = new(uint64)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "_refundChannelSequence")
	return *ret0, err
}

// RefundChannelSequence is a free data retrieval call binding the contract method 0x4e4a70e6.
//
// Solidity: function _refundChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubSession) RefundChannelSequence() (uint64, error) {
	return _Tokenhub.Contract.RefundChannelSequence(&_Tokenhub.CallOpts)
}

// RefundChannelSequence is a free data retrieval call binding the contract method 0x4e4a70e6.
//
// Solidity: function _refundChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubCallerSession) RefundChannelSequence() (uint64, error) {
	return _Tokenhub.Contract.RefundChannelSequence(&_Tokenhub.CallOpts)
}

// TransferInChannelSequence is a free data retrieval call binding the contract method 0xdac3f64f.
//
// Solidity: function _transferInChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubCaller) TransferInChannelSequence(opts *bind.CallOpts) (uint64, error) {
	var (
		ret0 = new(uint64)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "_transferInChannelSequence")
	return *ret0, err
}

// TransferInChannelSequence is a free data retrieval call binding the contract method 0xdac3f64f.
//
// Solidity: function _transferInChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubSession) TransferInChannelSequence() (uint64, error) {
	return _Tokenhub.Contract.TransferInChannelSequence(&_Tokenhub.CallOpts)
}

// TransferInChannelSequence is a free data retrieval call binding the contract method 0xdac3f64f.
//
// Solidity: function _transferInChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubCallerSession) TransferInChannelSequence() (uint64, error) {
	return _Tokenhub.Contract.TransferInChannelSequence(&_Tokenhub.CallOpts)
}

// TransferInFailureChannelSequence is a free data retrieval call binding the contract method 0x5da9b1f2.
//
// Solidity: function _transferInFailureChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubCaller) TransferInFailureChannelSequence(opts *bind.CallOpts) (uint64, error) {
	var (
		ret0 = new(uint64)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "_transferInFailureChannelSequence")
	return *ret0, err
}

// TransferInFailureChannelSequence is a free data retrieval call binding the contract method 0x5da9b1f2.
//
// Solidity: function _transferInFailureChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubSession) TransferInFailureChannelSequence() (uint64, error) {
	return _Tokenhub.Contract.TransferInFailureChannelSequence(&_Tokenhub.CallOpts)
}

// TransferInFailureChannelSequence is a free data retrieval call binding the contract method 0x5da9b1f2.
//
// Solidity: function _transferInFailureChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubCallerSession) TransferInFailureChannelSequence() (uint64, error) {
	return _Tokenhub.Contract.TransferInFailureChannelSequence(&_Tokenhub.CallOpts)
}

// TransferOutChannelSequence is a free data retrieval call binding the contract method 0xbd038949.
//
// Solidity: function _transferOutChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubCaller) TransferOutChannelSequence(opts *bind.CallOpts) (uint64, error) {
	var (
		ret0 = new(uint64)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "_transferOutChannelSequence")
	return *ret0, err
}

// TransferOutChannelSequence is a free data retrieval call binding the contract method 0xbd038949.
//
// Solidity: function _transferOutChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubSession) TransferOutChannelSequence() (uint64, error) {
	return _Tokenhub.Contract.TransferOutChannelSequence(&_Tokenhub.CallOpts)
}

// TransferOutChannelSequence is a free data retrieval call binding the contract method 0xbd038949.
//
// Solidity: function _transferOutChannelSequence() constant returns(uint64)
func (_Tokenhub *TokenhubCallerSession) TransferOutChannelSequence() (uint64, error) {
	return _Tokenhub.Contract.TransferOutChannelSequence(&_Tokenhub.CallOpts)
}

// Bep2TokenSymbolConvert is a free data retrieval call binding the contract method 0xe1063635.
//
// Solidity: function bep2TokenSymbolConvert(string symbol) constant returns(bytes32)
func (_Tokenhub *TokenhubCaller) Bep2TokenSymbolConvert(opts *bind.CallOpts, symbol string) ([32]byte, error) {
	var (
		ret0 = new([32]byte)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "bep2TokenSymbolConvert", symbol)
	return *ret0, err
}

// Bep2TokenSymbolConvert is a free data retrieval call binding the contract method 0xe1063635.
//
// Solidity: function bep2TokenSymbolConvert(string symbol) constant returns(bytes32)
func (_Tokenhub *TokenhubSession) Bep2TokenSymbolConvert(symbol string) ([32]byte, error) {
	return _Tokenhub.Contract.Bep2TokenSymbolConvert(&_Tokenhub.CallOpts, symbol)
}

// Bep2TokenSymbolConvert is a free data retrieval call binding the contract method 0xe1063635.
//
// Solidity: function bep2TokenSymbolConvert(string symbol) constant returns(bytes32)
func (_Tokenhub *TokenhubCallerSession) Bep2TokenSymbolConvert(symbol string) ([32]byte, error) {
	return _Tokenhub.Contract.Bep2TokenSymbolConvert(&_Tokenhub.CallOpts, symbol)
}

// CheckSymbol is a free data retrieval call binding the contract method 0xf5d31519.
//
// Solidity: function checkSymbol(string bep2eSymbol, bytes32 bep2TokenSymbol) constant returns(bool)
func (_Tokenhub *TokenhubCaller) CheckSymbol(opts *bind.CallOpts, bep2eSymbol string, bep2TokenSymbol [32]byte) (bool, error) {
	var (
		ret0 = new(bool)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "checkSymbol", bep2eSymbol, bep2TokenSymbol)
	return *ret0, err
}

// CheckSymbol is a free data retrieval call binding the contract method 0xf5d31519.
//
// Solidity: function checkSymbol(string bep2eSymbol, bytes32 bep2TokenSymbol) constant returns(bool)
func (_Tokenhub *TokenhubSession) CheckSymbol(bep2eSymbol string, bep2TokenSymbol [32]byte) (bool, error) {
	return _Tokenhub.Contract.CheckSymbol(&_Tokenhub.CallOpts, bep2eSymbol, bep2TokenSymbol)
}

// CheckSymbol is a free data retrieval call binding the contract method 0xf5d31519.
//
// Solidity: function checkSymbol(string bep2eSymbol, bytes32 bep2TokenSymbol) constant returns(bool)
func (_Tokenhub *TokenhubCallerSession) CheckSymbol(bep2eSymbol string, bep2TokenSymbol [32]byte) (bool, error) {
	return _Tokenhub.Contract.CheckSymbol(&_Tokenhub.CallOpts, bep2eSymbol, bep2TokenSymbol)
}

// ConvertToBep2Amount is a free data retrieval call binding the contract method 0xd398809b.
//
// Solidity: function convertToBep2Amount(uint256 amount, uint256 bep2eTokenDecimals) constant returns(uint256)
func (_Tokenhub *TokenhubCaller) ConvertToBep2Amount(opts *bind.CallOpts, amount *big.Int, bep2eTokenDecimals *big.Int) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "convertToBep2Amount", amount, bep2eTokenDecimals)
	return *ret0, err
}

// ConvertToBep2Amount is a free data retrieval call binding the contract method 0xd398809b.
//
// Solidity: function convertToBep2Amount(uint256 amount, uint256 bep2eTokenDecimals) constant returns(uint256)
func (_Tokenhub *TokenhubSession) ConvertToBep2Amount(amount *big.Int, bep2eTokenDecimals *big.Int) (*big.Int, error) {
	return _Tokenhub.Contract.ConvertToBep2Amount(&_Tokenhub.CallOpts, amount, bep2eTokenDecimals)
}

// ConvertToBep2Amount is a free data retrieval call binding the contract method 0xd398809b.
//
// Solidity: function convertToBep2Amount(uint256 amount, uint256 bep2eTokenDecimals) constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) ConvertToBep2Amount(amount *big.Int, bep2eTokenDecimals *big.Int) (*big.Int, error) {
	return _Tokenhub.Contract.ConvertToBep2Amount(&_Tokenhub.CallOpts, amount, bep2eTokenDecimals)
}

// DenominaroeHeaderRelayerSystemReward is a free data retrieval call binding the contract method 0x7194c967.
//
// Solidity: function denominaroeHeaderRelayerSystemReward() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) DenominaroeHeaderRelayerSystemReward(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "denominaroeHeaderRelayerSystemReward")
	return *ret0, err
}

// DenominaroeHeaderRelayerSystemReward is a free data retrieval call binding the contract method 0x7194c967.
//
// Solidity: function denominaroeHeaderRelayerSystemReward() constant returns(uint256)
func (_Tokenhub *TokenhubSession) DenominaroeHeaderRelayerSystemReward() (*big.Int, error) {
	return _Tokenhub.Contract.DenominaroeHeaderRelayerSystemReward(&_Tokenhub.CallOpts)
}

// DenominaroeHeaderRelayerSystemReward is a free data retrieval call binding the contract method 0x7194c967.
//
// Solidity: function denominaroeHeaderRelayerSystemReward() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) DenominaroeHeaderRelayerSystemReward() (*big.Int, error) {
	return _Tokenhub.Contract.DenominaroeHeaderRelayerSystemReward(&_Tokenhub.CallOpts)
}

// MinimumRelayFee is a free data retrieval call binding the contract method 0xaae2768c.
//
// Solidity: function minimumRelayFee() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) MinimumRelayFee(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "minimumRelayFee")
	return *ret0, err
}

// MinimumRelayFee is a free data retrieval call binding the contract method 0xaae2768c.
//
// Solidity: function minimumRelayFee() constant returns(uint256)
func (_Tokenhub *TokenhubSession) MinimumRelayFee() (*big.Int, error) {
	return _Tokenhub.Contract.MinimumRelayFee(&_Tokenhub.CallOpts)
}

// MinimumRelayFee is a free data retrieval call binding the contract method 0xaae2768c.
//
// Solidity: function minimumRelayFee() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) MinimumRelayFee() (*big.Int, error) {
	return _Tokenhub.Contract.MinimumRelayFee(&_Tokenhub.CallOpts)
}

// MoleculeHeaderRelayerSystemReward is a free data retrieval call binding the contract method 0x6fd31f81.
//
// Solidity: function moleculeHeaderRelayerSystemReward() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) MoleculeHeaderRelayerSystemReward(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "moleculeHeaderRelayerSystemReward")
	return *ret0, err
}

// MoleculeHeaderRelayerSystemReward is a free data retrieval call binding the contract method 0x6fd31f81.
//
// Solidity: function moleculeHeaderRelayerSystemReward() constant returns(uint256)
func (_Tokenhub *TokenhubSession) MoleculeHeaderRelayerSystemReward() (*big.Int, error) {
	return _Tokenhub.Contract.MoleculeHeaderRelayerSystemReward(&_Tokenhub.CallOpts)
}

// MoleculeHeaderRelayerSystemReward is a free data retrieval call binding the contract method 0x6fd31f81.
//
// Solidity: function moleculeHeaderRelayerSystemReward() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) MoleculeHeaderRelayerSystemReward() (*big.Int, error) {
	return _Tokenhub.Contract.MoleculeHeaderRelayerSystemReward(&_Tokenhub.CallOpts)
}

// RefundRelayReward is a free data retrieval call binding the contract method 0x14e68d82.
//
// Solidity: function refundRelayReward() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) RefundRelayReward(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "refundRelayReward")
	return *ret0, err
}

// RefundRelayReward is a free data retrieval call binding the contract method 0x14e68d82.
//
// Solidity: function refundRelayReward() constant returns(uint256)
func (_Tokenhub *TokenhubSession) RefundRelayReward() (*big.Int, error) {
	return _Tokenhub.Contract.RefundRelayReward(&_Tokenhub.CallOpts)
}

// RefundRelayReward is a free data retrieval call binding the contract method 0x14e68d82.
//
// Solidity: function refundRelayReward() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) RefundRelayReward() (*big.Int, error) {
	return _Tokenhub.Contract.RefundRelayReward(&_Tokenhub.CallOpts)
}

// ApproveBind is a paid mutator transaction binding the contract method 0x6b3f1307.
//
// Solidity: function approveBind(address contractAddr, string bep2Symbol) returns(bool)
func (_Tokenhub *TokenhubTransactor) ApproveBind(opts *bind.TransactOpts, contractAddr common.Address, bep2Symbol string) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "approveBind", contractAddr, bep2Symbol)
}

// ApproveBind is a paid mutator transaction binding the contract method 0x6b3f1307.
//
// Solidity: function approveBind(address contractAddr, string bep2Symbol) returns(bool)
func (_Tokenhub *TokenhubSession) ApproveBind(contractAddr common.Address, bep2Symbol string) (*types.Transaction, error) {
	return _Tokenhub.Contract.ApproveBind(&_Tokenhub.TransactOpts, contractAddr, bep2Symbol)
}

// ApproveBind is a paid mutator transaction binding the contract method 0x6b3f1307.
//
// Solidity: function approveBind(address contractAddr, string bep2Symbol) returns(bool)
func (_Tokenhub *TokenhubTransactorSession) ApproveBind(contractAddr common.Address, bep2Symbol string) (*types.Transaction, error) {
	return _Tokenhub.Contract.ApproveBind(&_Tokenhub.TransactOpts, contractAddr, bep2Symbol)
}

// BatchTransferOut is a paid mutator transaction binding the contract method 0x053799cf.
//
// Solidity: function batchTransferOut(address[] recipientAddrs, uint256[] amounts, address[] refundAddrs, address contractAddr, uint256 expireTime, uint256 relayFee) returns(bool)
func (_Tokenhub *TokenhubTransactor) BatchTransferOut(opts *bind.TransactOpts, recipientAddrs []common.Address, amounts []*big.Int, refundAddrs []common.Address, contractAddr common.Address, expireTime *big.Int, relayFee *big.Int) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "batchTransferOut", recipientAddrs, amounts, refundAddrs, contractAddr, expireTime, relayFee)
}

// BatchTransferOut is a paid mutator transaction binding the contract method 0x053799cf.
//
// Solidity: function batchTransferOut(address[] recipientAddrs, uint256[] amounts, address[] refundAddrs, address contractAddr, uint256 expireTime, uint256 relayFee) returns(bool)
func (_Tokenhub *TokenhubSession) BatchTransferOut(recipientAddrs []common.Address, amounts []*big.Int, refundAddrs []common.Address, contractAddr common.Address, expireTime *big.Int, relayFee *big.Int) (*types.Transaction, error) {
	return _Tokenhub.Contract.BatchTransferOut(&_Tokenhub.TransactOpts, recipientAddrs, amounts, refundAddrs, contractAddr, expireTime, relayFee)
}

// BatchTransferOut is a paid mutator transaction binding the contract method 0x053799cf.
//
// Solidity: function batchTransferOut(address[] recipientAddrs, uint256[] amounts, address[] refundAddrs, address contractAddr, uint256 expireTime, uint256 relayFee) returns(bool)
func (_Tokenhub *TokenhubTransactorSession) BatchTransferOut(recipientAddrs []common.Address, amounts []*big.Int, refundAddrs []common.Address, contractAddr common.Address, expireTime *big.Int, relayFee *big.Int) (*types.Transaction, error) {
	return _Tokenhub.Contract.BatchTransferOut(&_Tokenhub.TransactOpts, recipientAddrs, amounts, refundAddrs, contractAddr, expireTime, relayFee)
}

// ExpireBind is a paid mutator transaction binding the contract method 0x72c4e086.
//
// Solidity: function expireBind(string bep2Symbol) returns(bool)
func (_Tokenhub *TokenhubTransactor) ExpireBind(opts *bind.TransactOpts, bep2Symbol string) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "expireBind", bep2Symbol)
}

// ExpireBind is a paid mutator transaction binding the contract method 0x72c4e086.
//
// Solidity: function expireBind(string bep2Symbol) returns(bool)
func (_Tokenhub *TokenhubSession) ExpireBind(bep2Symbol string) (*types.Transaction, error) {
	return _Tokenhub.Contract.ExpireBind(&_Tokenhub.TransactOpts, bep2Symbol)
}

// ExpireBind is a paid mutator transaction binding the contract method 0x72c4e086.
//
// Solidity: function expireBind(string bep2Symbol) returns(bool)
func (_Tokenhub *TokenhubTransactorSession) ExpireBind(bep2Symbol string) (*types.Transaction, error) {
	return _Tokenhub.Contract.ExpireBind(&_Tokenhub.TransactOpts, bep2Symbol)
}

// HandleBindPackage is a paid mutator transaction binding the contract method 0x2eb881b0.
//
// Solidity: function handleBindPackage(bytes msgBytes, bytes proof, uint64 height, uint64 packageSequence) returns(bool)
func (_Tokenhub *TokenhubTransactor) HandleBindPackage(opts *bind.TransactOpts, msgBytes []byte, proof []byte, height uint64, packageSequence uint64) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "handleBindPackage", msgBytes, proof, height, packageSequence)
}

// HandleBindPackage is a paid mutator transaction binding the contract method 0x2eb881b0.
//
// Solidity: function handleBindPackage(bytes msgBytes, bytes proof, uint64 height, uint64 packageSequence) returns(bool)
func (_Tokenhub *TokenhubSession) HandleBindPackage(msgBytes []byte, proof []byte, height uint64, packageSequence uint64) (*types.Transaction, error) {
	return _Tokenhub.Contract.HandleBindPackage(&_Tokenhub.TransactOpts, msgBytes, proof, height, packageSequence)
}

// HandleBindPackage is a paid mutator transaction binding the contract method 0x2eb881b0.
//
// Solidity: function handleBindPackage(bytes msgBytes, bytes proof, uint64 height, uint64 packageSequence) returns(bool)
func (_Tokenhub *TokenhubTransactorSession) HandleBindPackage(msgBytes []byte, proof []byte, height uint64, packageSequence uint64) (*types.Transaction, error) {
	return _Tokenhub.Contract.HandleBindPackage(&_Tokenhub.TransactOpts, msgBytes, proof, height, packageSequence)
}

// HandleRefundPackage is a paid mutator transaction binding the contract method 0xccb27f6a.
//
// Solidity: function handleRefundPackage(bytes msgBytes, bytes proof, uint64 height, uint64 packageSequence) returns(bool)
func (_Tokenhub *TokenhubTransactor) HandleRefundPackage(opts *bind.TransactOpts, msgBytes []byte, proof []byte, height uint64, packageSequence uint64) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "handleRefundPackage", msgBytes, proof, height, packageSequence)
}

// HandleRefundPackage is a paid mutator transaction binding the contract method 0xccb27f6a.
//
// Solidity: function handleRefundPackage(bytes msgBytes, bytes proof, uint64 height, uint64 packageSequence) returns(bool)
func (_Tokenhub *TokenhubSession) HandleRefundPackage(msgBytes []byte, proof []byte, height uint64, packageSequence uint64) (*types.Transaction, error) {
	return _Tokenhub.Contract.HandleRefundPackage(&_Tokenhub.TransactOpts, msgBytes, proof, height, packageSequence)
}

// HandleRefundPackage is a paid mutator transaction binding the contract method 0xccb27f6a.
//
// Solidity: function handleRefundPackage(bytes msgBytes, bytes proof, uint64 height, uint64 packageSequence) returns(bool)
func (_Tokenhub *TokenhubTransactorSession) HandleRefundPackage(msgBytes []byte, proof []byte, height uint64, packageSequence uint64) (*types.Transaction, error) {
	return _Tokenhub.Contract.HandleRefundPackage(&_Tokenhub.TransactOpts, msgBytes, proof, height, packageSequence)
}

// HandleTransferInPackage is a paid mutator transaction binding the contract method 0x964c0dcd.
//
// Solidity: function handleTransferInPackage(bytes msgBytes, bytes proof, uint64 height, uint64 packageSequence) returns(bool)
func (_Tokenhub *TokenhubTransactor) HandleTransferInPackage(opts *bind.TransactOpts, msgBytes []byte, proof []byte, height uint64, packageSequence uint64) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "handleTransferInPackage", msgBytes, proof, height, packageSequence)
}

// HandleTransferInPackage is a paid mutator transaction binding the contract method 0x964c0dcd.
//
// Solidity: function handleTransferInPackage(bytes msgBytes, bytes proof, uint64 height, uint64 packageSequence) returns(bool)
func (_Tokenhub *TokenhubSession) HandleTransferInPackage(msgBytes []byte, proof []byte, height uint64, packageSequence uint64) (*types.Transaction, error) {
	return _Tokenhub.Contract.HandleTransferInPackage(&_Tokenhub.TransactOpts, msgBytes, proof, height, packageSequence)
}

// HandleTransferInPackage is a paid mutator transaction binding the contract method 0x964c0dcd.
//
// Solidity: function handleTransferInPackage(bytes msgBytes, bytes proof, uint64 height, uint64 packageSequence) returns(bool)
func (_Tokenhub *TokenhubTransactorSession) HandleTransferInPackage(msgBytes []byte, proof []byte, height uint64, packageSequence uint64) (*types.Transaction, error) {
	return _Tokenhub.Contract.HandleTransferInPackage(&_Tokenhub.TransactOpts, msgBytes, proof, height, packageSequence)
}

// RejectBind is a paid mutator transaction binding the contract method 0x77d9dae8.
//
// Solidity: function rejectBind(address contractAddr, string bep2Symbol) returns(bool)
func (_Tokenhub *TokenhubTransactor) RejectBind(opts *bind.TransactOpts, contractAddr common.Address, bep2Symbol string) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "rejectBind", contractAddr, bep2Symbol)
}

// RejectBind is a paid mutator transaction binding the contract method 0x77d9dae8.
//
// Solidity: function rejectBind(address contractAddr, string bep2Symbol) returns(bool)
func (_Tokenhub *TokenhubSession) RejectBind(contractAddr common.Address, bep2Symbol string) (*types.Transaction, error) {
	return _Tokenhub.Contract.RejectBind(&_Tokenhub.TransactOpts, contractAddr, bep2Symbol)
}

// RejectBind is a paid mutator transaction binding the contract method 0x77d9dae8.
//
// Solidity: function rejectBind(address contractAddr, string bep2Symbol) returns(bool)
func (_Tokenhub *TokenhubTransactorSession) RejectBind(contractAddr common.Address, bep2Symbol string) (*types.Transaction, error) {
	return _Tokenhub.Contract.RejectBind(&_Tokenhub.TransactOpts, contractAddr, bep2Symbol)
}

// TransferOut is a paid mutator transaction binding the contract method 0xd43b8c5b.
//
// Solidity: function transferOut(address contractAddr, address recipient, uint256 amount, uint256 expireTime, uint256 relayFee) returns(bool)
func (_Tokenhub *TokenhubTransactor) TransferOut(opts *bind.TransactOpts, contractAddr common.Address, recipient common.Address, amount *big.Int, expireTime *big.Int, relayFee *big.Int) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "transferOut", contractAddr, recipient, amount, expireTime, relayFee)
}

// TransferOut is a paid mutator transaction binding the contract method 0xd43b8c5b.
//
// Solidity: function transferOut(address contractAddr, address recipient, uint256 amount, uint256 expireTime, uint256 relayFee) returns(bool)
func (_Tokenhub *TokenhubSession) TransferOut(contractAddr common.Address, recipient common.Address, amount *big.Int, expireTime *big.Int, relayFee *big.Int) (*types.Transaction, error) {
	return _Tokenhub.Contract.TransferOut(&_Tokenhub.TransactOpts, contractAddr, recipient, amount, expireTime, relayFee)
}

// TransferOut is a paid mutator transaction binding the contract method 0xd43b8c5b.
//
// Solidity: function transferOut(address contractAddr, address recipient, uint256 amount, uint256 expireTime, uint256 relayFee) returns(bool)
func (_Tokenhub *TokenhubTransactorSession) TransferOut(contractAddr common.Address, recipient common.Address, amount *big.Int, expireTime *big.Int, relayFee *big.Int) (*types.Transaction, error) {
	return _Tokenhub.Contract.TransferOut(&_Tokenhub.TransactOpts, contractAddr, recipient, amount, expireTime, relayFee)
}

// TokenhubLogBatchTransferOutIterator is returned from FilterLogBatchTransferOut and is used to iterate over the raw logs and unpacked data for LogBatchTransferOut events raised by the Tokenhub contract.
type TokenhubLogBatchTransferOutIterator struct {
	Event *TokenhubLogBatchTransferOut // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogBatchTransferOutIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogBatchTransferOut)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogBatchTransferOut)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogBatchTransferOutIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogBatchTransferOutIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogBatchTransferOut represents a LogBatchTransferOut event raised by the Tokenhub contract.
type TokenhubLogBatchTransferOut struct {
	Sequence        *big.Int
	Amounts         []*big.Int
	ContractAddr    common.Address
	Bep2TokenSymbol [32]byte
	ExpireTime      *big.Int
	RelayFee        *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterLogBatchTransferOut is a free log retrieval operation binding the contract event 0x00a18f0343865824d1375c23f5dd79fdf32a12f50400ef2591e52276f8378e31.
//
// Solidity: event LogBatchTransferOut(uint256 sequence, uint256[] amounts, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayFee)
func (_Tokenhub *TokenhubFilterer) FilterLogBatchTransferOut(opts *bind.FilterOpts) (*TokenhubLogBatchTransferOutIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogBatchTransferOut")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogBatchTransferOutIterator{contract: _Tokenhub.contract, event: "LogBatchTransferOut", logs: logs, sub: sub}, nil
}

// WatchLogBatchTransferOut is a free log subscription operation binding the contract event 0x00a18f0343865824d1375c23f5dd79fdf32a12f50400ef2591e52276f8378e31.
//
// Solidity: event LogBatchTransferOut(uint256 sequence, uint256[] amounts, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayFee)
func (_Tokenhub *TokenhubFilterer) WatchLogBatchTransferOut(opts *bind.WatchOpts, sink chan<- *TokenhubLogBatchTransferOut) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogBatchTransferOut")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogBatchTransferOut)
				if err := _Tokenhub.contract.UnpackLog(event, "LogBatchTransferOut", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogBatchTransferOut is a log parse operation binding the contract event 0x00a18f0343865824d1375c23f5dd79fdf32a12f50400ef2591e52276f8378e31.
//
// Solidity: event LogBatchTransferOut(uint256 sequence, uint256[] amounts, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayFee)
func (_Tokenhub *TokenhubFilterer) ParseLogBatchTransferOut(log types.Log) (*TokenhubLogBatchTransferOut, error) {
	event := new(TokenhubLogBatchTransferOut)
	if err := _Tokenhub.contract.UnpackLog(event, "LogBatchTransferOut", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogBatchTransferOutAddrsIterator is returned from FilterLogBatchTransferOutAddrs and is used to iterate over the raw logs and unpacked data for LogBatchTransferOutAddrs events raised by the Tokenhub contract.
type TokenhubLogBatchTransferOutAddrsIterator struct {
	Event *TokenhubLogBatchTransferOutAddrs // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogBatchTransferOutAddrsIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogBatchTransferOutAddrs)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogBatchTransferOutAddrs)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogBatchTransferOutAddrsIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogBatchTransferOutAddrsIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogBatchTransferOutAddrs represents a LogBatchTransferOutAddrs event raised by the Tokenhub contract.
type TokenhubLogBatchTransferOutAddrs struct {
	Sequence       *big.Int
	RecipientAddrs []common.Address
	RefundAddrs    []common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterLogBatchTransferOutAddrs is a free log retrieval operation binding the contract event 0x8740bbd4e1a2505bf2908481adbf1056fb52f762152b702f6c65468f63c55cf8.
//
// Solidity: event LogBatchTransferOutAddrs(uint256 sequence, address[] recipientAddrs, address[] refundAddrs)
func (_Tokenhub *TokenhubFilterer) FilterLogBatchTransferOutAddrs(opts *bind.FilterOpts) (*TokenhubLogBatchTransferOutAddrsIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogBatchTransferOutAddrs")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogBatchTransferOutAddrsIterator{contract: _Tokenhub.contract, event: "LogBatchTransferOutAddrs", logs: logs, sub: sub}, nil
}

// WatchLogBatchTransferOutAddrs is a free log subscription operation binding the contract event 0x8740bbd4e1a2505bf2908481adbf1056fb52f762152b702f6c65468f63c55cf8.
//
// Solidity: event LogBatchTransferOutAddrs(uint256 sequence, address[] recipientAddrs, address[] refundAddrs)
func (_Tokenhub *TokenhubFilterer) WatchLogBatchTransferOutAddrs(opts *bind.WatchOpts, sink chan<- *TokenhubLogBatchTransferOutAddrs) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogBatchTransferOutAddrs")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogBatchTransferOutAddrs)
				if err := _Tokenhub.contract.UnpackLog(event, "LogBatchTransferOutAddrs", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogBatchTransferOutAddrs is a log parse operation binding the contract event 0x8740bbd4e1a2505bf2908481adbf1056fb52f762152b702f6c65468f63c55cf8.
//
// Solidity: event LogBatchTransferOutAddrs(uint256 sequence, address[] recipientAddrs, address[] refundAddrs)
func (_Tokenhub *TokenhubFilterer) ParseLogBatchTransferOutAddrs(log types.Log) (*TokenhubLogBatchTransferOutAddrs, error) {
	event := new(TokenhubLogBatchTransferOutAddrs)
	if err := _Tokenhub.contract.UnpackLog(event, "LogBatchTransferOutAddrs", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogBindInvalidParameterIterator is returned from FilterLogBindInvalidParameter and is used to iterate over the raw logs and unpacked data for LogBindInvalidParameter events raised by the Tokenhub contract.
type TokenhubLogBindInvalidParameterIterator struct {
	Event *TokenhubLogBindInvalidParameter // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogBindInvalidParameterIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogBindInvalidParameter)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogBindInvalidParameter)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogBindInvalidParameterIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogBindInvalidParameterIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogBindInvalidParameter represents a LogBindInvalidParameter event raised by the Tokenhub contract.
type TokenhubLogBindInvalidParameter struct {
	Sequence        *big.Int
	ContractAddr    common.Address
	Bep2TokenSymbol [32]byte
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterLogBindInvalidParameter is a free log retrieval operation binding the contract event 0x2117f993c9cc877c531b4e6bd55d822cb48b529fd003c80e5bd6c27b7c1c1702.
//
// Solidity: event LogBindInvalidParameter(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol)
func (_Tokenhub *TokenhubFilterer) FilterLogBindInvalidParameter(opts *bind.FilterOpts) (*TokenhubLogBindInvalidParameterIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogBindInvalidParameter")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogBindInvalidParameterIterator{contract: _Tokenhub.contract, event: "LogBindInvalidParameter", logs: logs, sub: sub}, nil
}

// WatchLogBindInvalidParameter is a free log subscription operation binding the contract event 0x2117f993c9cc877c531b4e6bd55d822cb48b529fd003c80e5bd6c27b7c1c1702.
//
// Solidity: event LogBindInvalidParameter(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol)
func (_Tokenhub *TokenhubFilterer) WatchLogBindInvalidParameter(opts *bind.WatchOpts, sink chan<- *TokenhubLogBindInvalidParameter) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogBindInvalidParameter")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogBindInvalidParameter)
				if err := _Tokenhub.contract.UnpackLog(event, "LogBindInvalidParameter", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogBindInvalidParameter is a log parse operation binding the contract event 0x2117f993c9cc877c531b4e6bd55d822cb48b529fd003c80e5bd6c27b7c1c1702.
//
// Solidity: event LogBindInvalidParameter(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol)
func (_Tokenhub *TokenhubFilterer) ParseLogBindInvalidParameter(log types.Log) (*TokenhubLogBindInvalidParameter, error) {
	event := new(TokenhubLogBindInvalidParameter)
	if err := _Tokenhub.contract.UnpackLog(event, "LogBindInvalidParameter", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogBindRejectedIterator is returned from FilterLogBindRejected and is used to iterate over the raw logs and unpacked data for LogBindRejected events raised by the Tokenhub contract.
type TokenhubLogBindRejectedIterator struct {
	Event *TokenhubLogBindRejected // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogBindRejectedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogBindRejected)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogBindRejected)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogBindRejectedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogBindRejectedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogBindRejected represents a LogBindRejected event raised by the Tokenhub contract.
type TokenhubLogBindRejected struct {
	Sequence        *big.Int
	ContractAddr    common.Address
	Bep2TokenSymbol [32]byte
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterLogBindRejected is a free log retrieval operation binding the contract event 0x341e20b0b6b62cb3990e2d1f8bcb0a15e7d7fd446355a7be807face162285254.
//
// Solidity: event LogBindRejected(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol)
func (_Tokenhub *TokenhubFilterer) FilterLogBindRejected(opts *bind.FilterOpts) (*TokenhubLogBindRejectedIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogBindRejected")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogBindRejectedIterator{contract: _Tokenhub.contract, event: "LogBindRejected", logs: logs, sub: sub}, nil
}

// WatchLogBindRejected is a free log subscription operation binding the contract event 0x341e20b0b6b62cb3990e2d1f8bcb0a15e7d7fd446355a7be807face162285254.
//
// Solidity: event LogBindRejected(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol)
func (_Tokenhub *TokenhubFilterer) WatchLogBindRejected(opts *bind.WatchOpts, sink chan<- *TokenhubLogBindRejected) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogBindRejected")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogBindRejected)
				if err := _Tokenhub.contract.UnpackLog(event, "LogBindRejected", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogBindRejected is a log parse operation binding the contract event 0x341e20b0b6b62cb3990e2d1f8bcb0a15e7d7fd446355a7be807face162285254.
//
// Solidity: event LogBindRejected(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol)
func (_Tokenhub *TokenhubFilterer) ParseLogBindRejected(log types.Log) (*TokenhubLogBindRejected, error) {
	event := new(TokenhubLogBindRejected)
	if err := _Tokenhub.contract.UnpackLog(event, "LogBindRejected", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogBindRequestIterator is returned from FilterLogBindRequest and is used to iterate over the raw logs and unpacked data for LogBindRequest events raised by the Tokenhub contract.
type TokenhubLogBindRequestIterator struct {
	Event *TokenhubLogBindRequest // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogBindRequestIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogBindRequest)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogBindRequest)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogBindRequestIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogBindRequestIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogBindRequest represents a LogBindRequest event raised by the Tokenhub contract.
type TokenhubLogBindRequest struct {
	ContractAddr    common.Address
	Bep2TokenSymbol [32]byte
	TotalSupply     *big.Int
	PeggyAmount     *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterLogBindRequest is a free log retrieval operation binding the contract event 0xf8608cf3c27350e6aa0beaa6723ea6911e3d7353e8b22a69bb112c15f93867ca.
//
// Solidity: event LogBindRequest(address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount)
func (_Tokenhub *TokenhubFilterer) FilterLogBindRequest(opts *bind.FilterOpts) (*TokenhubLogBindRequestIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogBindRequest")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogBindRequestIterator{contract: _Tokenhub.contract, event: "LogBindRequest", logs: logs, sub: sub}, nil
}

// WatchLogBindRequest is a free log subscription operation binding the contract event 0xf8608cf3c27350e6aa0beaa6723ea6911e3d7353e8b22a69bb112c15f93867ca.
//
// Solidity: event LogBindRequest(address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount)
func (_Tokenhub *TokenhubFilterer) WatchLogBindRequest(opts *bind.WatchOpts, sink chan<- *TokenhubLogBindRequest) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogBindRequest")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogBindRequest)
				if err := _Tokenhub.contract.UnpackLog(event, "LogBindRequest", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogBindRequest is a log parse operation binding the contract event 0xf8608cf3c27350e6aa0beaa6723ea6911e3d7353e8b22a69bb112c15f93867ca.
//
// Solidity: event LogBindRequest(address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount)
func (_Tokenhub *TokenhubFilterer) ParseLogBindRequest(log types.Log) (*TokenhubLogBindRequest, error) {
	event := new(TokenhubLogBindRequest)
	if err := _Tokenhub.contract.UnpackLog(event, "LogBindRequest", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogBindSuccessIterator is returned from FilterLogBindSuccess and is used to iterate over the raw logs and unpacked data for LogBindSuccess events raised by the Tokenhub contract.
type TokenhubLogBindSuccessIterator struct {
	Event *TokenhubLogBindSuccess // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogBindSuccessIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogBindSuccess)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogBindSuccess)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogBindSuccessIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogBindSuccessIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogBindSuccess represents a LogBindSuccess event raised by the Tokenhub contract.
type TokenhubLogBindSuccess struct {
	Sequence        *big.Int
	ContractAddr    common.Address
	Bep2TokenSymbol [32]byte
	TotalSupply     *big.Int
	PeggyAmount     *big.Int
	Decimals        *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterLogBindSuccess is a free log retrieval operation binding the contract event 0x8005b9354dd0ca4c5593805bcd00ea12b5fce8a2cc9bc15252f50fb2d17c09d2.
//
// Solidity: event LogBindSuccess(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount, uint256 decimals)
func (_Tokenhub *TokenhubFilterer) FilterLogBindSuccess(opts *bind.FilterOpts) (*TokenhubLogBindSuccessIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogBindSuccess")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogBindSuccessIterator{contract: _Tokenhub.contract, event: "LogBindSuccess", logs: logs, sub: sub}, nil
}

// WatchLogBindSuccess is a free log subscription operation binding the contract event 0x8005b9354dd0ca4c5593805bcd00ea12b5fce8a2cc9bc15252f50fb2d17c09d2.
//
// Solidity: event LogBindSuccess(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount, uint256 decimals)
func (_Tokenhub *TokenhubFilterer) WatchLogBindSuccess(opts *bind.WatchOpts, sink chan<- *TokenhubLogBindSuccess) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogBindSuccess")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogBindSuccess)
				if err := _Tokenhub.contract.UnpackLog(event, "LogBindSuccess", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogBindSuccess is a log parse operation binding the contract event 0x8005b9354dd0ca4c5593805bcd00ea12b5fce8a2cc9bc15252f50fb2d17c09d2.
//
// Solidity: event LogBindSuccess(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount, uint256 decimals)
func (_Tokenhub *TokenhubFilterer) ParseLogBindSuccess(log types.Log) (*TokenhubLogBindSuccess, error) {
	event := new(TokenhubLogBindSuccess)
	if err := _Tokenhub.contract.UnpackLog(event, "LogBindSuccess", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogBindTimeoutIterator is returned from FilterLogBindTimeout and is used to iterate over the raw logs and unpacked data for LogBindTimeout events raised by the Tokenhub contract.
type TokenhubLogBindTimeoutIterator struct {
	Event *TokenhubLogBindTimeout // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogBindTimeoutIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogBindTimeout)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogBindTimeout)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogBindTimeoutIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogBindTimeoutIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogBindTimeout represents a LogBindTimeout event raised by the Tokenhub contract.
type TokenhubLogBindTimeout struct {
	Sequence        *big.Int
	ContractAddr    common.Address
	Bep2TokenSymbol [32]byte
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterLogBindTimeout is a free log retrieval operation binding the contract event 0x4781c2d0a33124fb32083581f5b48c93a59b71fd567ce2d4a56c89196baa2ccd.
//
// Solidity: event LogBindTimeout(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol)
func (_Tokenhub *TokenhubFilterer) FilterLogBindTimeout(opts *bind.FilterOpts) (*TokenhubLogBindTimeoutIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogBindTimeout")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogBindTimeoutIterator{contract: _Tokenhub.contract, event: "LogBindTimeout", logs: logs, sub: sub}, nil
}

// WatchLogBindTimeout is a free log subscription operation binding the contract event 0x4781c2d0a33124fb32083581f5b48c93a59b71fd567ce2d4a56c89196baa2ccd.
//
// Solidity: event LogBindTimeout(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol)
func (_Tokenhub *TokenhubFilterer) WatchLogBindTimeout(opts *bind.WatchOpts, sink chan<- *TokenhubLogBindTimeout) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogBindTimeout")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogBindTimeout)
				if err := _Tokenhub.contract.UnpackLog(event, "LogBindTimeout", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogBindTimeout is a log parse operation binding the contract event 0x4781c2d0a33124fb32083581f5b48c93a59b71fd567ce2d4a56c89196baa2ccd.
//
// Solidity: event LogBindTimeout(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol)
func (_Tokenhub *TokenhubFilterer) ParseLogBindTimeout(log types.Log) (*TokenhubLogBindTimeout, error) {
	event := new(TokenhubLogBindTimeout)
	if err := _Tokenhub.contract.UnpackLog(event, "LogBindTimeout", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogRefundFailureInsufficientBalanceIterator is returned from FilterLogRefundFailureInsufficientBalance and is used to iterate over the raw logs and unpacked data for LogRefundFailureInsufficientBalance events raised by the Tokenhub contract.
type TokenhubLogRefundFailureInsufficientBalanceIterator struct {
	Event *TokenhubLogRefundFailureInsufficientBalance // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogRefundFailureInsufficientBalanceIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogRefundFailureInsufficientBalance)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogRefundFailureInsufficientBalance)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogRefundFailureInsufficientBalanceIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogRefundFailureInsufficientBalanceIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogRefundFailureInsufficientBalance represents a LogRefundFailureInsufficientBalance event raised by the Tokenhub contract.
type TokenhubLogRefundFailureInsufficientBalance struct {
	ContractAddr  common.Address
	RefundAddr    common.Address
	Amount        *big.Int
	Reason        uint16
	ActualBalance *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterLogRefundFailureInsufficientBalance is a free log retrieval operation binding the contract event 0x3c4b6baf924ba2c954f9d76392ea4a866fda4b545684f54badbb5ab67c59f277.
//
// Solidity: event LogRefundFailureInsufficientBalance(address contractAddr, address refundAddr, uint256 amount, uint16 reason, uint256 actualBalance)
func (_Tokenhub *TokenhubFilterer) FilterLogRefundFailureInsufficientBalance(opts *bind.FilterOpts) (*TokenhubLogRefundFailureInsufficientBalanceIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogRefundFailureInsufficientBalance")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogRefundFailureInsufficientBalanceIterator{contract: _Tokenhub.contract, event: "LogRefundFailureInsufficientBalance", logs: logs, sub: sub}, nil
}

// WatchLogRefundFailureInsufficientBalance is a free log subscription operation binding the contract event 0x3c4b6baf924ba2c954f9d76392ea4a866fda4b545684f54badbb5ab67c59f277.
//
// Solidity: event LogRefundFailureInsufficientBalance(address contractAddr, address refundAddr, uint256 amount, uint16 reason, uint256 actualBalance)
func (_Tokenhub *TokenhubFilterer) WatchLogRefundFailureInsufficientBalance(opts *bind.WatchOpts, sink chan<- *TokenhubLogRefundFailureInsufficientBalance) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogRefundFailureInsufficientBalance")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogRefundFailureInsufficientBalance)
				if err := _Tokenhub.contract.UnpackLog(event, "LogRefundFailureInsufficientBalance", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogRefundFailureInsufficientBalance is a log parse operation binding the contract event 0x3c4b6baf924ba2c954f9d76392ea4a866fda4b545684f54badbb5ab67c59f277.
//
// Solidity: event LogRefundFailureInsufficientBalance(address contractAddr, address refundAddr, uint256 amount, uint16 reason, uint256 actualBalance)
func (_Tokenhub *TokenhubFilterer) ParseLogRefundFailureInsufficientBalance(log types.Log) (*TokenhubLogRefundFailureInsufficientBalance, error) {
	event := new(TokenhubLogRefundFailureInsufficientBalance)
	if err := _Tokenhub.contract.UnpackLog(event, "LogRefundFailureInsufficientBalance", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogRefundFailureUnboundTokenIterator is returned from FilterLogRefundFailureUnboundToken and is used to iterate over the raw logs and unpacked data for LogRefundFailureUnboundToken events raised by the Tokenhub contract.
type TokenhubLogRefundFailureUnboundTokenIterator struct {
	Event *TokenhubLogRefundFailureUnboundToken // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogRefundFailureUnboundTokenIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogRefundFailureUnboundToken)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogRefundFailureUnboundToken)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogRefundFailureUnboundTokenIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogRefundFailureUnboundTokenIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogRefundFailureUnboundToken represents a LogRefundFailureUnboundToken event raised by the Tokenhub contract.
type TokenhubLogRefundFailureUnboundToken struct {
	ContractAddr common.Address
	RefundAddr   common.Address
	Amount       *big.Int
	Reason       uint16
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterLogRefundFailureUnboundToken is a free log retrieval operation binding the contract event 0xc9f4828eed39b4d08b0bcc16c824d67db7f30fdb36aa5572912134742f623f99.
//
// Solidity: event LogRefundFailureUnboundToken(address contractAddr, address refundAddr, uint256 amount, uint16 reason)
func (_Tokenhub *TokenhubFilterer) FilterLogRefundFailureUnboundToken(opts *bind.FilterOpts) (*TokenhubLogRefundFailureUnboundTokenIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogRefundFailureUnboundToken")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogRefundFailureUnboundTokenIterator{contract: _Tokenhub.contract, event: "LogRefundFailureUnboundToken", logs: logs, sub: sub}, nil
}

// WatchLogRefundFailureUnboundToken is a free log subscription operation binding the contract event 0xc9f4828eed39b4d08b0bcc16c824d67db7f30fdb36aa5572912134742f623f99.
//
// Solidity: event LogRefundFailureUnboundToken(address contractAddr, address refundAddr, uint256 amount, uint16 reason)
func (_Tokenhub *TokenhubFilterer) WatchLogRefundFailureUnboundToken(opts *bind.WatchOpts, sink chan<- *TokenhubLogRefundFailureUnboundToken) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogRefundFailureUnboundToken")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogRefundFailureUnboundToken)
				if err := _Tokenhub.contract.UnpackLog(event, "LogRefundFailureUnboundToken", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogRefundFailureUnboundToken is a log parse operation binding the contract event 0xc9f4828eed39b4d08b0bcc16c824d67db7f30fdb36aa5572912134742f623f99.
//
// Solidity: event LogRefundFailureUnboundToken(address contractAddr, address refundAddr, uint256 amount, uint16 reason)
func (_Tokenhub *TokenhubFilterer) ParseLogRefundFailureUnboundToken(log types.Log) (*TokenhubLogRefundFailureUnboundToken, error) {
	event := new(TokenhubLogRefundFailureUnboundToken)
	if err := _Tokenhub.contract.UnpackLog(event, "LogRefundFailureUnboundToken", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogRefundFailureUnknownReasonIterator is returned from FilterLogRefundFailureUnknownReason and is used to iterate over the raw logs and unpacked data for LogRefundFailureUnknownReason events raised by the Tokenhub contract.
type TokenhubLogRefundFailureUnknownReasonIterator struct {
	Event *TokenhubLogRefundFailureUnknownReason // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogRefundFailureUnknownReasonIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogRefundFailureUnknownReason)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogRefundFailureUnknownReason)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogRefundFailureUnknownReasonIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogRefundFailureUnknownReasonIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogRefundFailureUnknownReason represents a LogRefundFailureUnknownReason event raised by the Tokenhub contract.
type TokenhubLogRefundFailureUnknownReason struct {
	ContractAddr common.Address
	RefundAddr   common.Address
	Amount       *big.Int
	Reason       uint16
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterLogRefundFailureUnknownReason is a free log retrieval operation binding the contract event 0x21ecc19fbf4244dbd58a78f83d525251163700dfdeec195b4e0ab98127ad790c.
//
// Solidity: event LogRefundFailureUnknownReason(address contractAddr, address refundAddr, uint256 amount, uint16 reason)
func (_Tokenhub *TokenhubFilterer) FilterLogRefundFailureUnknownReason(opts *bind.FilterOpts) (*TokenhubLogRefundFailureUnknownReasonIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogRefundFailureUnknownReason")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogRefundFailureUnknownReasonIterator{contract: _Tokenhub.contract, event: "LogRefundFailureUnknownReason", logs: logs, sub: sub}, nil
}

// WatchLogRefundFailureUnknownReason is a free log subscription operation binding the contract event 0x21ecc19fbf4244dbd58a78f83d525251163700dfdeec195b4e0ab98127ad790c.
//
// Solidity: event LogRefundFailureUnknownReason(address contractAddr, address refundAddr, uint256 amount, uint16 reason)
func (_Tokenhub *TokenhubFilterer) WatchLogRefundFailureUnknownReason(opts *bind.WatchOpts, sink chan<- *TokenhubLogRefundFailureUnknownReason) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogRefundFailureUnknownReason")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogRefundFailureUnknownReason)
				if err := _Tokenhub.contract.UnpackLog(event, "LogRefundFailureUnknownReason", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogRefundFailureUnknownReason is a log parse operation binding the contract event 0x21ecc19fbf4244dbd58a78f83d525251163700dfdeec195b4e0ab98127ad790c.
//
// Solidity: event LogRefundFailureUnknownReason(address contractAddr, address refundAddr, uint256 amount, uint16 reason)
func (_Tokenhub *TokenhubFilterer) ParseLogRefundFailureUnknownReason(log types.Log) (*TokenhubLogRefundFailureUnknownReason, error) {
	event := new(TokenhubLogRefundFailureUnknownReason)
	if err := _Tokenhub.contract.UnpackLog(event, "LogRefundFailureUnknownReason", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogRefundSuccessIterator is returned from FilterLogRefundSuccess and is used to iterate over the raw logs and unpacked data for LogRefundSuccess events raised by the Tokenhub contract.
type TokenhubLogRefundSuccessIterator struct {
	Event *TokenhubLogRefundSuccess // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogRefundSuccessIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogRefundSuccess)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogRefundSuccess)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogRefundSuccessIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogRefundSuccessIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogRefundSuccess represents a LogRefundSuccess event raised by the Tokenhub contract.
type TokenhubLogRefundSuccess struct {
	ContractAddr common.Address
	RefundAddr   common.Address
	Amount       *big.Int
	Reason       uint16
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterLogRefundSuccess is a free log retrieval operation binding the contract event 0x5d287c29bf23b5f4c450d5e83e5ca51c1f8225afb6f253e9d2ca107893b2a7e4.
//
// Solidity: event LogRefundSuccess(address contractAddr, address refundAddr, uint256 amount, uint16 reason)
func (_Tokenhub *TokenhubFilterer) FilterLogRefundSuccess(opts *bind.FilterOpts) (*TokenhubLogRefundSuccessIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogRefundSuccess")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogRefundSuccessIterator{contract: _Tokenhub.contract, event: "LogRefundSuccess", logs: logs, sub: sub}, nil
}

// WatchLogRefundSuccess is a free log subscription operation binding the contract event 0x5d287c29bf23b5f4c450d5e83e5ca51c1f8225afb6f253e9d2ca107893b2a7e4.
//
// Solidity: event LogRefundSuccess(address contractAddr, address refundAddr, uint256 amount, uint16 reason)
func (_Tokenhub *TokenhubFilterer) WatchLogRefundSuccess(opts *bind.WatchOpts, sink chan<- *TokenhubLogRefundSuccess) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogRefundSuccess")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogRefundSuccess)
				if err := _Tokenhub.contract.UnpackLog(event, "LogRefundSuccess", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogRefundSuccess is a log parse operation binding the contract event 0x5d287c29bf23b5f4c450d5e83e5ca51c1f8225afb6f253e9d2ca107893b2a7e4.
//
// Solidity: event LogRefundSuccess(address contractAddr, address refundAddr, uint256 amount, uint16 reason)
func (_Tokenhub *TokenhubFilterer) ParseLogRefundSuccess(log types.Log) (*TokenhubLogRefundSuccess, error) {
	event := new(TokenhubLogRefundSuccess)
	if err := _Tokenhub.contract.UnpackLog(event, "LogRefundSuccess", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogTransferInFailureInsufficientBalanceIterator is returned from FilterLogTransferInFailureInsufficientBalance and is used to iterate over the raw logs and unpacked data for LogTransferInFailureInsufficientBalance events raised by the Tokenhub contract.
type TokenhubLogTransferInFailureInsufficientBalanceIterator struct {
	Event *TokenhubLogTransferInFailureInsufficientBalance // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogTransferInFailureInsufficientBalanceIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogTransferInFailureInsufficientBalance)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogTransferInFailureInsufficientBalance)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogTransferInFailureInsufficientBalanceIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogTransferInFailureInsufficientBalanceIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogTransferInFailureInsufficientBalance represents a LogTransferInFailureInsufficientBalance event raised by the Tokenhub contract.
type TokenhubLogTransferInFailureInsufficientBalance struct {
	Sequence        *big.Int
	RefundAddr      common.Address
	Recipient       common.Address
	Bep2TokenAmount *big.Int
	ContractAddr    common.Address
	Bep2TokenSymbol [32]byte
	ActualBalance   *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterLogTransferInFailureInsufficientBalance is a free log retrieval operation binding the contract event 0x1de400dfa3e72ba83f12c6f1d8b9b85dc3d2aedc6eacc27b481267826aec7422.
//
// Solidity: event LogTransferInFailureInsufficientBalance(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol, uint256 actualBalance)
func (_Tokenhub *TokenhubFilterer) FilterLogTransferInFailureInsufficientBalance(opts *bind.FilterOpts) (*TokenhubLogTransferInFailureInsufficientBalanceIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogTransferInFailureInsufficientBalance")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogTransferInFailureInsufficientBalanceIterator{contract: _Tokenhub.contract, event: "LogTransferInFailureInsufficientBalance", logs: logs, sub: sub}, nil
}

// WatchLogTransferInFailureInsufficientBalance is a free log subscription operation binding the contract event 0x1de400dfa3e72ba83f12c6f1d8b9b85dc3d2aedc6eacc27b481267826aec7422.
//
// Solidity: event LogTransferInFailureInsufficientBalance(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol, uint256 actualBalance)
func (_Tokenhub *TokenhubFilterer) WatchLogTransferInFailureInsufficientBalance(opts *bind.WatchOpts, sink chan<- *TokenhubLogTransferInFailureInsufficientBalance) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogTransferInFailureInsufficientBalance")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogTransferInFailureInsufficientBalance)
				if err := _Tokenhub.contract.UnpackLog(event, "LogTransferInFailureInsufficientBalance", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogTransferInFailureInsufficientBalance is a log parse operation binding the contract event 0x1de400dfa3e72ba83f12c6f1d8b9b85dc3d2aedc6eacc27b481267826aec7422.
//
// Solidity: event LogTransferInFailureInsufficientBalance(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol, uint256 actualBalance)
func (_Tokenhub *TokenhubFilterer) ParseLogTransferInFailureInsufficientBalance(log types.Log) (*TokenhubLogTransferInFailureInsufficientBalance, error) {
	event := new(TokenhubLogTransferInFailureInsufficientBalance)
	if err := _Tokenhub.contract.UnpackLog(event, "LogTransferInFailureInsufficientBalance", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogTransferInFailureTimeoutIterator is returned from FilterLogTransferInFailureTimeout and is used to iterate over the raw logs and unpacked data for LogTransferInFailureTimeout events raised by the Tokenhub contract.
type TokenhubLogTransferInFailureTimeoutIterator struct {
	Event *TokenhubLogTransferInFailureTimeout // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogTransferInFailureTimeoutIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogTransferInFailureTimeout)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogTransferInFailureTimeout)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogTransferInFailureTimeoutIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogTransferInFailureTimeoutIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogTransferInFailureTimeout represents a LogTransferInFailureTimeout event raised by the Tokenhub contract.
type TokenhubLogTransferInFailureTimeout struct {
	Sequence        *big.Int
	RefundAddr      common.Address
	Recipient       common.Address
	Bep2TokenAmount *big.Int
	ContractAddr    common.Address
	Bep2TokenSymbol [32]byte
	ExpireTime      *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterLogTransferInFailureTimeout is a free log retrieval operation binding the contract event 0x8090e98e190cb0b05412d5c1a8cd5ee9af5d40da935335cef5d4179c7da63d79.
//
// Solidity: event LogTransferInFailureTimeout(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime)
func (_Tokenhub *TokenhubFilterer) FilterLogTransferInFailureTimeout(opts *bind.FilterOpts) (*TokenhubLogTransferInFailureTimeoutIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogTransferInFailureTimeout")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogTransferInFailureTimeoutIterator{contract: _Tokenhub.contract, event: "LogTransferInFailureTimeout", logs: logs, sub: sub}, nil
}

// WatchLogTransferInFailureTimeout is a free log subscription operation binding the contract event 0x8090e98e190cb0b05412d5c1a8cd5ee9af5d40da935335cef5d4179c7da63d79.
//
// Solidity: event LogTransferInFailureTimeout(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime)
func (_Tokenhub *TokenhubFilterer) WatchLogTransferInFailureTimeout(opts *bind.WatchOpts, sink chan<- *TokenhubLogTransferInFailureTimeout) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogTransferInFailureTimeout")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogTransferInFailureTimeout)
				if err := _Tokenhub.contract.UnpackLog(event, "LogTransferInFailureTimeout", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogTransferInFailureTimeout is a log parse operation binding the contract event 0x8090e98e190cb0b05412d5c1a8cd5ee9af5d40da935335cef5d4179c7da63d79.
//
// Solidity: event LogTransferInFailureTimeout(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime)
func (_Tokenhub *TokenhubFilterer) ParseLogTransferInFailureTimeout(log types.Log) (*TokenhubLogTransferInFailureTimeout, error) {
	event := new(TokenhubLogTransferInFailureTimeout)
	if err := _Tokenhub.contract.UnpackLog(event, "LogTransferInFailureTimeout", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogTransferInFailureUnboundTokenIterator is returned from FilterLogTransferInFailureUnboundToken and is used to iterate over the raw logs and unpacked data for LogTransferInFailureUnboundToken events raised by the Tokenhub contract.
type TokenhubLogTransferInFailureUnboundTokenIterator struct {
	Event *TokenhubLogTransferInFailureUnboundToken // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogTransferInFailureUnboundTokenIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogTransferInFailureUnboundToken)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogTransferInFailureUnboundToken)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogTransferInFailureUnboundTokenIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogTransferInFailureUnboundTokenIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogTransferInFailureUnboundToken represents a LogTransferInFailureUnboundToken event raised by the Tokenhub contract.
type TokenhubLogTransferInFailureUnboundToken struct {
	Sequence        *big.Int
	RefundAddr      common.Address
	Recipient       common.Address
	Bep2TokenAmount *big.Int
	ContractAddr    common.Address
	Bep2TokenSymbol [32]byte
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterLogTransferInFailureUnboundToken is a free log retrieval operation binding the contract event 0x055f2adbd109a4e99b3821af55571cccb4981551d10e3846b21574d348572a59.
//
// Solidity: event LogTransferInFailureUnboundToken(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol)
func (_Tokenhub *TokenhubFilterer) FilterLogTransferInFailureUnboundToken(opts *bind.FilterOpts) (*TokenhubLogTransferInFailureUnboundTokenIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogTransferInFailureUnboundToken")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogTransferInFailureUnboundTokenIterator{contract: _Tokenhub.contract, event: "LogTransferInFailureUnboundToken", logs: logs, sub: sub}, nil
}

// WatchLogTransferInFailureUnboundToken is a free log subscription operation binding the contract event 0x055f2adbd109a4e99b3821af55571cccb4981551d10e3846b21574d348572a59.
//
// Solidity: event LogTransferInFailureUnboundToken(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol)
func (_Tokenhub *TokenhubFilterer) WatchLogTransferInFailureUnboundToken(opts *bind.WatchOpts, sink chan<- *TokenhubLogTransferInFailureUnboundToken) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogTransferInFailureUnboundToken")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogTransferInFailureUnboundToken)
				if err := _Tokenhub.contract.UnpackLog(event, "LogTransferInFailureUnboundToken", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogTransferInFailureUnboundToken is a log parse operation binding the contract event 0x055f2adbd109a4e99b3821af55571cccb4981551d10e3846b21574d348572a59.
//
// Solidity: event LogTransferInFailureUnboundToken(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol)
func (_Tokenhub *TokenhubFilterer) ParseLogTransferInFailureUnboundToken(log types.Log) (*TokenhubLogTransferInFailureUnboundToken, error) {
	event := new(TokenhubLogTransferInFailureUnboundToken)
	if err := _Tokenhub.contract.UnpackLog(event, "LogTransferInFailureUnboundToken", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogTransferInFailureUnknownReasonIterator is returned from FilterLogTransferInFailureUnknownReason and is used to iterate over the raw logs and unpacked data for LogTransferInFailureUnknownReason events raised by the Tokenhub contract.
type TokenhubLogTransferInFailureUnknownReasonIterator struct {
	Event *TokenhubLogTransferInFailureUnknownReason // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogTransferInFailureUnknownReasonIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogTransferInFailureUnknownReason)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogTransferInFailureUnknownReason)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogTransferInFailureUnknownReasonIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogTransferInFailureUnknownReasonIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogTransferInFailureUnknownReason represents a LogTransferInFailureUnknownReason event raised by the Tokenhub contract.
type TokenhubLogTransferInFailureUnknownReason struct {
	Sequence        *big.Int
	RefundAddr      common.Address
	Recipient       common.Address
	Bep2TokenAmount *big.Int
	ContractAddr    common.Address
	Bep2TokenSymbol [32]byte
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterLogTransferInFailureUnknownReason is a free log retrieval operation binding the contract event 0xcb6ddd4a252f58c1ff32f31fbb529dc35e8f6a81908f6211bbe7dfa94ef52f1f.
//
// Solidity: event LogTransferInFailureUnknownReason(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol)
func (_Tokenhub *TokenhubFilterer) FilterLogTransferInFailureUnknownReason(opts *bind.FilterOpts) (*TokenhubLogTransferInFailureUnknownReasonIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogTransferInFailureUnknownReason")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogTransferInFailureUnknownReasonIterator{contract: _Tokenhub.contract, event: "LogTransferInFailureUnknownReason", logs: logs, sub: sub}, nil
}

// WatchLogTransferInFailureUnknownReason is a free log subscription operation binding the contract event 0xcb6ddd4a252f58c1ff32f31fbb529dc35e8f6a81908f6211bbe7dfa94ef52f1f.
//
// Solidity: event LogTransferInFailureUnknownReason(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol)
func (_Tokenhub *TokenhubFilterer) WatchLogTransferInFailureUnknownReason(opts *bind.WatchOpts, sink chan<- *TokenhubLogTransferInFailureUnknownReason) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogTransferInFailureUnknownReason")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogTransferInFailureUnknownReason)
				if err := _Tokenhub.contract.UnpackLog(event, "LogTransferInFailureUnknownReason", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogTransferInFailureUnknownReason is a log parse operation binding the contract event 0xcb6ddd4a252f58c1ff32f31fbb529dc35e8f6a81908f6211bbe7dfa94ef52f1f.
//
// Solidity: event LogTransferInFailureUnknownReason(uint256 sequence, address refundAddr, address recipient, uint256 bep2TokenAmount, address contractAddr, bytes32 bep2TokenSymbol)
func (_Tokenhub *TokenhubFilterer) ParseLogTransferInFailureUnknownReason(log types.Log) (*TokenhubLogTransferInFailureUnknownReason, error) {
	event := new(TokenhubLogTransferInFailureUnknownReason)
	if err := _Tokenhub.contract.UnpackLog(event, "LogTransferInFailureUnknownReason", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogTransferInSuccessIterator is returned from FilterLogTransferInSuccess and is used to iterate over the raw logs and unpacked data for LogTransferInSuccess events raised by the Tokenhub contract.
type TokenhubLogTransferInSuccessIterator struct {
	Event *TokenhubLogTransferInSuccess // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogTransferInSuccessIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogTransferInSuccess)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogTransferInSuccess)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogTransferInSuccessIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogTransferInSuccessIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogTransferInSuccess represents a LogTransferInSuccess event raised by the Tokenhub contract.
type TokenhubLogTransferInSuccess struct {
	Sequence     *big.Int
	Recipient    common.Address
	Amount       *big.Int
	ContractAddr common.Address
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterLogTransferInSuccess is a free log retrieval operation binding the contract event 0x8b8816b9cf4590950a140d102435e65bcce6ee7c84bb38367dd2bb71b8ae4ad2.
//
// Solidity: event LogTransferInSuccess(uint256 sequence, address recipient, uint256 amount, address contractAddr)
func (_Tokenhub *TokenhubFilterer) FilterLogTransferInSuccess(opts *bind.FilterOpts) (*TokenhubLogTransferInSuccessIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogTransferInSuccess")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogTransferInSuccessIterator{contract: _Tokenhub.contract, event: "LogTransferInSuccess", logs: logs, sub: sub}, nil
}

// WatchLogTransferInSuccess is a free log subscription operation binding the contract event 0x8b8816b9cf4590950a140d102435e65bcce6ee7c84bb38367dd2bb71b8ae4ad2.
//
// Solidity: event LogTransferInSuccess(uint256 sequence, address recipient, uint256 amount, address contractAddr)
func (_Tokenhub *TokenhubFilterer) WatchLogTransferInSuccess(opts *bind.WatchOpts, sink chan<- *TokenhubLogTransferInSuccess) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogTransferInSuccess")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogTransferInSuccess)
				if err := _Tokenhub.contract.UnpackLog(event, "LogTransferInSuccess", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogTransferInSuccess is a log parse operation binding the contract event 0x8b8816b9cf4590950a140d102435e65bcce6ee7c84bb38367dd2bb71b8ae4ad2.
//
// Solidity: event LogTransferInSuccess(uint256 sequence, address recipient, uint256 amount, address contractAddr)
func (_Tokenhub *TokenhubFilterer) ParseLogTransferInSuccess(log types.Log) (*TokenhubLogTransferInSuccess, error) {
	event := new(TokenhubLogTransferInSuccess)
	if err := _Tokenhub.contract.UnpackLog(event, "LogTransferInSuccess", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogTransferOutIterator is returned from FilterLogTransferOut and is used to iterate over the raw logs and unpacked data for LogTransferOut events raised by the Tokenhub contract.
type TokenhubLogTransferOutIterator struct {
	Event *TokenhubLogTransferOut // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogTransferOutIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogTransferOut)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogTransferOut)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogTransferOutIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogTransferOutIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogTransferOut represents a LogTransferOut event raised by the Tokenhub contract.
type TokenhubLogTransferOut struct {
	Sequence        *big.Int
	RefundAddr      common.Address
	Recipient       common.Address
	Amount          *big.Int
	ContractAddr    common.Address
	Bep2TokenSymbol [32]byte
	ExpireTime      *big.Int
	RelayFee        *big.Int
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterLogTransferOut is a free log retrieval operation binding the contract event 0x5bd451c53ab05abd9855ceb52a469590655af1d732a4cfd67f1f9b53d74dc613.
//
// Solidity: event LogTransferOut(uint256 sequence, address refundAddr, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayFee)
func (_Tokenhub *TokenhubFilterer) FilterLogTransferOut(opts *bind.FilterOpts) (*TokenhubLogTransferOutIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogTransferOut")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogTransferOutIterator{contract: _Tokenhub.contract, event: "LogTransferOut", logs: logs, sub: sub}, nil
}

// WatchLogTransferOut is a free log subscription operation binding the contract event 0x5bd451c53ab05abd9855ceb52a469590655af1d732a4cfd67f1f9b53d74dc613.
//
// Solidity: event LogTransferOut(uint256 sequence, address refundAddr, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayFee)
func (_Tokenhub *TokenhubFilterer) WatchLogTransferOut(opts *bind.WatchOpts, sink chan<- *TokenhubLogTransferOut) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogTransferOut")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogTransferOut)
				if err := _Tokenhub.contract.UnpackLog(event, "LogTransferOut", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogTransferOut is a log parse operation binding the contract event 0x5bd451c53ab05abd9855ceb52a469590655af1d732a4cfd67f1f9b53d74dc613.
//
// Solidity: event LogTransferOut(uint256 sequence, address refundAddr, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayFee)
func (_Tokenhub *TokenhubFilterer) ParseLogTransferOut(log types.Log) (*TokenhubLogTransferOut, error) {
	event := new(TokenhubLogTransferOut)
	if err := _Tokenhub.contract.UnpackLog(event, "LogTransferOut", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogUnexpectedFailureAssertionInBEP2EIterator is returned from FilterLogUnexpectedFailureAssertionInBEP2E and is used to iterate over the raw logs and unpacked data for LogUnexpectedFailureAssertionInBEP2E events raised by the Tokenhub contract.
type TokenhubLogUnexpectedFailureAssertionInBEP2EIterator struct {
	Event *TokenhubLogUnexpectedFailureAssertionInBEP2E // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogUnexpectedFailureAssertionInBEP2EIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogUnexpectedFailureAssertionInBEP2E)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogUnexpectedFailureAssertionInBEP2E)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogUnexpectedFailureAssertionInBEP2EIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogUnexpectedFailureAssertionInBEP2EIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogUnexpectedFailureAssertionInBEP2E represents a LogUnexpectedFailureAssertionInBEP2E event raised by the Tokenhub contract.
type TokenhubLogUnexpectedFailureAssertionInBEP2E struct {
	ContractAddr common.Address
	LowLevelData []byte
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterLogUnexpectedFailureAssertionInBEP2E is a free log retrieval operation binding the contract event 0x31a48d93e6850d386f670b9e376328798aa76e04eccb473f292a73cfd4955edb.
//
// Solidity: event LogUnexpectedFailureAssertionInBEP2E(address contractAddr, bytes lowLevelData)
func (_Tokenhub *TokenhubFilterer) FilterLogUnexpectedFailureAssertionInBEP2E(opts *bind.FilterOpts) (*TokenhubLogUnexpectedFailureAssertionInBEP2EIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogUnexpectedFailureAssertionInBEP2E")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogUnexpectedFailureAssertionInBEP2EIterator{contract: _Tokenhub.contract, event: "LogUnexpectedFailureAssertionInBEP2E", logs: logs, sub: sub}, nil
}

// WatchLogUnexpectedFailureAssertionInBEP2E is a free log subscription operation binding the contract event 0x31a48d93e6850d386f670b9e376328798aa76e04eccb473f292a73cfd4955edb.
//
// Solidity: event LogUnexpectedFailureAssertionInBEP2E(address contractAddr, bytes lowLevelData)
func (_Tokenhub *TokenhubFilterer) WatchLogUnexpectedFailureAssertionInBEP2E(opts *bind.WatchOpts, sink chan<- *TokenhubLogUnexpectedFailureAssertionInBEP2E) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogUnexpectedFailureAssertionInBEP2E")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogUnexpectedFailureAssertionInBEP2E)
				if err := _Tokenhub.contract.UnpackLog(event, "LogUnexpectedFailureAssertionInBEP2E", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogUnexpectedFailureAssertionInBEP2E is a log parse operation binding the contract event 0x31a48d93e6850d386f670b9e376328798aa76e04eccb473f292a73cfd4955edb.
//
// Solidity: event LogUnexpectedFailureAssertionInBEP2E(address contractAddr, bytes lowLevelData)
func (_Tokenhub *TokenhubFilterer) ParseLogUnexpectedFailureAssertionInBEP2E(log types.Log) (*TokenhubLogUnexpectedFailureAssertionInBEP2E, error) {
	event := new(TokenhubLogUnexpectedFailureAssertionInBEP2E)
	if err := _Tokenhub.contract.UnpackLog(event, "LogUnexpectedFailureAssertionInBEP2E", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubLogUnexpectedRevertInBEP2EIterator is returned from FilterLogUnexpectedRevertInBEP2E and is used to iterate over the raw logs and unpacked data for LogUnexpectedRevertInBEP2E events raised by the Tokenhub contract.
type TokenhubLogUnexpectedRevertInBEP2EIterator struct {
	Event *TokenhubLogUnexpectedRevertInBEP2E // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TokenhubLogUnexpectedRevertInBEP2EIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubLogUnexpectedRevertInBEP2E)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TokenhubLogUnexpectedRevertInBEP2E)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TokenhubLogUnexpectedRevertInBEP2EIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubLogUnexpectedRevertInBEP2EIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubLogUnexpectedRevertInBEP2E represents a LogUnexpectedRevertInBEP2E event raised by the Tokenhub contract.
type TokenhubLogUnexpectedRevertInBEP2E struct {
	ContractAddr common.Address
	Reason       string
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterLogUnexpectedRevertInBEP2E is a free log retrieval operation binding the contract event 0x6b12c383d2683ef480c42ffdc69b5e1b142f2d9e63993c4ba14789d43b9f4999.
//
// Solidity: event LogUnexpectedRevertInBEP2E(address contractAddr, string reason)
func (_Tokenhub *TokenhubFilterer) FilterLogUnexpectedRevertInBEP2E(opts *bind.FilterOpts) (*TokenhubLogUnexpectedRevertInBEP2EIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "LogUnexpectedRevertInBEP2E")
	if err != nil {
		return nil, err
	}
	return &TokenhubLogUnexpectedRevertInBEP2EIterator{contract: _Tokenhub.contract, event: "LogUnexpectedRevertInBEP2E", logs: logs, sub: sub}, nil
}

// WatchLogUnexpectedRevertInBEP2E is a free log subscription operation binding the contract event 0x6b12c383d2683ef480c42ffdc69b5e1b142f2d9e63993c4ba14789d43b9f4999.
//
// Solidity: event LogUnexpectedRevertInBEP2E(address contractAddr, string reason)
func (_Tokenhub *TokenhubFilterer) WatchLogUnexpectedRevertInBEP2E(opts *bind.WatchOpts, sink chan<- *TokenhubLogUnexpectedRevertInBEP2E) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "LogUnexpectedRevertInBEP2E")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubLogUnexpectedRevertInBEP2E)
				if err := _Tokenhub.contract.UnpackLog(event, "LogUnexpectedRevertInBEP2E", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseLogUnexpectedRevertInBEP2E is a log parse operation binding the contract event 0x6b12c383d2683ef480c42ffdc69b5e1b142f2d9e63993c4ba14789d43b9f4999.
//
// Solidity: event LogUnexpectedRevertInBEP2E(address contractAddr, string reason)
func (_Tokenhub *TokenhubFilterer) ParseLogUnexpectedRevertInBEP2E(log types.Log) (*TokenhubLogUnexpectedRevertInBEP2E, error) {
	event := new(TokenhubLogUnexpectedRevertInBEP2E)
	if err := _Tokenhub.contract.UnpackLog(event, "LogUnexpectedRevertInBEP2E", log); err != nil {
		return nil, err
	}
	return event, nil
}
