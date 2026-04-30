// SPDX-License-Identifier: MIT                                                                                                                                                       
pragma solidity ^0.8.0;                                                                                                                                                               
                                                                                                                                                                                    
abstract contract AccessControl {                                                                                                                                                     
    address public admin;                                                                                                                                                             
    address public pendingAdmin;                          
    mapping(address => bool) public registeredVoters;
    address[] private voterList;                                                                                                                                                      

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

    function registerVoter(address _voter) external onlyAdmin {                                                                                                                       
        require(!registeredVoters[_voter], "Auth: Voter already registered");
        registeredVoters[_voter] = true;
        voterList.push(_voter);                                                                                                                                                       
        emit VoterRegistered(_voter);
    }

    function getVoters() external view returns (address[] memory) {
        return voterList;
    }

    function getVoterCount() external view returns (uint256) {
        return voterList.length;
    }
}