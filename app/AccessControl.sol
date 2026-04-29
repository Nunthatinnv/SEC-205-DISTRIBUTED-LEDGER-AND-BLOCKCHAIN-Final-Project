// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract AccessControl {
    address public admin;
    address public pendingAdmin;
    mapping(address => bool) public registeredVoters;

    event AdminTransferInitiated(address indexed currentAdmin, address indexed pendingAdmin);
    event AdminTransferred(address indexed oldAdmin, address indexed newAdmin);
    event VoterRegistered(address voter);

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Auth: Caller is not admin");
        _;
    }

    // Fix #6: Two-step admin transfer — prevents accidental loss of admin to wrong address
    function transferAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Auth: Invalid address");
        pendingAdmin = _newAdmin;
        emit AdminTransferInitiated(admin, _newAdmin);
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Auth: Caller is not pending admin");
        emit AdminTransferred(admin, pendingAdmin);
        admin = pendingAdmin;
        pendingAdmin = address(0);
    }

    // Fix #8: Reject duplicate registration to avoid misleading events
    function registerVoter(address _voter) external onlyAdmin {
        require(!registeredVoters[_voter], "Auth: Voter already registered");
        registeredVoters[_voter] = true;
        emit VoterRegistered(_voter);
    }
}
