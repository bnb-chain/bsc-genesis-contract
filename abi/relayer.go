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
const TokenhubABI = "[{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"string\",\"name\":\"key\",\"type\":\"string\"},{\"indexed\":false,\"internalType\":\"bytes\",\"name\":\"value\",\"type\":\"bytes\"}],\"name\":\"paramChange\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"_relayer\",\"type\":\"address\"}],\"name\":\"relayerRegister\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"_relayer\",\"type\":\"address\"}],\"name\":\"relayerUnRegister\",\"type\":\"event\"},{\"constant\":true,\"inputs\":[],\"name\":\"GOV_HUB_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"INCENTIVIZE_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"INIT_DUES\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"INIT_REQUIRED_DEPOSIT\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"LIGHT_CLIENT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"RELAYERHUB_CONTRACT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"RELAYER_REWARD\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"SLASH_CONTRACT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"SYSTEM_REWARD_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"TOKEN_HUB_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"VALIDATOR_CONTRACT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"alreadyInit\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"dues\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[],\"name\":\"init\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"}],\"name\":\"isRelayer\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[],\"name\":\"register\",\"outputs\":[],\"payable\":true,\"stateMutability\":\"payable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"requiredDeposit\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[],\"name\":\"unregister\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"internalType\":\"string\",\"name\":\"key\",\"type\":\"string\"},{\"internalType\":\"bytes\",\"name\":\"value\",\"type\":\"bytes\"}],\"name\":\"updateParam\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]"

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

// INITDUES is a free data retrieval call binding the contract method 0x95468d26.
//
// Solidity: function INIT_DUES() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) INITDUES(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "INIT_DUES")
	return *ret0, err
}

// INITDUES is a free data retrieval call binding the contract method 0x95468d26.
//
// Solidity: function INIT_DUES() constant returns(uint256)
func (_Tokenhub *TokenhubSession) INITDUES() (*big.Int, error) {
	return _Tokenhub.Contract.INITDUES(&_Tokenhub.CallOpts)
}

// INITDUES is a free data retrieval call binding the contract method 0x95468d26.
//
// Solidity: function INIT_DUES() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) INITDUES() (*big.Int, error) {
	return _Tokenhub.Contract.INITDUES(&_Tokenhub.CallOpts)
}

// INITREQUIREDDEPOSIT is a free data retrieval call binding the contract method 0x7ae23088.
//
// Solidity: function INIT_REQUIRED_DEPOSIT() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) INITREQUIREDDEPOSIT(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "INIT_REQUIRED_DEPOSIT")
	return *ret0, err
}

// INITREQUIREDDEPOSIT is a free data retrieval call binding the contract method 0x7ae23088.
//
// Solidity: function INIT_REQUIRED_DEPOSIT() constant returns(uint256)
func (_Tokenhub *TokenhubSession) INITREQUIREDDEPOSIT() (*big.Int, error) {
	return _Tokenhub.Contract.INITREQUIREDDEPOSIT(&_Tokenhub.CallOpts)
}

// INITREQUIREDDEPOSIT is a free data retrieval call binding the contract method 0x7ae23088.
//
// Solidity: function INIT_REQUIRED_DEPOSIT() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) INITREQUIREDDEPOSIT() (*big.Int, error) {
	return _Tokenhub.Contract.INITREQUIREDDEPOSIT(&_Tokenhub.CallOpts)
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

// Dues is a free data retrieval call binding the contract method 0x6a87d780.
//
// Solidity: function dues() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) Dues(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "dues")
	return *ret0, err
}

// Dues is a free data retrieval call binding the contract method 0x6a87d780.
//
// Solidity: function dues() constant returns(uint256)
func (_Tokenhub *TokenhubSession) Dues() (*big.Int, error) {
	return _Tokenhub.Contract.Dues(&_Tokenhub.CallOpts)
}

// Dues is a free data retrieval call binding the contract method 0x6a87d780.
//
// Solidity: function dues() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) Dues() (*big.Int, error) {
	return _Tokenhub.Contract.Dues(&_Tokenhub.CallOpts)
}

// IsRelayer is a free data retrieval call binding the contract method 0x541d5548.
//
// Solidity: function isRelayer(address sender) constant returns(bool)
func (_Tokenhub *TokenhubCaller) IsRelayer(opts *bind.CallOpts, sender common.Address) (bool, error) {
	var (
		ret0 = new(bool)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "isRelayer", sender)
	return *ret0, err
}

// IsRelayer is a free data retrieval call binding the contract method 0x541d5548.
//
// Solidity: function isRelayer(address sender) constant returns(bool)
func (_Tokenhub *TokenhubSession) IsRelayer(sender common.Address) (bool, error) {
	return _Tokenhub.Contract.IsRelayer(&_Tokenhub.CallOpts, sender)
}

// IsRelayer is a free data retrieval call binding the contract method 0x541d5548.
//
// Solidity: function isRelayer(address sender) constant returns(bool)
func (_Tokenhub *TokenhubCallerSession) IsRelayer(sender common.Address) (bool, error) {
	return _Tokenhub.Contract.IsRelayer(&_Tokenhub.CallOpts, sender)
}

// RequiredDeposit is a free data retrieval call binding the contract method 0xfb7cfdd7.
//
// Solidity: function requiredDeposit() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) RequiredDeposit(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "requiredDeposit")
	return *ret0, err
}

// RequiredDeposit is a free data retrieval call binding the contract method 0xfb7cfdd7.
//
// Solidity: function requiredDeposit() constant returns(uint256)
func (_Tokenhub *TokenhubSession) RequiredDeposit() (*big.Int, error) {
	return _Tokenhub.Contract.RequiredDeposit(&_Tokenhub.CallOpts)
}

// RequiredDeposit is a free data retrieval call binding the contract method 0xfb7cfdd7.
//
// Solidity: function requiredDeposit() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) RequiredDeposit() (*big.Int, error) {
	return _Tokenhub.Contract.RequiredDeposit(&_Tokenhub.CallOpts)
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

// Register is a paid mutator transaction binding the contract method 0x1aa3a008.
//
// Solidity: function register() returns()
func (_Tokenhub *TokenhubTransactor) Register(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "register")
}

// Register is a paid mutator transaction binding the contract method 0x1aa3a008.
//
// Solidity: function register() returns()
func (_Tokenhub *TokenhubSession) Register() (*types.Transaction, error) {
	return _Tokenhub.Contract.Register(&_Tokenhub.TransactOpts)
}

// Register is a paid mutator transaction binding the contract method 0x1aa3a008.
//
// Solidity: function register() returns()
func (_Tokenhub *TokenhubTransactorSession) Register() (*types.Transaction, error) {
	return _Tokenhub.Contract.Register(&_Tokenhub.TransactOpts)
}

// Unregister is a paid mutator transaction binding the contract method 0xe79a198f.
//
// Solidity: function unregister() returns()
func (_Tokenhub *TokenhubTransactor) Unregister(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "unregister")
}

// Unregister is a paid mutator transaction binding the contract method 0xe79a198f.
//
// Solidity: function unregister() returns()
func (_Tokenhub *TokenhubSession) Unregister() (*types.Transaction, error) {
	return _Tokenhub.Contract.Unregister(&_Tokenhub.TransactOpts)
}

// Unregister is a paid mutator transaction binding the contract method 0xe79a198f.
//
// Solidity: function unregister() returns()
func (_Tokenhub *TokenhubTransactorSession) Unregister() (*types.Transaction, error) {
	return _Tokenhub.Contract.Unregister(&_Tokenhub.TransactOpts)
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

// TokenhubRelayerRegisterIterator is returned from FilterRelayerRegister and is used to iterate over the raw logs and unpacked data for RelayerRegister events raised by the Tokenhub contract.
type TokenhubRelayerRegisterIterator struct {
	Event *TokenhubRelayerRegister // Event containing the contract specifics and raw log

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
func (it *TokenhubRelayerRegisterIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubRelayerRegister)
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
		it.Event = new(TokenhubRelayerRegister)
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
func (it *TokenhubRelayerRegisterIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubRelayerRegisterIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubRelayerRegister represents a RelayerRegister event raised by the Tokenhub contract.
type TokenhubRelayerRegister struct {
	Relayer common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRelayerRegister is a free log retrieval operation binding the contract event 0xdb33a09d38b59a8fa8b7d92a1d82c8015e99f05f67ae9c9ae623157767959496.
//
// Solidity: event relayerRegister(address _relayer)
func (_Tokenhub *TokenhubFilterer) FilterRelayerRegister(opts *bind.FilterOpts) (*TokenhubRelayerRegisterIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "relayerRegister")
	if err != nil {
		return nil, err
	}
	return &TokenhubRelayerRegisterIterator{contract: _Tokenhub.contract, event: "relayerRegister", logs: logs, sub: sub}, nil
}

// WatchRelayerRegister is a free log subscription operation binding the contract event 0xdb33a09d38b59a8fa8b7d92a1d82c8015e99f05f67ae9c9ae623157767959496.
//
// Solidity: event relayerRegister(address _relayer)
func (_Tokenhub *TokenhubFilterer) WatchRelayerRegister(opts *bind.WatchOpts, sink chan<- *TokenhubRelayerRegister) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "relayerRegister")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubRelayerRegister)
				if err := _Tokenhub.contract.UnpackLog(event, "relayerRegister", log); err != nil {
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

// ParseRelayerRegister is a log parse operation binding the contract event 0xdb33a09d38b59a8fa8b7d92a1d82c8015e99f05f67ae9c9ae623157767959496.
//
// Solidity: event relayerRegister(address _relayer)
func (_Tokenhub *TokenhubFilterer) ParseRelayerRegister(log types.Log) (*TokenhubRelayerRegister, error) {
	event := new(TokenhubRelayerRegister)
	if err := _Tokenhub.contract.UnpackLog(event, "relayerRegister", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubRelayerUnRegisterIterator is returned from FilterRelayerUnRegister and is used to iterate over the raw logs and unpacked data for RelayerUnRegister events raised by the Tokenhub contract.
type TokenhubRelayerUnRegisterIterator struct {
	Event *TokenhubRelayerUnRegister // Event containing the contract specifics and raw log

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
func (it *TokenhubRelayerUnRegisterIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubRelayerUnRegister)
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
		it.Event = new(TokenhubRelayerUnRegister)
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
func (it *TokenhubRelayerUnRegisterIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubRelayerUnRegisterIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubRelayerUnRegister represents a RelayerUnRegister event raised by the Tokenhub contract.
type TokenhubRelayerUnRegister struct {
	Relayer common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRelayerUnRegister is a free log retrieval operation binding the contract event 0xd17202129b83db7880d6b9f25df81c58ad46f7e0e2c92236b1aa10663a487667.
//
// Solidity: event relayerUnRegister(address _relayer)
func (_Tokenhub *TokenhubFilterer) FilterRelayerUnRegister(opts *bind.FilterOpts) (*TokenhubRelayerUnRegisterIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "relayerUnRegister")
	if err != nil {
		return nil, err
	}
	return &TokenhubRelayerUnRegisterIterator{contract: _Tokenhub.contract, event: "relayerUnRegister", logs: logs, sub: sub}, nil
}

// WatchRelayerUnRegister is a free log subscription operation binding the contract event 0xd17202129b83db7880d6b9f25df81c58ad46f7e0e2c92236b1aa10663a487667.
//
// Solidity: event relayerUnRegister(address _relayer)
func (_Tokenhub *TokenhubFilterer) WatchRelayerUnRegister(opts *bind.WatchOpts, sink chan<- *TokenhubRelayerUnRegister) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "relayerUnRegister")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubRelayerUnRegister)
				if err := _Tokenhub.contract.UnpackLog(event, "relayerUnRegister", log); err != nil {
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

// ParseRelayerUnRegister is a log parse operation binding the contract event 0xd17202129b83db7880d6b9f25df81c58ad46f7e0e2c92236b1aa10663a487667.
//
// Solidity: event relayerUnRegister(address _relayer)
func (_Tokenhub *TokenhubFilterer) ParseRelayerUnRegister(log types.Log) (*TokenhubRelayerUnRegister, error) {
	event := new(TokenhubRelayerUnRegister)
	if err := _Tokenhub.contract.UnpackLog(event, "relayerUnRegister", log); err != nil {
		return nil, err
	}
	return event, nil
}
