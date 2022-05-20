//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract DAO is AccessControl {
    bytes32 public constant CHAIR_MAN = keccak256("CHAIR_MAN");
    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");

    using SafeERC20 for IERC20;
    address public chairMan;
    IERC20 public voteToken; 

    uint256 public minQ;
    uint256 public debatePeriod;
    uint256 private propId = 0;

    struct Voters {
        uint256 depositedAmount;
        mapping(uint256 => uint256) voteCount;
        uint256 depositPeriod;
    }

    struct Proposals {
        address recipient;
        bytes callData;
        string description;
        uint256 timeStamp;
        mapping(bool => uint256) position;
    }

    mapping(address => Voters) public voters;
    mapping(uint256 => Proposals) public proposals;

    constructor(address _chairMan, address _voteTokenAddress, uint256 _minQ, uint256 _dabatePeriod) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CHAIR_MAN, _chairMan);
        _grantRole(DAO_ROLE, address(this));

        chairMan = _chairMan;
        voteToken = IERC20(_voteTokenAddress);
        minQ = _minQ;
        debatePeriod = _dabatePeriod;
    }

    function updateChairMan(address _chairMan) external onlyRole(DEFAULT_ADMIN_ROLE) returns(bool) {
        _grantRole(CHAIR_MAN, _chairMan);

        chairMan = _chairMan;

        return true;
    }

    function updateProposalParams(
        address _voteTokenAddress, 
        uint256 _minQ, 
        uint256 _dabatePeriod
    ) external onlyRole(DAO_ROLE) returns(bool) {
        voteToken = IERC20(_voteTokenAddress);
        minQ = _minQ;
        debatePeriod = _dabatePeriod;

        return true;
    }

    function deposit(uint256 amount) external returns(bool) {
        voteToken.safeTransferFrom(msg.sender, address(this), amount);
        voters[msg.sender].depositedAmount += amount;

        return true;
    }

    function addProposal(address recipient, bytes memory callData, string memory description) external onlyRole(CHAIR_MAN) returns(bool) {
        proposals[propId].recipient = recipient;
        proposals[propId].callData = callData;
        proposals[propId].description = description;
        proposals[propId].timeStamp = block.timestamp;        

        propId++;

        return true;
    }

    function vote(uint256 _propId, uint256 amount, bool position) external returns(bool) {
        require(proposals[_propId].timeStamp + debatePeriod >= block.timestamp, "Proposal doesn't exist!");
        require(voters[msg.sender].depositedAmount >= voters[msg.sender].voteCount[_propId] + amount, "Not enough votes!");

        proposals[_propId].position[position] += amount;
        voters[msg.sender].voteCount[_propId] += amount;

        return true;
    }

    function finishProposal(uint256 _propId) external returns(bool) {
        require(proposals[_propId].timeStamp != 0, "Proposal doesn't exist!");
        require(proposals[_propId].timeStamp + debatePeriod <= block.timestamp, "Too soon to finish!");
        require(proposals[_propId].position[true] + proposals[_propId].position[false] >= minQ, "MinQ doesnt reached!");


        if(proposals[_propId].position[true] >= proposals[_propId].position[false]) {
            (bool success, ) = proposals[_propId].recipient.call{value: 0}(
                proposals[_propId].callData
            );
            
            require(success, "ERROR call func");
        }
        
        return true;
    }

    function withdraw(uint256 amount) external returns(bool) {
        require(amount <= voters[msg.sender].depositedAmount, "No such amount deposited!");

        voteToken.safeTransfer(msg.sender, amount);

        return true;
    }

    function getProposalPositions(uint256 _propId, bool position) external view returns(uint256){
        return proposals[_propId].position[position];
    }

    function getVoterPositionForProposal(address voterAddress, uint256 _propId) external view returns(uint256){
        return voters[voterAddress].voteCount[_propId];
    }
}