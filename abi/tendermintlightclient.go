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
const TokenhubABI = "[{\"inputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"constructor\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"initHeight\",\"type\":\"uint64\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"appHash\",\"type\":\"bytes32\"}],\"name\":\"InitConsensusState\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"height\",\"type\":\"uint64\"},{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"preValidatorSetChangeHeight\",\"type\":\"uint64\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"appHash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"bool\",\"name\":\"validatorChanged\",\"type\":\"bool\"}],\"name\":\"SyncConsensusState\",\"type\":\"event\"},{\"constant\":true,\"inputs\":[],\"name\":\"GOV_HUB_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"INCENTIVIZE_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"INIT_CONSENSUS_STATE_BYTES\",\"outputs\":[{\"internalType\":\"bytes\",\"name\":\"\",\"type\":\"bytes\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"LIGHT_CLIENT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"RELAYERHUB_CONTRACT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"RELAYER_REWARD\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"SLASH_CONTRACT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"SYSTEM_REWARD_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"TOKEN_HUB_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"VALIDATOR_CONTRACT_ADDR\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"name\":\"_BBCLightClientConsensusState\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"preValidatorSetChangeHeight\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"appHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"curValidatorSetHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes\",\"name\":\"nextValidatorSet\",\"type\":\"bytes\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"_alreadyInit\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"_chainID\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"_initialHeight\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"_latestHeight\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"name\":\"_submitters\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"height\",\"type\":\"uint64\"}],\"name\":\"getAppHash\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"getChainID\",\"outputs\":[{\"internalType\":\"string\",\"name\":\"\",\"type\":\"string\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"height\",\"type\":\"uint64\"}],\"name\":\"getSubmitter\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[],\"name\":\"init\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"height\",\"type\":\"uint64\"}],\"name\":\"isHeaderSynced\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"rewardForValidatorSetChange\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"internalType\":\"bytes\",\"name\":\"header\",\"type\":\"bytes\"},{\"internalType\":\"uint64\",\"name\":\"height\",\"type\":\"uint64\"}],\"name\":\"syncTendermintHeader\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]"

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

// INITCONSENSUSSTATEBYTES is a free data retrieval call binding the contract method 0xea54b2aa.
//
// Solidity: function INIT_CONSENSUS_STATE_BYTES() constant returns(bytes)
func (_Tokenhub *TokenhubCaller) INITCONSENSUSSTATEBYTES(opts *bind.CallOpts) ([]byte, error) {
	var (
		ret0 = new([]byte)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "INIT_CONSENSUS_STATE_BYTES")
	return *ret0, err
}

// INITCONSENSUSSTATEBYTES is a free data retrieval call binding the contract method 0xea54b2aa.
//
// Solidity: function INIT_CONSENSUS_STATE_BYTES() constant returns(bytes)
func (_Tokenhub *TokenhubSession) INITCONSENSUSSTATEBYTES() ([]byte, error) {
	return _Tokenhub.Contract.INITCONSENSUSSTATEBYTES(&_Tokenhub.CallOpts)
}

// INITCONSENSUSSTATEBYTES is a free data retrieval call binding the contract method 0xea54b2aa.
//
// Solidity: function INIT_CONSENSUS_STATE_BYTES() constant returns(bytes)
func (_Tokenhub *TokenhubCallerSession) INITCONSENSUSSTATEBYTES() ([]byte, error) {
	return _Tokenhub.Contract.INITCONSENSUSSTATEBYTES(&_Tokenhub.CallOpts)
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

// BBCLightClientConsensusState is a free data retrieval call binding the contract method 0xa9bfd0f1.
//
// Solidity: function _BBCLightClientConsensusState(uint64 ) constant returns(uint64 preValidatorSetChangeHeight, bytes32 appHash, bytes32 curValidatorSetHash, bytes nextValidatorSet)
func (_Tokenhub *TokenhubCaller) BBCLightClientConsensusState(opts *bind.CallOpts, arg0 uint64) (struct {
	PreValidatorSetChangeHeight uint64
	AppHash                     [32]byte
	CurValidatorSetHash         [32]byte
	NextValidatorSet            []byte
}, error) {
	ret := new(struct {
		PreValidatorSetChangeHeight uint64
		AppHash                     [32]byte
		CurValidatorSetHash         [32]byte
		NextValidatorSet            []byte
	})
	out := ret
	err := _Tokenhub.contract.Call(opts, out, "_BBCLightClientConsensusState", arg0)
	return *ret, err
}

// BBCLightClientConsensusState is a free data retrieval call binding the contract method 0xa9bfd0f1.
//
// Solidity: function _BBCLightClientConsensusState(uint64 ) constant returns(uint64 preValidatorSetChangeHeight, bytes32 appHash, bytes32 curValidatorSetHash, bytes nextValidatorSet)
func (_Tokenhub *TokenhubSession) BBCLightClientConsensusState(arg0 uint64) (struct {
	PreValidatorSetChangeHeight uint64
	AppHash                     [32]byte
	CurValidatorSetHash         [32]byte
	NextValidatorSet            []byte
}, error) {
	return _Tokenhub.Contract.BBCLightClientConsensusState(&_Tokenhub.CallOpts, arg0)
}

// BBCLightClientConsensusState is a free data retrieval call binding the contract method 0xa9bfd0f1.
//
// Solidity: function _BBCLightClientConsensusState(uint64 ) constant returns(uint64 preValidatorSetChangeHeight, bytes32 appHash, bytes32 curValidatorSetHash, bytes nextValidatorSet)
func (_Tokenhub *TokenhubCallerSession) BBCLightClientConsensusState(arg0 uint64) (struct {
	PreValidatorSetChangeHeight uint64
	AppHash                     [32]byte
	CurValidatorSetHash         [32]byte
	NextValidatorSet            []byte
}, error) {
	return _Tokenhub.Contract.BBCLightClientConsensusState(&_Tokenhub.CallOpts, arg0)
}

// AlreadyInit is a free data retrieval call binding the contract method 0x6547bb06.
//
// Solidity: function _alreadyInit() constant returns(bool)
func (_Tokenhub *TokenhubCaller) AlreadyInit(opts *bind.CallOpts) (bool, error) {
	var (
		ret0 = new(bool)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "_alreadyInit")
	return *ret0, err
}

// AlreadyInit is a free data retrieval call binding the contract method 0x6547bb06.
//
// Solidity: function _alreadyInit() constant returns(bool)
func (_Tokenhub *TokenhubSession) AlreadyInit() (bool, error) {
	return _Tokenhub.Contract.AlreadyInit(&_Tokenhub.CallOpts)
}

// AlreadyInit is a free data retrieval call binding the contract method 0x6547bb06.
//
// Solidity: function _alreadyInit() constant returns(bool)
func (_Tokenhub *TokenhubCallerSession) AlreadyInit() (bool, error) {
	return _Tokenhub.Contract.AlreadyInit(&_Tokenhub.CallOpts)
}

// ChainID is a free data retrieval call binding the contract method 0xbeab7131.
//
// Solidity: function _chainID() constant returns(bytes32)
func (_Tokenhub *TokenhubCaller) ChainID(opts *bind.CallOpts) ([32]byte, error) {
	var (
		ret0 = new([32]byte)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "_chainID")
	return *ret0, err
}

// ChainID is a free data retrieval call binding the contract method 0xbeab7131.
//
// Solidity: function _chainID() constant returns(bytes32)
func (_Tokenhub *TokenhubSession) ChainID() ([32]byte, error) {
	return _Tokenhub.Contract.ChainID(&_Tokenhub.CallOpts)
}

// ChainID is a free data retrieval call binding the contract method 0xbeab7131.
//
// Solidity: function _chainID() constant returns(bytes32)
func (_Tokenhub *TokenhubCallerSession) ChainID() ([32]byte, error) {
	return _Tokenhub.Contract.ChainID(&_Tokenhub.CallOpts)
}

// InitialHeight is a free data retrieval call binding the contract method 0x3ae6005d.
//
// Solidity: function _initialHeight() constant returns(uint64)
func (_Tokenhub *TokenhubCaller) InitialHeight(opts *bind.CallOpts) (uint64, error) {
	var (
		ret0 = new(uint64)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "_initialHeight")
	return *ret0, err
}

// InitialHeight is a free data retrieval call binding the contract method 0x3ae6005d.
//
// Solidity: function _initialHeight() constant returns(uint64)
func (_Tokenhub *TokenhubSession) InitialHeight() (uint64, error) {
	return _Tokenhub.Contract.InitialHeight(&_Tokenhub.CallOpts)
}

// InitialHeight is a free data retrieval call binding the contract method 0x3ae6005d.
//
// Solidity: function _initialHeight() constant returns(uint64)
func (_Tokenhub *TokenhubCallerSession) InitialHeight() (uint64, error) {
	return _Tokenhub.Contract.InitialHeight(&_Tokenhub.CallOpts)
}

// LatestHeight is a free data retrieval call binding the contract method 0x7945c2f3.
//
// Solidity: function _latestHeight() constant returns(uint64)
func (_Tokenhub *TokenhubCaller) LatestHeight(opts *bind.CallOpts) (uint64, error) {
	var (
		ret0 = new(uint64)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "_latestHeight")
	return *ret0, err
}

// LatestHeight is a free data retrieval call binding the contract method 0x7945c2f3.
//
// Solidity: function _latestHeight() constant returns(uint64)
func (_Tokenhub *TokenhubSession) LatestHeight() (uint64, error) {
	return _Tokenhub.Contract.LatestHeight(&_Tokenhub.CallOpts)
}

// LatestHeight is a free data retrieval call binding the contract method 0x7945c2f3.
//
// Solidity: function _latestHeight() constant returns(uint64)
func (_Tokenhub *TokenhubCallerSession) LatestHeight() (uint64, error) {
	return _Tokenhub.Contract.LatestHeight(&_Tokenhub.CallOpts)
}

// Submitters is a free data retrieval call binding the contract method 0xbc53477e.
//
// Solidity: function _submitters(uint64 ) constant returns(address)
func (_Tokenhub *TokenhubCaller) Submitters(opts *bind.CallOpts, arg0 uint64) (common.Address, error) {
	var (
		ret0 = new(common.Address)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "_submitters", arg0)
	return *ret0, err
}

// Submitters is a free data retrieval call binding the contract method 0xbc53477e.
//
// Solidity: function _submitters(uint64 ) constant returns(address)
func (_Tokenhub *TokenhubSession) Submitters(arg0 uint64) (common.Address, error) {
	return _Tokenhub.Contract.Submitters(&_Tokenhub.CallOpts, arg0)
}

// Submitters is a free data retrieval call binding the contract method 0xbc53477e.
//
// Solidity: function _submitters(uint64 ) constant returns(address)
func (_Tokenhub *TokenhubCallerSession) Submitters(arg0 uint64) (common.Address, error) {
	return _Tokenhub.Contract.Submitters(&_Tokenhub.CallOpts, arg0)
}

// GetAppHash is a free data retrieval call binding the contract method 0xcba510a9.
//
// Solidity: function getAppHash(uint64 height) constant returns(bytes32)
func (_Tokenhub *TokenhubCaller) GetAppHash(opts *bind.CallOpts, height uint64) ([32]byte, error) {
	var (
		ret0 = new([32]byte)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "getAppHash", height)
	return *ret0, err
}

// GetAppHash is a free data retrieval call binding the contract method 0xcba510a9.
//
// Solidity: function getAppHash(uint64 height) constant returns(bytes32)
func (_Tokenhub *TokenhubSession) GetAppHash(height uint64) ([32]byte, error) {
	return _Tokenhub.Contract.GetAppHash(&_Tokenhub.CallOpts, height)
}

// GetAppHash is a free data retrieval call binding the contract method 0xcba510a9.
//
// Solidity: function getAppHash(uint64 height) constant returns(bytes32)
func (_Tokenhub *TokenhubCallerSession) GetAppHash(height uint64) ([32]byte, error) {
	return _Tokenhub.Contract.GetAppHash(&_Tokenhub.CallOpts, height)
}

// GetChainID is a free data retrieval call binding the contract method 0x564b81ef.
//
// Solidity: function getChainID() constant returns(string)
func (_Tokenhub *TokenhubCaller) GetChainID(opts *bind.CallOpts) (string, error) {
	var (
		ret0 = new(string)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "getChainID")
	return *ret0, err
}

// GetChainID is a free data retrieval call binding the contract method 0x564b81ef.
//
// Solidity: function getChainID() constant returns(string)
func (_Tokenhub *TokenhubSession) GetChainID() (string, error) {
	return _Tokenhub.Contract.GetChainID(&_Tokenhub.CallOpts)
}

// GetChainID is a free data retrieval call binding the contract method 0x564b81ef.
//
// Solidity: function getChainID() constant returns(string)
func (_Tokenhub *TokenhubCallerSession) GetChainID() (string, error) {
	return _Tokenhub.Contract.GetChainID(&_Tokenhub.CallOpts)
}

// GetSubmitter is a free data retrieval call binding the contract method 0xdda83148.
//
// Solidity: function getSubmitter(uint64 height) constant returns(address)
func (_Tokenhub *TokenhubCaller) GetSubmitter(opts *bind.CallOpts, height uint64) (common.Address, error) {
	var (
		ret0 = new(common.Address)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "getSubmitter", height)
	return *ret0, err
}

// GetSubmitter is a free data retrieval call binding the contract method 0xdda83148.
//
// Solidity: function getSubmitter(uint64 height) constant returns(address)
func (_Tokenhub *TokenhubSession) GetSubmitter(height uint64) (common.Address, error) {
	return _Tokenhub.Contract.GetSubmitter(&_Tokenhub.CallOpts, height)
}

// GetSubmitter is a free data retrieval call binding the contract method 0xdda83148.
//
// Solidity: function getSubmitter(uint64 height) constant returns(address)
func (_Tokenhub *TokenhubCallerSession) GetSubmitter(height uint64) (common.Address, error) {
	return _Tokenhub.Contract.GetSubmitter(&_Tokenhub.CallOpts, height)
}

// IsHeaderSynced is a free data retrieval call binding the contract method 0xdf5fe704.
//
// Solidity: function isHeaderSynced(uint64 height) constant returns(bool)
func (_Tokenhub *TokenhubCaller) IsHeaderSynced(opts *bind.CallOpts, height uint64) (bool, error) {
	var (
		ret0 = new(bool)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "isHeaderSynced", height)
	return *ret0, err
}

// IsHeaderSynced is a free data retrieval call binding the contract method 0xdf5fe704.
//
// Solidity: function isHeaderSynced(uint64 height) constant returns(bool)
func (_Tokenhub *TokenhubSession) IsHeaderSynced(height uint64) (bool, error) {
	return _Tokenhub.Contract.IsHeaderSynced(&_Tokenhub.CallOpts, height)
}

// IsHeaderSynced is a free data retrieval call binding the contract method 0xdf5fe704.
//
// Solidity: function isHeaderSynced(uint64 height) constant returns(bool)
func (_Tokenhub *TokenhubCallerSession) IsHeaderSynced(height uint64) (bool, error) {
	return _Tokenhub.Contract.IsHeaderSynced(&_Tokenhub.CallOpts, height)
}

// RewardForValidatorSetChange is a free data retrieval call binding the contract method 0x33f7798d.
//
// Solidity: function rewardForValidatorSetChange() constant returns(uint256)
func (_Tokenhub *TokenhubCaller) RewardForValidatorSetChange(opts *bind.CallOpts) (*big.Int, error) {
	var (
		ret0 = new(*big.Int)
	)
	out := ret0
	err := _Tokenhub.contract.Call(opts, out, "rewardForValidatorSetChange")
	return *ret0, err
}

// RewardForValidatorSetChange is a free data retrieval call binding the contract method 0x33f7798d.
//
// Solidity: function rewardForValidatorSetChange() constant returns(uint256)
func (_Tokenhub *TokenhubSession) RewardForValidatorSetChange() (*big.Int, error) {
	return _Tokenhub.Contract.RewardForValidatorSetChange(&_Tokenhub.CallOpts)
}

// RewardForValidatorSetChange is a free data retrieval call binding the contract method 0x33f7798d.
//
// Solidity: function rewardForValidatorSetChange() constant returns(uint256)
func (_Tokenhub *TokenhubCallerSession) RewardForValidatorSetChange() (*big.Int, error) {
	return _Tokenhub.Contract.RewardForValidatorSetChange(&_Tokenhub.CallOpts)
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

// SyncTendermintHeader is a paid mutator transaction binding the contract method 0xd8169879.
//
// Solidity: function syncTendermintHeader(bytes header, uint64 height) returns(bool)
func (_Tokenhub *TokenhubTransactor) SyncTendermintHeader(opts *bind.TransactOpts, header []byte, height uint64) (*types.Transaction, error) {
	return _Tokenhub.contract.Transact(opts, "syncTendermintHeader", header, height)
}

// SyncTendermintHeader is a paid mutator transaction binding the contract method 0xd8169879.
//
// Solidity: function syncTendermintHeader(bytes header, uint64 height) returns(bool)
func (_Tokenhub *TokenhubSession) SyncTendermintHeader(header []byte, height uint64) (*types.Transaction, error) {
	return _Tokenhub.Contract.SyncTendermintHeader(&_Tokenhub.TransactOpts, header, height)
}

// SyncTendermintHeader is a paid mutator transaction binding the contract method 0xd8169879.
//
// Solidity: function syncTendermintHeader(bytes header, uint64 height) returns(bool)
func (_Tokenhub *TokenhubTransactorSession) SyncTendermintHeader(header []byte, height uint64) (*types.Transaction, error) {
	return _Tokenhub.Contract.SyncTendermintHeader(&_Tokenhub.TransactOpts, header, height)
}

// TokenhubInitConsensusStateIterator is returned from FilterInitConsensusState and is used to iterate over the raw logs and unpacked data for InitConsensusState events raised by the Tokenhub contract.
type TokenhubInitConsensusStateIterator struct {
	Event *TokenhubInitConsensusState // Event containing the contract specifics and raw log

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
func (it *TokenhubInitConsensusStateIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubInitConsensusState)
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
		it.Event = new(TokenhubInitConsensusState)
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
func (it *TokenhubInitConsensusStateIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubInitConsensusStateIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubInitConsensusState represents a InitConsensusState event raised by the Tokenhub contract.
type TokenhubInitConsensusState struct {
	InitHeight uint64
	AppHash    [32]byte
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterInitConsensusState is a free log retrieval operation binding the contract event 0x6d0670f0a020e865a8cacaeeb070b48d5522fd0f687bcbb111a1d6c9b6ae66ab.
//
// Solidity: event InitConsensusState(uint64 initHeight, bytes32 appHash)
func (_Tokenhub *TokenhubFilterer) FilterInitConsensusState(opts *bind.FilterOpts) (*TokenhubInitConsensusStateIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "InitConsensusState")
	if err != nil {
		return nil, err
	}
	return &TokenhubInitConsensusStateIterator{contract: _Tokenhub.contract, event: "InitConsensusState", logs: logs, sub: sub}, nil
}

// WatchInitConsensusState is a free log subscription operation binding the contract event 0x6d0670f0a020e865a8cacaeeb070b48d5522fd0f687bcbb111a1d6c9b6ae66ab.
//
// Solidity: event InitConsensusState(uint64 initHeight, bytes32 appHash)
func (_Tokenhub *TokenhubFilterer) WatchInitConsensusState(opts *bind.WatchOpts, sink chan<- *TokenhubInitConsensusState) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "InitConsensusState")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubInitConsensusState)
				if err := _Tokenhub.contract.UnpackLog(event, "InitConsensusState", log); err != nil {
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

// ParseInitConsensusState is a log parse operation binding the contract event 0x6d0670f0a020e865a8cacaeeb070b48d5522fd0f687bcbb111a1d6c9b6ae66ab.
//
// Solidity: event InitConsensusState(uint64 initHeight, bytes32 appHash)
func (_Tokenhub *TokenhubFilterer) ParseInitConsensusState(log types.Log) (*TokenhubInitConsensusState, error) {
	event := new(TokenhubInitConsensusState)
	if err := _Tokenhub.contract.UnpackLog(event, "InitConsensusState", log); err != nil {
		return nil, err
	}
	return event, nil
}

// TokenhubSyncConsensusStateIterator is returned from FilterSyncConsensusState and is used to iterate over the raw logs and unpacked data for SyncConsensusState events raised by the Tokenhub contract.
type TokenhubSyncConsensusStateIterator struct {
	Event *TokenhubSyncConsensusState // Event containing the contract specifics and raw log

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
func (it *TokenhubSyncConsensusStateIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenhubSyncConsensusState)
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
		it.Event = new(TokenhubSyncConsensusState)
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
func (it *TokenhubSyncConsensusStateIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenhubSyncConsensusStateIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenhubSyncConsensusState represents a SyncConsensusState event raised by the Tokenhub contract.
type TokenhubSyncConsensusState struct {
	Height                      uint64
	PreValidatorSetChangeHeight uint64
	AppHash                     [32]byte
	ValidatorChanged            bool
	Raw                         types.Log // Blockchain specific contextual infos
}

// FilterSyncConsensusState is a free log retrieval operation binding the contract event 0x2641c9932368bef6eec1f666e32e7cba680c3e4c6e158a449d1f2601ad47926e.
//
// Solidity: event SyncConsensusState(uint64 height, uint64 preValidatorSetChangeHeight, bytes32 appHash, bool validatorChanged)
func (_Tokenhub *TokenhubFilterer) FilterSyncConsensusState(opts *bind.FilterOpts) (*TokenhubSyncConsensusStateIterator, error) {

	logs, sub, err := _Tokenhub.contract.FilterLogs(opts, "SyncConsensusState")
	if err != nil {
		return nil, err
	}
	return &TokenhubSyncConsensusStateIterator{contract: _Tokenhub.contract, event: "SyncConsensusState", logs: logs, sub: sub}, nil
}

// WatchSyncConsensusState is a free log subscription operation binding the contract event 0x2641c9932368bef6eec1f666e32e7cba680c3e4c6e158a449d1f2601ad47926e.
//
// Solidity: event SyncConsensusState(uint64 height, uint64 preValidatorSetChangeHeight, bytes32 appHash, bool validatorChanged)
func (_Tokenhub *TokenhubFilterer) WatchSyncConsensusState(opts *bind.WatchOpts, sink chan<- *TokenhubSyncConsensusState) (event.Subscription, error) {

	logs, sub, err := _Tokenhub.contract.WatchLogs(opts, "SyncConsensusState")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenhubSyncConsensusState)
				if err := _Tokenhub.contract.UnpackLog(event, "SyncConsensusState", log); err != nil {
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

// ParseSyncConsensusState is a log parse operation binding the contract event 0x2641c9932368bef6eec1f666e32e7cba680c3e4c6e158a449d1f2601ad47926e.
//
// Solidity: event SyncConsensusState(uint64 height, uint64 preValidatorSetChangeHeight, bytes32 appHash, bool validatorChanged)
func (_Tokenhub *TokenhubFilterer) ParseSyncConsensusState(log types.Log) (*TokenhubSyncConsensusState, error) {
	event := new(TokenhubSyncConsensusState)
	if err := _Tokenhub.contract.UnpackLog(event, "SyncConsensusState", log); err != nil {
		return nil, err
	}
	return event, nil
}
