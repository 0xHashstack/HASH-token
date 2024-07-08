// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract HashWallet is AccessControl {
    error HashWallet__AddressZero();
    error HashWallet__AddressNotUnique();
    error HashWallet__NotEnoughOwners();
    error HashWallet__CallerIsNotOwner();
    error HashWallet__TxDoesNotExists();
    error HashWallet__TxAlreadyExecuted();
    error HashWallet__TxAlreadyConfirmed();
    error HashWallet__TxNotConfirmed();
    error HashWallet__TxFailed();
    error HashWallet__InvallidPermissionNumber();
    error HashWallet__InvalidOwnersLength();

    event SubmitTransaction(
        address indexed owner, uint256 indexed txIndex, address indexed to, uint256 value, bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    bytes32 public constant SUPER_ADMIN = keccak256("SUPER_ADMIN");
    bytes32 public constant ADMIN = keccak256("ADMIN");

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numConfirmationsRequired;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    // mapping from tx index => owner => bool
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    // Transaction[] public transactions;

    mapping(uint256 => Transaction) transactions;
    uint256 numOfTransactions;

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert HashWallet__CallerIsNotOwner();
        _;
    }

    modifier txExists(uint256 _txIndex) {
        if (_txIndex > numOfTransactions) revert HashWallet__TxDoesNotExists();
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        if (transactions[_txIndex].executed) revert HashWallet__TxAlreadyExecuted();
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        if (isConfirmed[_txIndex][msg.sender]) revert HashWallet__TxAlreadyConfirmed();
        _;
    }

    constructor(address[] memory _owners) {
        _setRoleAdmin(SUPER_ADMIN, SUPER_ADMIN);
        _grantRole(SUPER_ADMIN, msg.sender);
        _setRoleAdmin(ADMIN, SUPER_ADMIN);

        uint256 ownersLength = _owners.length;
        if (ownersLength <= 0) revert HashWallet__NotEnoughOwners();

        if (ownersLength > 5 || ownersLength < 3) {
            revert HashWallet__InvalidOwnersLength();
        }

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            if (owner == address(0)) revert HashWallet__AddressZero();
            if (isOwner[owner]) revert HashWallet__AddressNotUnique();

            isOwner[owner] = true;
            _grantRole(ADMIN, _owners[i]);
            owners.push(owner);
        }

        numConfirmationsRequired = (ownersLength / 2) + 1;
    }

    function submitTransaction(address _to, uint256 _value, bytes memory _data) public onlyOwner {
        if (address(_to) == address(0)) revert HashWallet__AddressZero();
        uint256 txIndex = numOfTransactions;

        // transactions.push(Transaction({to: _to, value: _value, data: _data, executed: false, numConfirmations: 0}));
        transactions[txIndex] = Transaction({to: _to, value: _value, data: _data, executed: false, numConfirmations: 0});

        numOfTransactions++;

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        if (transaction.numConfirmations < numConfirmationsRequired) revert HashWallet__InvallidPermissionNumber();

        transaction.executed = true;

        (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);
        if (!success) revert HashWallet__TxFailed();

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        if (!isConfirmed[_txIndex][msg.sender]) revert HashWallet__TxNotConfirmed();

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function addOwner(bytes32 role, address account) public {
        if (owners.length >= 5) {
            revert HashWallet__InvalidOwnersLength();
        }
        super.grantRole(role, account);
        owners.push(account);
        isOwner[account] = true;

        numConfirmationsRequired = (owners.length / 2) + 1;
    }

    function removeOwner(bytes32 role, address account) public {
        if (owners.length <= 3) {
            revert HashWallet__InvalidOwnersLength();
        }
        super.revokeRole(role, account);

        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == account) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                isOwner[account] = false;
                break;
            }
        }

        numConfirmationsRequired = (owners.length / 2) + 1;
    }

    function transferOwner(bytes32 role, address newOwner) public {
        if (!hasRole(role, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, role);
        }
        
        _revokeRole(role, msg.sender);
        _grantRole(role, newOwner);

        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == msg.sender) {
                owners[i] = newOwner;
                isOwner[msg.sender] = false;
                isOwner[newOwner] = true;
                break;
            }
        }
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) public onlyRole(getRoleAdmin(role)) {
        _setRoleAdmin(role, adminRole);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return numOfTransactions;
    }

    function getTransaction(uint256 _txIndex)
        public
        view
        returns (address to, uint256 value, bytes memory data, bool executed, uint256 numConfirmations)
    {
        Transaction storage transaction = transactions[_txIndex];

        return (transaction.to, transaction.value, transaction.data, transaction.executed, transaction.numConfirmations);
    }
}
