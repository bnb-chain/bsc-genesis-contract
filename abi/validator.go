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
const TokenhubABI = "[{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"batchTransfer\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"string\",\"name\":\"reason\",\"type\":\"string\"}],\"name\":\"batchTransferFailed\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"bytes\",\"name\":\"reason\",\"type\":\"bytes\"}],\"name\":\"batchTransferLowerFailed\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"validator\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"deprecatedDeposit\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"addresspayable\",\"name\":\"validator\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"directTransfer\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"addresspayable\",\"name\":\"validator\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"directTransferFail\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"string\",\"name\":\"message\",\"type\":\"string\"}],\"name\":\"failReasonWithStr\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"string\",\"name\":\"key\",\"type\":\"string\"},{\"indexed\":false,\"internalType\":\"bytes\",\"name\":\"value\",\"type\":\"bytes\"}],\"name\":\"paramChange\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"systemTransfer\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"validator\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"validatorDeposit\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"validator\",\"type\":\"address\"}],\"name\":\"validatorEmptyJailed\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint64\",\"name\":\"sequence\",\"type\":\"uint64\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"validator\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"validatorFelony\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"validator\",\"type\":\"address\"}],\"name\":\"validatorJailed\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"validator\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"validatorMisdemeanor\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[],\"name\":\"validatorSetUpdated\",\"type\":\"event\"},{\"constant\":true,\"inputs\":[],\"name\":\"CHANNEL_ID\",\"outputs\":[{\"internalType\":\"uint8\",\"name\":\"\",\"type\":\"uint8\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"DUSTY_INCOMING\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"EXTRA_FEE\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"GOV_HUB_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"INCENTIVIZE_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"INIT_VALIDATORSET_BYTES\",\"outputs\":[{\"internalType\":\"bytes\",\"name\":\"\",\"type\":\"bytes\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"JAIL_MESSAGE_TYPE\",\"outputs\":[{\"internalType\":\"uint8\",\"name\":\"\",\"type\":\"uint8\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"LIGHT_CLIENT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"RELAYERHUB_CONTRACT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"RELAYER_REWARD\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"SLASH_CONTRACT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"SYSTEM_REWARD_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"TOKEN_HUB_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"VALIDATORS_UPDATE_MESSAGE_TYPE\",\"outputs\":[{\"internalType\":\"uint8\",\"name\":\"\",\"type\":\"uint8\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"VALIDATOR_CONTRACT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"alreadyInit\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"currentValidatorSet\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"consensusAddress\",\"type\":\"address\"},{\"internalType\":\"addresspayable\",\"name\":\"feeAddress\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"BBCFeeAddress\",\"type\":\"address\"},{\"internalType\":\"uint64\",\"name\":\"votingPower\",\"type\":\"uint64\"},{\"internalType\":\"bool\",\"name\":\"jailed\",\"type\":\"bool\"},{\"internalType\":\"uint256\",\"name\":\"incoming\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"internalType\":\"address\",\"name\":\"valAddr\",\"type\":\"address\"}],\"name\":\"deposit\",\"outputs\":[],\"payable\":true,\"stateMutability\":\"payable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"expireTimeSecondGap\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"extraFee\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"internalType\":\"address\",\"name\":\"validator\",\"type\":\"address\"}],\"name\":\"felony\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"felonySequence\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"internalType\":\"address\",\"name\":\"validator\",\"type\":\"address\"}],\"name\":\"getIncoming\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"getValidators\",\"outputs\":[{\"internalType\":\"address[]\",\"name\":\"\",\"type\":\"address[]\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"internalType\":\"bytes\",\"name\":\"msgBytes\",\"type\":\"bytes\"},{\"internalType\":\"bytes\",\"name\":\"proof\",\"type\":\"bytes\"},{\"internalType\":\"uint64\",\"name\":\"height\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"packageSequence\",\"type\":\"uint64\"}],\"name\":\"handlePackage\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[],\"name\":\"init\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"internalType\":\"address\",\"name\":\"validator\",\"type\":\"address\"}],\"name\":\"misdemeanor\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"previousDepositHeight\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"relayerReward\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"sequence\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"totalInComing\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"internalType\":\"string\",\"name\":\"key\",\"type\":\"string\"},{\"internalType\":\"bytes\",\"name\":\"value\",\"type\":\"bytes\"}],\"name\":\"updateParam\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]"

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

// CHANNELID is a free data retrieval call binding the contract method 0xb0c0c514.
//
// Solidity: function CHANNEL_ID() constant returns(uint8)
func (_Tokenhub *TokenhubCaller) CHANNELID(opts *bind.CallOpts) (uint8, error) {
	var (
		ret0 = new(uint8)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "CHANNEL_ID")
	return *ret0, err
}

// CHANNELID is a free data retrieval call binding the contract method 0xb0c0c514.
//
// Solidity: function CHANNEL_ID() constant returns(uint8)
func (_Tokenhub *TokenhubSession) CHANNELID() (uint8, error) {
	return _Tokenhub.Contract.CHANNELID(&_Tokenhub.CallOpts)
}

// CHANNELID is a free data retrieval call binding the contract method 0xb0c0c514.
//
// Solidity: function CHANNEL_ID() constant returns(uint8)
func (_Tokenhub *TokenhubCallerSession) CHANNELID() (uint8, error) {
	return _Tokenhub.Contract.CHANNELID(&_Tokenhub.CallOpts)
}

// DUSTYINCOMING is a free data retrieval call binding the contract method 0xd86222d5.
//
// Solidity: function DUSTY_INCOMING() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) DUSTYINCOMING(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "DUSTY_INCOMING")
	return *ret0, err
}

// DUSTYINCOMING is a free data retrieval call binding the contract method 0xd86222d5.
//
// Solidity: function DUSTY_INCOMING() constant returns(uint256)
func (_Tokenhub *TokenhubSession) DUSTYINCOMING() (*big.Int, error) {
	return _Tokenhub.Contract.DUSTYINCOMING(&_Tokenhub.CallOpts)
}

// DUSTYINCOMING is a free data retrieval call binding the contract method 0xd86222d5.
//
// Solidity: function DUSTY_INCOMING() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) DUSTYINCOMING() (*big.Int, error) {
	return _Tokenhub.Contract.DUSTYINCOMING(&_Tokenhub.CallOpts)
}

// EXTRAFEE is a free data retrieval call binding the contract method 0x6a65855e.
//
// Solidity: function EXTRA_FEE() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) EXTRAFEE(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "EXTRA_FEE")
	return *ret0, err
}

// EXTRAFEE is a free data retrieval call binding the contract method 0x6a65855e.
//
// Solidity: function EXTRA_FEE() constant returns(uint256)
func (_Tokenhub *TokenhubSession) EXTRAFEE() (*big.Int, error) {
	return _Tokenhub.Contract.EXTRAFEE(&_Tokenhub.CallOpts)
}

// EXTRAFEE is a free data retrieval call binding the contract method 0x6a65855e.
//
// Solidity: function EXTRA_FEE() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) EXTRAFEE() (*big.Int, error) {
	return _Tokenhub.Contract.EXTRAFEE(&_Tokenhub.CallOpts)
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

// INITVALIDATORSETBYTES is a free data retrieval call binding the contract method 0xa5422d5c.
//
// Solidity: function INIT_VALIDATORSET_BYTES() constant returns(bytes)
func (_Tokenhub *TokenhubCaller) INITVALIDATORSETBYTES(opts *bind.CallOpts) ([]byte, error) {
	var (
		ret0 = new([]byte)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "INIT_VALIDATORSET_BYTES")
	return *ret0, err
}

// INITVALIDATORSETBYTES is a free data retrieval call binding the contract method 0xa5422d5c.
//
// Solidity: function INIT_VALIDATORSET_BYTES() constant returns(bytes)
func (_Tokenhub *TokenhubSession) INITVALIDATORSETBYTES() ([]byte, error) {
	return _Tokenhub.Contract.INITVALIDATORSETBYTES(&_Tokenhub.CallOpts)
}

// INITVALIDATORSETBYTES is a free data retrieval call binding the contract method 0xa5422d5c.
//
// Solidity: function INIT_VALIDATORSET_BYTES() constant returns(bytes)
func (_Tokenhub *TokenhubCallerSession) INITVALIDATORSETBYTES() ([]byte, error) {
	return _Tokenhub.Contract.INITVALIDATORSETBYTES(&_Tokenhub.CallOpts)
}

// JAILMESSAGETYPE is a free data retrieval call binding the contract method 0xbf9f4995.
//
// Solidity: function JAIL_MESSAGE_TYPE() constant returns(uint8)
func (_Tokenhub *TokenhubCaller) JAILMESSAGETYPE(opts *bind.CallOpts) (uint8, error) {
	var (
		ret0 = new(uint8)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "JAIL_MESSAGE_TYPE")
	return *ret0, err
}

// JAILMESSAGETYPE is a free data retrieval call binding the contract method 0xbf9f4995.
//
// Solidity: function JAIL_MESSAGE_TYPE() constant returns(uint8)
func (_Tokenhub *TokenhubSession) JAILMESSAGETYPE() (uint8, error) {
	return _Tokenhub.Contract.JAILMESSAGETYPE(&_Tokenhub.CallOpts)
}

// JAILMESSAGETYPE is a free data retrieval call binding the contract method 0xbf9f4995.
//
// Solidity: function JAIL_MESSAGE_TYPE() constant returns(uint8)
func (_Tokenhub *TokenhubCallerSession) JAILMESSAGETYPE() (uint8, error) {
	return _Tokenhub.Contract.JAILMESSAGETYPE(&_Tokenhub.CallOpts)
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

// VALIDATORSUPDATEMESSAGETYPE is a free data retrieval call binding the contract method 0x5667515a.
//
// Solidity: function VALIDATORS_UPDATE_MESSAGE_TYPE() constant returns(uint8)
func (_Tokenhub *TokenhubCaller) VALIDATORSUPDATEMESSAGETYPE(opts *bind.CallOpts) (uint8, error) {
	var (
		ret0 = new(uint8)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "VALIDATORS_UPDATE_MESSAGE_TYPE")
	return *ret0, err
}

// VALIDATORSUPDATEMESSAGETYPE is a free data retrieval call binding the contract method 0x5667515a.
//
// Solidity: function VALIDATORS_UPDATE_MESSAGE_TYPE() constant returns(uint8)
func (_Tokenhub *TokenhubSession) VALIDATORSUPDATEMESSAGETYPE() (uint8, error) {
	return _Tokenhub.Contract.VALIDATORSUPDATEMESSAGETYPE(&_Tokenhub.CallOpts)
}

// VALIDATORSUPDATEMESSAGETYPE is a free data retrieval call binding the contract method 0x5667515a.
//
// Solidity: function VALIDATORS_UPDATE_MESSAGE_TYPE() constant returns(uint8)
func (_Tokenhub *TokenhubCallerSession) VALIDATORSUPDATEMESSAGETYPE() (uint8, error) {
	return _Tokenhub.Contract.VALIDATORSUPDATEMESSAGETYPE(&_Tokenhub.CallOpts)
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

// AlreadyInit is a free data retrieval call binding the contract method 0xa78abc16.
//
// Solidity: function alreadyInit() constant returns(bool)
func (_Tokenhub *TokenhubCaller) AlreadyInit(opts *bind.CallOpts) (bool, error) {
	var (
		ret0 = new(bool)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "alreadyInit")
	return *ret0, err
}

// AlreadyInit is a free data retrieval call binding the contract method 0xa78abc16.
//
// Solidity: function alreadyInit() constant returns(bool)
func (_Tokenhub *TokenhubSession) AlreadyInit() (bool, error) {
	return _Tokenhub.Contract.AlreadyInit(&_Tokenhub.CallOpts)
}

// AlreadyInit is a free data retrieval call binding the contract method 0xa78abc16.
//
// Solidity: function alreadyInit() constant returns(bool)
func (_Tokenhub *TokenhubCallerSession) AlreadyInit() (bool, error) {
	return _Tokenhub.Contract.AlreadyInit(&_Tokenhub.CallOpts)
}

// CurrentValidatorSet is a free data retrieval call binding the contract method 0x6969a25c.
//
// Solidity: function currentValidatorSet(uint256 ) constant returns(address consensusAddress, address feeAddress, address BBCFeeAddress, uint64 votingPower, bool jailed, uint256 incoming)
func (_Tokenhub *TokenhubCaller) CurrentValidatorSet(opts *bind.CallOpts, arg0 *big.Int) (struct {
	ConsensusAddress common.Address
	FeeAddress       common.Address
	BBCFeeAddress    common.Address
	VotingPower      uint64
	Jailed           bool
	Incoming         *big.Int
}, error) {
	ret := new(struct {
		ConsensusAddress common.Address
		FeeAddress       common.Address
		BBCFeeAddress    common.Address
		VotingPower      uint64
		Jailed           bool
		Incoming         *big.Int
	})
	out := ret
	err := _Tokenhub.contract.Call(opts, out, "currentValidatorSet", arg0)
	return *ret, err
}

// CurrentValidatorSet is a free data retrieval call binding the contract method 0x6969a25c.
//
// Solidity: function currentValidatorSet(uint256 ) constant returns(address consensusAddress, address feeAddress, address BBCFeeAddress, uint64 votingPower, bool jailed, uint256 incoming)
func (_Tokenhub *TokenhubSession) CurrentValidatorSet(arg0 *big.Int) (struct {
	ConsensusAddress common.Address
	FeeAddress       common.Address
	BBCFeeAddress    common.Address
	VotingPower      uint64
	Jailed           bool
	Incoming         *big.Int
}, error) {
	return _Tokenhub.Contract.CurrentValidatorSet(&_Tokenhub.CallOpts, arg0)
}

// CurrentValidatorSet is a free data retrieval call binding the contract method 0x6969a25c.
//
// Solidity: function currentValidatorSet(uint256 ) constant returns(address consensusAddress, address feeAddress, address BBCFeeAddress, uint64 votingPower, bool jailed, uint256 incoming)
func (_Tokenhub *TokenhubCallerSession) CurrentValidatorSet(arg0 *big.Int) (struct {
	ConsensusAddress common.Address
	FeeAddress       common.Address
	BBCFeeAddress    common.Address
	VotingPower      uint64
	Jailed           bool
	Incoming         *big.Int
}, error) {
	return _Tokenhub.Contract.CurrentValidatorSet(&_Tokenhub.CallOpts, arg0)
}

// ExpireTimeSecondGap is a free data retrieval call binding the contract method 0x86249882.
//
// Solidity: function expireTimeSecondGap() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) ExpireTimeSecondGap(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "expireTimeSecondGap")
	return *ret0, err
}

// ExpireTimeSecondGap is a free data retrieval call binding the contract method 0x86249882.
//
// Solidity: function expireTimeSecondGap() constant returns(uint256)
func (_Tokenhub *TokenhubSession) ExpireTimeSecondGap() (*big.Int, error) {
	return _Tokenhub.Contract.ExpireTimeSecondGap(&_Tokenhub.CallOpts)
}

// ExpireTimeSecondGap is a free data retrieval call binding the contract method 0x86249882.
//
// Solidity: function expireTimeSecondGap() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) ExpireTimeSecondGap() (*big.Int, error) {
	return _Tokenhub.Contract.ExpireTimeSecondGap(&_Tokenhub.CallOpts)
}

// ExtraFee is a free data retrieval call binding the contract method 0xe20e1fee.
//
// Solidity: function extraFee() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) ExtraFee(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "extraFee")
	return *ret0, err
}

// ExtraFee is a free data retrieval call binding the contract method 0xe20e1fee.
//
// Solidity: function extraFee() constant returns(uint256)
func (_Tokenhub *TokenhubSession) ExtraFee() (*big.Int, error) {
	return _Tokenhub.Contract.ExtraFee(&_Tokenhub.CallOpts)
}

// ExtraFee is a free data retrieval call binding the contract method 0xe20e1fee.
//
// Solidity: function extraFee() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) ExtraFee() (*big.Int, error) {
	return _Tokenhub.Contract.ExtraFee(&_Tokenhub.CallOpts)
}

// FelonySequence is a free data retrieval call binding the contract method 0x7c973cb6.
//
// Solidity: function felonySequence() constant returns(uint64)
func (_Tokenhub *TokenhubCaller) FelonySequence(opts *bind.CallOpts) (uint64, error) {
	var (
		ret0 = new(uint64)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "felonySequence")
	return *ret0, err
}

// FelonySequence is a free data retrieval call binding the contract method 0x7c973cb6.
//
// Solidity: function felonySequence() constant returns(uint64)
func (_Tokenhub *TokenhubSession) FelonySequence() (uint64, error) {
	return _Tokenhub.Contract.FelonySequence(&_Tokenhub.CallOpts)
}

// FelonySequence is a free data retrieval call binding the contract method 0x7c973cb6.
//
// Solidity: function felonySequence() constant returns(uint64)
func (_Tokenhub *TokenhubCallerSession) FelonySequence() (uint64, error) {
	return _Tokenhub.Contract.FelonySequence(&_Tokenhub.CallOpts)
}

// GetIncoming is a free data retrieval call binding the contract method 0x565c56b3.
//
// Solidity: function getIncoming(address validator) constant returns(uint256)
func (_Tokenhub *TokenhubCaller) GetIncoming(opts *bind.CallOpts, validator common.Address) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "getIncoming", validator)
	return *ret0, err
}

// GetIncoming is a free data retrieval call binding the contract method 0x565c56b3.
//
// Solidity: function getIncoming(address validator) constant returns(uint256)
func (_Tokenhub *TokenhubSession) GetIncoming(validator common.Address) (*big.Int, error) {
	return _Tokenhub.Contract.GetIncoming(&_Tokenhub.CallOpts, validator)
}

// GetIncoming is a free data retrieval call binding the contract method 0x565c56b3.
//
// Solidity: function getIncoming(address validator) constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) GetIncoming(validator common.Address) (*big.Int, error) {
	return _Tokenhub.Contract.GetIncoming(&_Tokenhub.CallOpts, validator)
}

// GetValidators is a free data retrieval call binding the contract method 0xb7ab4db5.
//
// Solidity: function getValidators() constant returns(address[])
func (_Tokenhub *TokenhubCaller) GetValidators(opts *bind.CallOpts) ([]common.Address, error) {
	var (
		ret0 = new([]common.Address)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "getValidators")
	return *ret0, err
}

// GetValidators is a free data retrieval call binding the contract method 0xb7ab4db5.
//
// Solidity: function getValidators() constant returns(address[])
func (_Tokenhub *TokenhubSession) GetValidators() ([]common.Address, error) {
	return _Tokenhub.Contract.GetValidators(&_Tokenhub.CallOpts)
}

// GetValidators is a free data retrieval call binding the contract method 0xb7ab4db5.
//
// Solidity: function getValidators() constant returns(address[])
func (_Tokenhub *TokenhubCallerSession) GetValidators() ([]common.Address, error) {
	return _Tokenhub.Contract.GetValidators(&_Tokenhub.CallOpts)
}

// PreviousDepositHeight is a free data retrieval call binding the contract method 0x4e3e3ca9.
//
// Solidity: function previousDepositHeight() constant returns(uint64)
func (_Tokenhub *TokenhubCaller) PreviousDepositHeight(opts *bind.CallOpts) (uint64, error) {
	var (
		ret0 = new(uint64)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "previousDepositHeight")
	return *ret0, err
}

// PreviousDepositHeight is a free data retrieval call binding the contract method 0x4e3e3ca9.
//
// Solidity: function previousDepositHeight() constant returns(uint64)
func (_Tokenhub *TokenhubSession) PreviousDepositHeight() (uint64, error) {
	return _Tokenhub.Contract.PreviousDepositHeight(&_Tokenhub.CallOpts)
}

// PreviousDepositHeight is a free data retrieval call binding the contract method 0x4e3e3ca9.
//
// Solidity: function previousDepositHeight() constant returns(uint64)
func (_Tokenhub *TokenhubCallerSession) PreviousDepositHeight() (uint64, error) {
	return _Tokenhub.Contract.PreviousDepositHeight(&_Tokenhub.CallOpts)
}

// RelayerReward is a free data retrieval call binding the contract method 0x3f1e4244.
//
// Solidity: function relayerReward() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) RelayerReward(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "relayerReward")
	return *ret0, err
}

// RelayerReward is a free data retrieval call binding the contract method 0x3f1e4244.
//
// Solidity: function relayerReward() constant returns(uint256)
func (_Tokenhub *TokenhubSession) RelayerReward() (*big.Int, error) {
	return _Tokenhub.Contract.RelayerReward(&_Tokenhub.CallOpts)
}

// RelayerReward is a free data retrieval call binding the contract method 0x3f1e4244.
//
// Solidity: function relayerReward() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) RelayerReward() (*big.Int, error) {
	return _Tokenhub.Contract.RelayerReward(&_Tokenhub.CallOpts)
}

// Sequence is a free data retrieval call binding the contract method 0x529d15cc.
//
// Solidity: function sequence() constant returns(uint64)
func (_Tokenhub *TokenhubCaller) Sequence(opts *bind.CallOpts) (uint64, error) {
	var (
		ret0 = new(uint64)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "sequence")
	return *ret0, err
}

// Sequence is a free data retrieval call binding the contract method 0x529d15cc.
//
// Solidity: function sequence() constant returns(uint64)
func (_Tokenhub *TokenhubSession) Sequence() (uint64, error) {
	return _Tokenhub.Contract.Sequence(&_Tokenhub.CallOpts)
}

// Sequence is a free data retrieval call binding the contract method 0x529d15cc.
//
// Solidity: function sequence() constant returns(uint64)
func (_Tokenhub *TokenhubCallerSession) Sequence() (uint64, error) {
	return _Tokenhub.Contract.Sequence(&_Tokenhub.CallOpts)
}

// TotalInComing is a free data retrieval call binding the contract method 0x1ff18069.
//
// Solidity: function totalInComing() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) TotalInComing(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "totalInComing")
	return *ret0, err
}

// TotalInComing is a free data retrieval call binding the contract method 0x1ff18069.
//
// Solidity: function totalInComing() constant returns(uint256)
func (_Tokenhub *TokenhubSession) TotalInComing() (*big.Int, error) {
	return _Tokenhub.Contract.TotalInComing(&_Tokenhub.CallOpts)
}

// TotalInComing is a free data retrieval call binding the contract method 0x1ff18069.
//
// Solidity: function totalInComing() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) TotalInComing() (*big.Int, error) {
	return _Tokenhub.Contract.TotalInComing(&_Tokenhub.CallOpts)
}

// Deposit is a paid mutator transaction binding the contract method 0xf340fa01.
//
// Solidity: function deposit(address valAddr) returns()
func (_Tokenhub *TokenhubTransactor) Deposit(opts *bind.TransactOpts, valAddr common.Address) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "deposit", valAddr)
}

// Deposit is a paid mutator transaction binding the contract method 0xf340fa01.
//
// Solidity: function deposit(address valAddr) returns()
func (_Tokenhub *TokenhubSession) Deposit(valAddr common.Address) (*types.Transaction, error) {
	return _Tokenhub.Contract.Deposit(&_Tokenhub.TransactOpts, valAddr)
}

// Deposit is a paid mutator transaction binding the contract method 0xf340fa01.
//
// Solidity: function deposit(address valAddr) returns()
func (_Tokenhub *TokenhubTransactorSession) Deposit(valAddr common.Address) (*types.Transaction, error) {
	return _Tokenhub.Contract.Deposit(&_Tokenhub.TransactOpts, valAddr)
}

// Felony is a paid mutator transaction binding the contract method 0x35409f7f.
//
// Solidity: function felony(address validator) returns()
func (_Tokenhub *TokenhubTransactor) Felony(opts *bind.TransactOpts, validator common.Address) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "felony", validator)
}

// Felony is a paid mutator transaction binding the contract method 0x35409f7f.
//
// Solidity: function felony(address validator) returns()
func (_Tokenhub *TokenhubSession) Felony(validator common.Address) (*types.Transaction, error) {
	return _Tokenhub.Contract.Felony(&_Tokenhub.TransactOpts, validator)
}

// Felony is a paid mutator transaction binding the contract method 0x35409f7f.
//
// Solidity: function felony(address validator) returns()
func (_Tokenhub *TokenhubTransactorSession) Felony(validator common.Address) (*types.Transaction, error) {
	return _Tokenhub.Contract.Felony(&_Tokenhub.TransactOpts, validator)
}

// HandlePackage is a paid mutator transaction binding the contract method 0xe2a2dd4d.
//
// Solidity: function handlePackage(bytes msgBytes, bytes proof, uint64 height, uint64 packageSequence) returns()
func (_Tokenhub *TokenhubTransactor) HandlePackage(opts *bind.TransactOpts, msgBytes []byte, proof []byte, height uint64, packageSequence uint64) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "handlePackage", msgBytes, proof, height, packageSequence)
}

// HandlePackage is a paid mutator transaction binding the contract method 0xe2a2dd4d.
//
// Solidity: function handlePackage(bytes msgBytes, bytes proof, uint64 height, uint64 packageSequence) returns()
func (_Tokenhub *TokenhubSession) HandlePackage(msgBytes []byte, proof []byte, height uint64, packageSequence uint64) (*types.Transaction, error) {
	return _Tokenhub.Contract.HandlePackage(&_Tokenhub.TransactOpts, msgBytes, proof, height, packageSequence)
}

// HandlePackage is a paid mutator transaction binding the contract method 0xe2a2dd4d.
//
// Solidity: function handlePackage(bytes msgBytes, bytes proof, uint64 height, uint64 packageSequence) returns()
func (_Tokenhub *TokenhubTransactorSession) HandlePackage(msgBytes []byte, proof []byte, height uint64, packageSequence uint64) (*types.Transaction, error) {
	return _Tokenhub.Contract.HandlePackage(&_Tokenhub.TransactOpts, msgBytes, proof, height, packageSequence)
}

// Init is a paid mutator transaction binding the contract method 0xe1c7392a.
//
// Solidity: function init() returns()
func (_Tokenhub *TokenhubTransactor) Init(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "init")
}

// Init is a paid mutator transaction binding the contract method 0xe1c7392a.
//
// Solidity: function init() returns()
func (_Tokenhub *TokenhubSession) Init() (*types.Transaction, error) {
	return _Tokenhub.Contract.Init(&_Tokenhub.TransactOpts)
}

// Init is a paid mutator transaction binding the contract method 0xe1c7392a.
//
// Solidity: function init() returns()
func (_Tokenhub *TokenhubTransactorSession) Init() (*types.Transaction, error) {
	return _Tokenhub.Contract.Init(&_Tokenhub.TransactOpts)
}

// Misdemeanor is a paid mutator transaction binding the contract method 0xeb57e202.
//
// Solidity: function misdemeanor(address validator) returns()
func (_Tokenhub *TokenhubTransactor) Misdemeanor(opts *bind.TransactOpts, validator common.Address) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "misdemeanor", validator)
}

// Misdemeanor is a paid mutator transaction binding the contract method 0xeb57e202.
//
// Solidity: function misdemeanor(address validator) returns()
func (_Tokenhub *TokenhubSession) Misdemeanor(validator common.Address) (*types.Transaction, error) {
	return _Tokenhub.Contract.Misdemeanor(&_Tokenhub.TransactOpts, validator)
}

// Misdemeanor is a paid mutator transaction binding the contract method 0xeb57e202.
//
// Solidity: function misdemeanor(address validator) returns()
func (_Tokenhub *TokenhubTransactorSession) Misdemeanor(validator common.Address) (*types.Transaction, error) {
	return _Tokenhub.Contract.Misdemeanor(&_Tokenhub.TransactOpts, validator)
}

// UpdateParam is a paid mutator transaction binding the contract method 0xac431751.
//
// Solidity: function updateParam(string key, bytes value) returns()
func (_Tokenhub *TokenhubTransactor) UpdateParam(opts *bind.TransactOpts, key string, value []byte) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "updateParam", key, value)
}

// UpdateParam is a paid mutator transaction binding the contract method 0xac431751.
//
// Solidity: function updateParam(string key, bytes value) returns()
func (_Tokenhub *TokenhubSession) UpdateParam(key string, value []byte) (*types.Transaction, error) {
	return _Tokenhub.Contract.UpdateParam(&_Tokenhub.TransactOpts, key, value)
}

// UpdateParam is a paid mutator transaction binding the contract method 0xac431751.
//
// Solidity: function updateParam(string key, bytes value) returns()
func (_Tokenhub *TokenhubTransactorSession) UpdateParam(key string, value []byte) (*types.Transaction, error) {
	return _Tokenhub.Contract.UpdateParam(&_Tokenhub.TransactOpts, key, value)
}

// TokenhubBatchTransferIterator is returned from FilterBatchTransfer and is used to iterate over the raw logs and unpacked data for BatchTransfer events raised by the Tokenhub contract.
type TokenhubBatchTransferIterator struct {
	Event *TokenhubBatchTransfer // Event containing the contract specifics and raw log

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
func (it *TokenhubBatchTransferIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubBatchTransfer)
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
		it.Event = new(TokenhubBatchTransfer)
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
func (it *TokenhubBatchTransferIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubBatchTransferIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubBatchTransfer represents a BatchTransfer event raised by the Tokenhub contract.
type TokenhubBatchTransfer struct {
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBatchTransfer is a free log retrieval operation binding the contract event 0xa217d08e65f80c73121cd9db834d81652d544bfbf452f6d04922b16c90a37b70.
//
// Solidity: event batchTransfer(uint256 amount)
func (_Tokenhub *TokenhubFilterer) FilterBatchTransfer(opts *bind.FilterOpts) (*TokenhubBatchTransferIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "batchTransfer")
	if err != nil {
		return nil, err
	}
	return &TokenhubBatchTransferIterator{contract: _Tokenhub.contract, event: "batchTransfer", logs: logs, sub: sub}, nil
}

// WatchBatchTransfer is a free log subscription operation binding the contract event 0xa217d08e65f80c73121cd9db834d81652d544bfbf452f6d04922b16c90a37b70.
//
// Solidity: event batchTransfer(uint256 amount)
func (_Tokenhub *TokenhubFilterer) WatchBatchTransfer(opts *bind.WatchOpts, sink chan<- *TokenhubBatchTransfer) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "batchTransfer")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubBatchTransfer)
				if err := _Tokenhub.contract.UnpackLog(event, "batchTransfer", log); err != nil {
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

// ParseBatchTransfer is a log parse operation binding the contract event 0xa217d08e65f80c73121cd9db834d81652d544bfbf452f6d04922b16c90a37b70.
//
// Solidity: event batchTransfer(uint256 amount)
func (_Tokenhub *TokenhubFilterer) ParseBatchTransfer(log types.Log) (*TokenhubBatchTransfer, error) {
	event := new(TokenhubBatchTransfer)
	if err := _Tokenhub.contract.UnpackLog(event, "batchTransfer", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubBatchTransferFailedIterator is returned from FilterBatchTransferFailed and is used to iterate over the raw logs and unpacked data for BatchTransferFailed events raised by the Tokenhub contract.
type TokenhubBatchTransferFailedIterator struct {
	Event *TokenhubBatchTransferFailed // Event containing the contract specifics and raw log

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
func (it *TokenhubBatchTransferFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubBatchTransferFailed)
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
		it.Event = new(TokenhubBatchTransferFailed)
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
func (it *TokenhubBatchTransferFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubBatchTransferFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubBatchTransferFailed represents a BatchTransferFailed event raised by the Tokenhub contract.
type TokenhubBatchTransferFailed struct {
	Amount *big.Int
	Reason string
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBatchTransferFailed is a free log retrieval operation binding the contract event 0xa7cdeed7d0db45e3219a6e5d60838824c16f1d39991fcfe3f963029c844bf280.
//
// Solidity: event batchTransferFailed(uint256 indexed amount, string reason)
func (_Tokenhub *TokenhubFilterer) FilterBatchTransferFailed(opts *bind.FilterOpts, amount []*big.Int) (*TokenhubBatchTransferFailedIterator, error) {

	var amountRule []interface{}
	for _, amountItem := range amount {
		amountRule = append(amountRule, amountItem)
	}

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "batchTransferFailed", amountRule)
	if err != nil {
		return nil, err
	}
	return &TokenhubBatchTransferFailedIterator{contract: _Tokenhub.contract, event: "batchTransferFailed", logs: logs, sub: sub}, nil
}

// WatchBatchTransferFailed is a free log subscription operation binding the contract event 0xa7cdeed7d0db45e3219a6e5d60838824c16f1d39991fcfe3f963029c844bf280.
//
// Solidity: event batchTransferFailed(uint256 indexed amount, string reason)
func (_Tokenhub *TokenhubFilterer) WatchBatchTransferFailed(opts *bind.WatchOpts, sink chan<- *TokenhubBatchTransferFailed, amount []*big.Int) (event.Subscription, error) {

	var amountRule []interface{}
	for _, amountItem := range amount {
		amountRule = append(amountRule, amountItem)
	}

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "batchTransferFailed", amountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubBatchTransferFailed)
				if err := _Tokenhub.contract.UnpackLog(event, "batchTransferFailed", log); err != nil {
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

// ParseBatchTransferFailed is a log parse operation binding the contract event 0xa7cdeed7d0db45e3219a6e5d60838824c16f1d39991fcfe3f963029c844bf280.
//
// Solidity: event batchTransferFailed(uint256 indexed amount, string reason)
func (_Tokenhub *TokenhubFilterer) ParseBatchTransferFailed(log types.Log) (*TokenhubBatchTransferFailed, error) {
	event := new(TokenhubBatchTransferFailed)
	if err := _Tokenhub.contract.UnpackLog(event, "batchTransferFailed", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubBatchTransferLowerFailedIterator is returned from FilterBatchTransferLowerFailed and is used to iterate over the raw logs and unpacked data for BatchTransferLowerFailed events raised by the Tokenhub contract.
type TokenhubBatchTransferLowerFailedIterator struct {
	Event *TokenhubBatchTransferLowerFailed // Event containing the contract specifics and raw log

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
func (it *TokenhubBatchTransferLowerFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubBatchTransferLowerFailed)
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
		it.Event = new(TokenhubBatchTransferLowerFailed)
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
func (it *TokenhubBatchTransferLowerFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubBatchTransferLowerFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubBatchTransferLowerFailed represents a BatchTransferLowerFailed event raised by the Tokenhub contract.
type TokenhubBatchTransferLowerFailed struct {
	Amount *big.Int
	Reason []byte
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBatchTransferLowerFailed is a free log retrieval operation binding the contract event 0xbfa884552dd8921b6ce90bfe906952ae5b3b29be0cc1a951d4f62697635a3a45.
//
// Solidity: event batchTransferLowerFailed(uint256 indexed amount, bytes reason)
func (_Tokenhub *TokenhubFilterer) FilterBatchTransferLowerFailed(opts *bind.FilterOpts, amount []*big.Int) (*TokenhubBatchTransferLowerFailedIterator, error) {

	var amountRule []interface{}
	for _, amountItem := range amount {
		amountRule = append(amountRule, amountItem)
	}

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "batchTransferLowerFailed", amountRule)
	if err != nil {
		return nil, err
	}
	return &TokenhubBatchTransferLowerFailedIterator{contract: _Tokenhub.contract, event: "batchTransferLowerFailed", logs: logs, sub: sub}, nil
}

// WatchBatchTransferLowerFailed is a free log subscription operation binding the contract event 0xbfa884552dd8921b6ce90bfe906952ae5b3b29be0cc1a951d4f62697635a3a45.
//
// Solidity: event batchTransferLowerFailed(uint256 indexed amount, bytes reason)
func (_Tokenhub *TokenhubFilterer) WatchBatchTransferLowerFailed(opts *bind.WatchOpts, sink chan<- *TokenhubBatchTransferLowerFailed, amount []*big.Int) (event.Subscription, error) {

	var amountRule []interface{}
	for _, amountItem := range amount {
		amountRule = append(amountRule, amountItem)
	}

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "batchTransferLowerFailed", amountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubBatchTransferLowerFailed)
				if err := _Tokenhub.contract.UnpackLog(event, "batchTransferLowerFailed", log); err != nil {
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

// ParseBatchTransferLowerFailed is a log parse operation binding the contract event 0xbfa884552dd8921b6ce90bfe906952ae5b3b29be0cc1a951d4f62697635a3a45.
//
// Solidity: event batchTransferLowerFailed(uint256 indexed amount, bytes reason)
func (_Tokenhub *TokenhubFilterer) ParseBatchTransferLowerFailed(log types.Log) (*TokenhubBatchTransferLowerFailed, error) {
	event := new(TokenhubBatchTransferLowerFailed)
	if err := _Tokenhub.contract.UnpackLog(event, "batchTransferLowerFailed", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubDeprecatedDepositIterator is returned from FilterDeprecatedDeposit and is used to iterate over the raw logs and unpacked data for DeprecatedDeposit events raised by the Tokenhub contract.
type TokenhubDeprecatedDepositIterator struct {
	Event *TokenhubDeprecatedDeposit // Event containing the contract specifics and raw log

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
func (it *TokenhubDeprecatedDepositIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubDeprecatedDeposit)
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
		it.Event = new(TokenhubDeprecatedDeposit)
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
func (it *TokenhubDeprecatedDepositIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubDeprecatedDepositIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubDeprecatedDeposit represents a DeprecatedDeposit event raised by the Tokenhub contract.
type TokenhubDeprecatedDeposit struct {
	Validator common.Address
	Amount    *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterDeprecatedDeposit is a free log retrieval operation binding the contract event 0xf177e5d6c5764d79c32883ed824111d9b13f5668cf6ab1cc12dd36791dd955b4.
//
// Solidity: event deprecatedDeposit(address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) FilterDeprecatedDeposit(opts *bind.FilterOpts, validator []common.Address) (*TokenhubDeprecatedDepositIterator, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "deprecatedDeposit", validatorRule)
	if err != nil {
		return nil, err
	}
	return &TokenhubDeprecatedDepositIterator{contract: _Tokenhub.contract, event: "deprecatedDeposit", logs: logs, sub: sub}, nil
}

// WatchDeprecatedDeposit is a free log subscription operation binding the contract event 0xf177e5d6c5764d79c32883ed824111d9b13f5668cf6ab1cc12dd36791dd955b4.
//
// Solidity: event deprecatedDeposit(address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) WatchDeprecatedDeposit(opts *bind.WatchOpts, sink chan<- *TokenhubDeprecatedDeposit, validator []common.Address) (event.Subscription, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "deprecatedDeposit", validatorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubDeprecatedDeposit)
				if err := _Tokenhub.contract.UnpackLog(event, "deprecatedDeposit", log); err != nil {
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

// ParseDeprecatedDeposit is a log parse operation binding the contract event 0xf177e5d6c5764d79c32883ed824111d9b13f5668cf6ab1cc12dd36791dd955b4.
//
// Solidity: event deprecatedDeposit(address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) ParseDeprecatedDeposit(log types.Log) (*TokenhubDeprecatedDeposit, error) {
	event := new(TokenhubDeprecatedDeposit)
	if err := _Tokenhub.contract.UnpackLog(event, "deprecatedDeposit", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubDirectTransferIterator is returned from FilterDirectTransfer and is used to iterate over the raw logs and unpacked data for DirectTransfer events raised by the Tokenhub contract.
type TokenhubDirectTransferIterator struct {
	Event *TokenhubDirectTransfer // Event containing the contract specifics and raw log

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
func (it *TokenhubDirectTransferIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubDirectTransfer)
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
		it.Event = new(TokenhubDirectTransfer)
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
func (it *TokenhubDirectTransferIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubDirectTransferIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubDirectTransfer represents a DirectTransfer event raised by the Tokenhub contract.
type TokenhubDirectTransfer struct {
	Validator common.Address
	Amount    *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterDirectTransfer is a free log retrieval operation binding the contract event 0x6c61d60f69a7beb3e1c80db7f39f37b208537cbb19da3174511b477812b2fc7d.
//
// Solidity: event directTransfer(address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) FilterDirectTransfer(opts *bind.FilterOpts, validator []common.Address) (*TokenhubDirectTransferIterator, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "directTransfer", validatorRule)
	if err != nil {
		return nil, err
	}
	return &TokenhubDirectTransferIterator{contract: _Tokenhub.contract, event: "directTransfer", logs: logs, sub: sub}, nil
}

// WatchDirectTransfer is a free log subscription operation binding the contract event 0x6c61d60f69a7beb3e1c80db7f39f37b208537cbb19da3174511b477812b2fc7d.
//
// Solidity: event directTransfer(address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) WatchDirectTransfer(opts *bind.WatchOpts, sink chan<- *TokenhubDirectTransfer, validator []common.Address) (event.Subscription, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "directTransfer", validatorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubDirectTransfer)
				if err := _Tokenhub.contract.UnpackLog(event, "directTransfer", log); err != nil {
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

// ParseDirectTransfer is a log parse operation binding the contract event 0x6c61d60f69a7beb3e1c80db7f39f37b208537cbb19da3174511b477812b2fc7d.
//
// Solidity: event directTransfer(address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) ParseDirectTransfer(log types.Log) (*TokenhubDirectTransfer, error) {
	event := new(TokenhubDirectTransfer)
	if err := _Tokenhub.contract.UnpackLog(event, "directTransfer", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubDirectTransferFailIterator is returned from FilterDirectTransferFail and is used to iterate over the raw logs and unpacked data for DirectTransferFail events raised by the Tokenhub contract.
type TokenhubDirectTransferFailIterator struct {
	Event *TokenhubDirectTransferFail // Event containing the contract specifics and raw log

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
func (it *TokenhubDirectTransferFailIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubDirectTransferFail)
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
		it.Event = new(TokenhubDirectTransferFail)
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
func (it *TokenhubDirectTransferFailIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubDirectTransferFailIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubDirectTransferFail represents a DirectTransferFail event raised by the Tokenhub contract.
type TokenhubDirectTransferFail struct {
	Validator common.Address
	Amount    *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterDirectTransferFail is a free log retrieval operation binding the contract event 0x25d0ce7d2f0cec669a8c17efe49d195c13455bb8872b65fa610ac7f53fe4ca7d.
//
// Solidity: event directTransferFail(address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) FilterDirectTransferFail(opts *bind.FilterOpts, validator []common.Address) (*TokenhubDirectTransferFailIterator, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "directTransferFail", validatorRule)
	if err != nil {
		return nil, err
	}
	return &TokenhubDirectTransferFailIterator{contract: _Tokenhub.contract, event: "directTransferFail", logs: logs, sub: sub}, nil
}

// WatchDirectTransferFail is a free log subscription operation binding the contract event 0x25d0ce7d2f0cec669a8c17efe49d195c13455bb8872b65fa610ac7f53fe4ca7d.
//
// Solidity: event directTransferFail(address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) WatchDirectTransferFail(opts *bind.WatchOpts, sink chan<- *TokenhubDirectTransferFail, validator []common.Address) (event.Subscription, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "directTransferFail", validatorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubDirectTransferFail)
				if err := _Tokenhub.contract.UnpackLog(event, "directTransferFail", log); err != nil {
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

// ParseDirectTransferFail is a log parse operation binding the contract event 0x25d0ce7d2f0cec669a8c17efe49d195c13455bb8872b65fa610ac7f53fe4ca7d.
//
// Solidity: event directTransferFail(address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) ParseDirectTransferFail(log types.Log) (*TokenhubDirectTransferFail, error) {
	event := new(TokenhubDirectTransferFail)
	if err := _Tokenhub.contract.UnpackLog(event, "directTransferFail", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubFailReasonWithStrIterator is returned from FilterFailReasonWithStr and is used to iterate over the raw logs and unpacked data for FailReasonWithStr events raised by the Tokenhub contract.
type TokenhubFailReasonWithStrIterator struct {
	Event *TokenhubFailReasonWithStr // Event containing the contract specifics and raw log

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
func (it *TokenhubFailReasonWithStrIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubFailReasonWithStr)
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
		it.Event = new(TokenhubFailReasonWithStr)
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
func (it *TokenhubFailReasonWithStrIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubFailReasonWithStrIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubFailReasonWithStr represents a FailReasonWithStr event raised by the Tokenhub contract.
type TokenhubFailReasonWithStr struct {
	Message string
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterFailReasonWithStr is a free log retrieval operation binding the contract event 0x70e72399380dcfb0338abc03dc8d47f9f470ada8e769c9a78d644ea97385ecb2.
//
// Solidity: event failReasonWithStr(string message)
func (_Tokenhub *TokenhubFilterer) FilterFailReasonWithStr(opts *bind.FilterOpts) (*TokenhubFailReasonWithStrIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "failReasonWithStr")
	if err != nil {
		return nil, err
	}
	return &TokenhubFailReasonWithStrIterator{contract: _Tokenhub.contract, event: "failReasonWithStr", logs: logs, sub: sub}, nil
}

// WatchFailReasonWithStr is a free log subscription operation binding the contract event 0x70e72399380dcfb0338abc03dc8d47f9f470ada8e769c9a78d644ea97385ecb2.
//
// Solidity: event failReasonWithStr(string message)
func (_Tokenhub *TokenhubFilterer) WatchFailReasonWithStr(opts *bind.WatchOpts, sink chan<- *TokenhubFailReasonWithStr) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "failReasonWithStr")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubFailReasonWithStr)
				if err := _Tokenhub.contract.UnpackLog(event, "failReasonWithStr", log); err != nil {
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

// ParseFailReasonWithStr is a log parse operation binding the contract event 0x70e72399380dcfb0338abc03dc8d47f9f470ada8e769c9a78d644ea97385ecb2.
//
// Solidity: event failReasonWithStr(string message)
func (_Tokenhub *TokenhubFilterer) ParseFailReasonWithStr(log types.Log) (*TokenhubFailReasonWithStr, error) {
	event := new(TokenhubFailReasonWithStr)
	if err := _Tokenhub.contract.UnpackLog(event, "failReasonWithStr", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubParamChangeIterator is returned from FilterParamChange and is used to iterate over the raw logs and unpacked data for ParamChange events raised by the Tokenhub contract.
type TokenhubParamChangeIterator struct {
	Event *TokenhubParamChange // Event containing the contract specifics and raw log

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
func (it *TokenhubParamChangeIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubParamChange)
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
		it.Event = new(TokenhubParamChange)
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
func (it *TokenhubParamChangeIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubParamChangeIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubParamChange represents a ParamChange event raised by the Tokenhub contract.
type TokenhubParamChange struct {
	Key   string
	Value []byte
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterParamChange is a free log retrieval operation binding the contract event 0x6cdb0ac70ab7f2e2d035cca5be60d89906f2dede7648ddbd7402189c1eeed17a.
//
// Solidity: event paramChange(string key, bytes value)
func (_Tokenhub *TokenhubFilterer) FilterParamChange(opts *bind.FilterOpts) (*TokenhubParamChangeIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "paramChange")
	if err != nil {
		return nil, err
	}
	return &TokenhubParamChangeIterator{contract: _Tokenhub.contract, event: "paramChange", logs: logs, sub: sub}, nil
}

// WatchParamChange is a free log subscription operation binding the contract event 0x6cdb0ac70ab7f2e2d035cca5be60d89906f2dede7648ddbd7402189c1eeed17a.
//
// Solidity: event paramChange(string key, bytes value)
func (_Tokenhub *TokenhubFilterer) WatchParamChange(opts *bind.WatchOpts, sink chan<- *TokenhubParamChange) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "paramChange")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubParamChange)
				if err := _Tokenhub.contract.UnpackLog(event, "paramChange", log); err != nil {
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

// ParseParamChange is a log parse operation binding the contract event 0x6cdb0ac70ab7f2e2d035cca5be60d89906f2dede7648ddbd7402189c1eeed17a.
//
// Solidity: event paramChange(string key, bytes value)
func (_Tokenhub *TokenhubFilterer) ParseParamChange(log types.Log) (*TokenhubParamChange, error) {
	event := new(TokenhubParamChange)
	if err := _Tokenhub.contract.UnpackLog(event, "paramChange", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubSystemTransferIterator is returned from FilterSystemTransfer and is used to iterate over the raw logs and unpacked data for SystemTransfer events raised by the Tokenhub contract.
type TokenhubSystemTransferIterator struct {
	Event *TokenhubSystemTransfer // Event containing the contract specifics and raw log

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
func (it *TokenhubSystemTransferIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubSystemTransfer)
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
		it.Event = new(TokenhubSystemTransfer)
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
func (it *TokenhubSystemTransferIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubSystemTransferIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubSystemTransfer represents a SystemTransfer event raised by the Tokenhub contract.
type TokenhubSystemTransfer struct {
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterSystemTransfer is a free log retrieval operation binding the contract event 0x6ecc855f9440a9282c90913bbc91619fd44f5ec0b462af28d127b116f130aa4d.
//
// Solidity: event systemTransfer(uint256 amount)
func (_Tokenhub *TokenhubFilterer) FilterSystemTransfer(opts *bind.FilterOpts) (*TokenhubSystemTransferIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "systemTransfer")
	if err != nil {
		return nil, err
	}
	return &TokenhubSystemTransferIterator{contract: _Tokenhub.contract, event: "systemTransfer", logs: logs, sub: sub}, nil
}

// WatchSystemTransfer is a free log subscription operation binding the contract event 0x6ecc855f9440a9282c90913bbc91619fd44f5ec0b462af28d127b116f130aa4d.
//
// Solidity: event systemTransfer(uint256 amount)
func (_Tokenhub *TokenhubFilterer) WatchSystemTransfer(opts *bind.WatchOpts, sink chan<- *TokenhubSystemTransfer) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "systemTransfer")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubSystemTransfer)
				if err := _Tokenhub.contract.UnpackLog(event, "systemTransfer", log); err != nil {
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

// ParseSystemTransfer is a log parse operation binding the contract event 0x6ecc855f9440a9282c90913bbc91619fd44f5ec0b462af28d127b116f130aa4d.
//
// Solidity: event systemTransfer(uint256 amount)
func (_Tokenhub *TokenhubFilterer) ParseSystemTransfer(log types.Log) (*TokenhubSystemTransfer, error) {
	event := new(TokenhubSystemTransfer)
	if err := _Tokenhub.contract.UnpackLog(event, "systemTransfer", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubValidatorDepositIterator is returned from FilterValidatorDeposit and is used to iterate over the raw logs and unpacked data for ValidatorDeposit events raised by the Tokenhub contract.
type TokenhubValidatorDepositIterator struct {
	Event *TokenhubValidatorDeposit // Event containing the contract specifics and raw log

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
func (it *TokenhubValidatorDepositIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubValidatorDeposit)
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
		it.Event = new(TokenhubValidatorDeposit)
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
func (it *TokenhubValidatorDepositIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubValidatorDepositIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubValidatorDeposit represents a ValidatorDeposit event raised by the Tokenhub contract.
type TokenhubValidatorDeposit struct {
	Validator common.Address
	Amount    *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterValidatorDeposit is a free log retrieval operation binding the contract event 0x93a090ecc682c002995fad3c85b30c5651d7fd29b0be5da9d784a3302aedc055.
//
// Solidity: event validatorDeposit(address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) FilterValidatorDeposit(opts *bind.FilterOpts, validator []common.Address) (*TokenhubValidatorDepositIterator, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "validatorDeposit", validatorRule)
	if err != nil {
		return nil, err
	}
	return &TokenhubValidatorDepositIterator{contract: _Tokenhub.contract, event: "validatorDeposit", logs: logs, sub: sub}, nil
}

// WatchValidatorDeposit is a free log subscription operation binding the contract event 0x93a090ecc682c002995fad3c85b30c5651d7fd29b0be5da9d784a3302aedc055.
//
// Solidity: event validatorDeposit(address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) WatchValidatorDeposit(opts *bind.WatchOpts, sink chan<- *TokenhubValidatorDeposit, validator []common.Address) (event.Subscription, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "validatorDeposit", validatorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubValidatorDeposit)
				if err := _Tokenhub.contract.UnpackLog(event, "validatorDeposit", log); err != nil {
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

// ParseValidatorDeposit is a log parse operation binding the contract event 0x93a090ecc682c002995fad3c85b30c5651d7fd29b0be5da9d784a3302aedc055.
//
// Solidity: event validatorDeposit(address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) ParseValidatorDeposit(log types.Log) (*TokenhubValidatorDeposit, error) {
	event := new(TokenhubValidatorDeposit)
	if err := _Tokenhub.contract.UnpackLog(event, "validatorDeposit", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubValidatorEmptyJailedIterator is returned from FilterValidatorEmptyJailed and is used to iterate over the raw logs and unpacked data for ValidatorEmptyJailed events raised by the Tokenhub contract.
type TokenhubValidatorEmptyJailedIterator struct {
	Event *TokenhubValidatorEmptyJailed // Event containing the contract specifics and raw log

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
func (it *TokenhubValidatorEmptyJailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubValidatorEmptyJailed)
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
		it.Event = new(TokenhubValidatorEmptyJailed)
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
func (it *TokenhubValidatorEmptyJailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubValidatorEmptyJailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubValidatorEmptyJailed represents a ValidatorEmptyJailed event raised by the Tokenhub contract.
type TokenhubValidatorEmptyJailed struct {
	Validator common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterValidatorEmptyJailed is a free log retrieval operation binding the contract event 0xe209c46bebf57cf265d5d9009a00870e256d9150f3ed5281ab9d9eb3cec6e4be.
//
// Solidity: event validatorEmptyJailed(address indexed validator)
func (_Tokenhub *TokenhubFilterer) FilterValidatorEmptyJailed(opts *bind.FilterOpts, validator []common.Address) (*TokenhubValidatorEmptyJailedIterator, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "validatorEmptyJailed", validatorRule)
	if err != nil {
		return nil, err
	}
	return &TokenhubValidatorEmptyJailedIterator{contract: _Tokenhub.contract, event: "validatorEmptyJailed", logs: logs, sub: sub}, nil
}

// WatchValidatorEmptyJailed is a free log subscription operation binding the contract event 0xe209c46bebf57cf265d5d9009a00870e256d9150f3ed5281ab9d9eb3cec6e4be.
//
// Solidity: event validatorEmptyJailed(address indexed validator)
func (_Tokenhub *TokenhubFilterer) WatchValidatorEmptyJailed(opts *bind.WatchOpts, sink chan<- *TokenhubValidatorEmptyJailed, validator []common.Address) (event.Subscription, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "validatorEmptyJailed", validatorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubValidatorEmptyJailed)
				if err := _Tokenhub.contract.UnpackLog(event, "validatorEmptyJailed", log); err != nil {
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

// ParseValidatorEmptyJailed is a log parse operation binding the contract event 0xe209c46bebf57cf265d5d9009a00870e256d9150f3ed5281ab9d9eb3cec6e4be.
//
// Solidity: event validatorEmptyJailed(address indexed validator)
func (_Tokenhub *TokenhubFilterer) ParseValidatorEmptyJailed(log types.Log) (*TokenhubValidatorEmptyJailed, error) {
	event := new(TokenhubValidatorEmptyJailed)
	if err := _Tokenhub.contract.UnpackLog(event, "validatorEmptyJailed", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubValidatorFelonyIterator is returned from FilterValidatorFelony and is used to iterate over the raw logs and unpacked data for ValidatorFelony events raised by the Tokenhub contract.
type TokenhubValidatorFelonyIterator struct {
	Event *TokenhubValidatorFelony // Event containing the contract specifics and raw log

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
func (it *TokenhubValidatorFelonyIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubValidatorFelony)
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
		it.Event = new(TokenhubValidatorFelony)
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
func (it *TokenhubValidatorFelonyIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubValidatorFelonyIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubValidatorFelony represents a ValidatorFelony event raised by the Tokenhub contract.
type TokenhubValidatorFelony struct {
	Sequence  uint64
	Validator common.Address
	Amount    *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterValidatorFelony is a free log retrieval operation binding the contract event 0x7e770310e43f85c3dca97460dbe1484068514437298ff349e6052595a6ffbdb7.
//
// Solidity: event validatorFelony(uint64 indexed sequence, address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) FilterValidatorFelony(opts *bind.FilterOpts, sequence []uint64, validator []common.Address) (*TokenhubValidatorFelonyIterator, error) {

	var sequenceRule []interface{}
	for _, sequenceItem := range sequence {
		sequenceRule = append(sequenceRule, sequenceItem)
	}
	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "validatorFelony", sequenceRule, validatorRule)
	if err != nil {
		return nil, err
	}
	return &TokenhubValidatorFelonyIterator{contract: _Tokenhub.contract, event: "validatorFelony", logs: logs, sub: sub}, nil
}

// WatchValidatorFelony is a free log subscription operation binding the contract event 0x7e770310e43f85c3dca97460dbe1484068514437298ff349e6052595a6ffbdb7.
//
// Solidity: event validatorFelony(uint64 indexed sequence, address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) WatchValidatorFelony(opts *bind.WatchOpts, sink chan<- *TokenhubValidatorFelony, sequence []uint64, validator []common.Address) (event.Subscription, error) {

	var sequenceRule []interface{}
	for _, sequenceItem := range sequence {
		sequenceRule = append(sequenceRule, sequenceItem)
	}
	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "validatorFelony", sequenceRule, validatorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubValidatorFelony)
				if err := _Tokenhub.contract.UnpackLog(event, "validatorFelony", log); err != nil {
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

// ParseValidatorFelony is a log parse operation binding the contract event 0x7e770310e43f85c3dca97460dbe1484068514437298ff349e6052595a6ffbdb7.
//
// Solidity: event validatorFelony(uint64 indexed sequence, address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) ParseValidatorFelony(log types.Log) (*TokenhubValidatorFelony, error) {
	event := new(TokenhubValidatorFelony)
	if err := _Tokenhub.contract.UnpackLog(event, "validatorFelony", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubValidatorJailedIterator is returned from FilterValidatorJailed and is used to iterate over the raw logs and unpacked data for ValidatorJailed events raised by the Tokenhub contract.
type TokenhubValidatorJailedIterator struct {
	Event *TokenhubValidatorJailed // Event containing the contract specifics and raw log

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
func (it *TokenhubValidatorJailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubValidatorJailed)
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
		it.Event = new(TokenhubValidatorJailed)
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
func (it *TokenhubValidatorJailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubValidatorJailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubValidatorJailed represents a ValidatorJailed event raised by the Tokenhub contract.
type TokenhubValidatorJailed struct {
	Validator common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterValidatorJailed is a free log retrieval operation binding the contract event 0xf226e7d8f547ff903d9d419cf5f54e0d7d07efa9584135a53a057c5f1f27f49a.
//
// Solidity: event validatorJailed(address indexed validator)
func (_Tokenhub *TokenhubFilterer) FilterValidatorJailed(opts *bind.FilterOpts, validator []common.Address) (*TokenhubValidatorJailedIterator, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "validatorJailed", validatorRule)
	if err != nil {
		return nil, err
	}
	return &TokenhubValidatorJailedIterator{contract: _Tokenhub.contract, event: "validatorJailed", logs: logs, sub: sub}, nil
}

// WatchValidatorJailed is a free log subscription operation binding the contract event 0xf226e7d8f547ff903d9d419cf5f54e0d7d07efa9584135a53a057c5f1f27f49a.
//
// Solidity: event validatorJailed(address indexed validator)
func (_Tokenhub *TokenhubFilterer) WatchValidatorJailed(opts *bind.WatchOpts, sink chan<- *TokenhubValidatorJailed, validator []common.Address) (event.Subscription, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "validatorJailed", validatorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubValidatorJailed)
				if err := _Tokenhub.contract.UnpackLog(event, "validatorJailed", log); err != nil {
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

// ParseValidatorJailed is a log parse operation binding the contract event 0xf226e7d8f547ff903d9d419cf5f54e0d7d07efa9584135a53a057c5f1f27f49a.
//
// Solidity: event validatorJailed(address indexed validator)
func (_Tokenhub *TokenhubFilterer) ParseValidatorJailed(log types.Log) (*TokenhubValidatorJailed, error) {
	event := new(TokenhubValidatorJailed)
	if err := _Tokenhub.contract.UnpackLog(event, "validatorJailed", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubValidatorMisdemeanorIterator is returned from FilterValidatorMisdemeanor and is used to iterate over the raw logs and unpacked data for ValidatorMisdemeanor events raised by the Tokenhub contract.
type TokenhubValidatorMisdemeanorIterator struct {
	Event *TokenhubValidatorMisdemeanor // Event containing the contract specifics and raw log

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
func (it *TokenhubValidatorMisdemeanorIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubValidatorMisdemeanor)
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
		it.Event = new(TokenhubValidatorMisdemeanor)
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
func (it *TokenhubValidatorMisdemeanorIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubValidatorMisdemeanorIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubValidatorMisdemeanor represents a ValidatorMisdemeanor event raised by the Tokenhub contract.
type TokenhubValidatorMisdemeanor struct {
	Validator common.Address
	Amount    *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterValidatorMisdemeanor is a free log retrieval operation binding the contract event 0x8cd4e147d8af98a9e3b6724021b8bf6aed2e5dac71c38f2dce8161b82585b25d.
//
// Solidity: event validatorMisdemeanor(address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) FilterValidatorMisdemeanor(opts *bind.FilterOpts, validator []common.Address) (*TokenhubValidatorMisdemeanorIterator, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "validatorMisdemeanor", validatorRule)
	if err != nil {
		return nil, err
	}
	return &TokenhubValidatorMisdemeanorIterator{contract: _Tokenhub.contract, event: "validatorMisdemeanor", logs: logs, sub: sub}, nil
}

// WatchValidatorMisdemeanor is a free log subscription operation binding the contract event 0x8cd4e147d8af98a9e3b6724021b8bf6aed2e5dac71c38f2dce8161b82585b25d.
//
// Solidity: event validatorMisdemeanor(address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) WatchValidatorMisdemeanor(opts *bind.WatchOpts, sink chan<- *TokenhubValidatorMisdemeanor, validator []common.Address) (event.Subscription, error) {

	var validatorRule []interface{}
	for _, validatorItem := range validator {
		validatorRule = append(validatorRule, validatorItem)
	}

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "validatorMisdemeanor", validatorRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubValidatorMisdemeanor)
				if err := _Tokenhub.contract.UnpackLog(event, "validatorMisdemeanor", log); err != nil {
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

// ParseValidatorMisdemeanor is a log parse operation binding the contract event 0x8cd4e147d8af98a9e3b6724021b8bf6aed2e5dac71c38f2dce8161b82585b25d.
//
// Solidity: event validatorMisdemeanor(address indexed validator, uint256 amount)
func (_Tokenhub *TokenhubFilterer) ParseValidatorMisdemeanor(log types.Log) (*TokenhubValidatorMisdemeanor, error) {
	event := new(TokenhubValidatorMisdemeanor)
	if err := _Tokenhub.contract.UnpackLog(event, "validatorMisdemeanor", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubValidatorSetUpdatedIterator is returned from FilterValidatorSetUpdated and is used to iterate over the raw logs and unpacked data for ValidatorSetUpdated events raised by the Tokenhub contract.
type TokenhubValidatorSetUpdatedIterator struct {
	Event *TokenhubValidatorSetUpdated // Event containing the contract specifics and raw log

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
func (it *TokenhubValidatorSetUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubValidatorSetUpdated)
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
		it.Event = new(TokenhubValidatorSetUpdated)
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
func (it *TokenhubValidatorSetUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubValidatorSetUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubValidatorSetUpdated represents a ValidatorSetUpdated event raised by the Tokenhub contract.
type TokenhubValidatorSetUpdated struct {
	Raw types.Log // Blockchain specific contextual infos
}

// FilterValidatorSetUpdated is a free log retrieval operation binding the contract event 0xedd8d7296956dd970ab4de3f2fc03be2b0ffc615d20cd4c72c6e44f928630ebf.
//
// Solidity: event validatorSetUpdated()
func (_Tokenhub *TokenhubFilterer) FilterValidatorSetUpdated(opts *bind.FilterOpts) (*TokenhubValidatorSetUpdatedIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "validatorSetUpdated")
	if err != nil {
		return nil, err
	}
	return &TokenhubValidatorSetUpdatedIterator{contract: _Tokenhub.contract, event: "validatorSetUpdated", logs: logs, sub: sub}, nil
}

// WatchValidatorSetUpdated is a free log subscription operation binding the contract event 0xedd8d7296956dd970ab4de3f2fc03be2b0ffc615d20cd4c72c6e44f928630ebf.
//
// Solidity: event validatorSetUpdated()
func (_Tokenhub *TokenhubFilterer) WatchValidatorSetUpdated(opts *bind.WatchOpts, sink chan<- *TokenhubValidatorSetUpdated) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "validatorSetUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubValidatorSetUpdated)
				if err := _Tokenhub.contract.UnpackLog(event, "validatorSetUpdated", log); err != nil {
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

// ParseValidatorSetUpdated is a log parse operation binding the contract event 0xedd8d7296956dd970ab4de3f2fc03be2b0ffc615d20cd4c72c6e44f928630ebf.
//
// Solidity: event validatorSetUpdated()
func (_Tokenhub *TokenhubFilterer) ParseValidatorSetUpdated(log types.Log) (*TokenhubValidatorSetUpdated, error) {
	event := new(TokenhubValidatorSetUpdated)
	if err := _Tokenhub.contract.UnpackLog(event, "validatorSetUpdated", log); err != nil {
		return nil, err
	}
	return event, nil
}
