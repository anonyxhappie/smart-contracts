// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Scholarship is Initializable, AccessControlUpgradeable, PausableUpgradeable  {
    IERC721 public RACE;

    bytes32 public constant CEO = keccak256("CEO");
    bytes32 public constant CTO = keccak256("CTO");
    bytes32 public constant CFO = keccak256("CFO");
    address internal _safe = 0xd8806d66E24b702e0A56fb972b75D24CAd656821;

    struct Holder {
        address manager;
        address scholar;
        uint racerId;
    }
    mapping(uint256 => Holder) public holders;

    event RacerAssignEvent(bool _event, uint8 role, address from, address to, uint tokenId, uint timestamp);
    // _event - true/assign, false/withdraw
    // role - 1/manager, 2/scholar

    function initialize(address _RACE) public initializer {
        RACE = IERC721(_RACE);
    }
    
    modifier validate() {
        require(
            hasRole(CEO, msg.sender) ||
                hasRole(CFO, msg.sender) ||
                hasRole(CTO, msg.sender),
            "AccessControl: Address does not have valid Rights"
        );
        _;
    }

    modifier onlyOwner(uint _tokenId) {
        require(
            RACE.ownerOf(_tokenId) == msg.sender,
            "AccessControl: Address does not have valid Rights");
        _;
    }

    modifier ownerOrManager(uint _tokenId) {
        require(
            RACE.ownerOf(_tokenId) == msg.sender ||
            holders[_tokenId].manager == msg.sender,
            "AccessControl: Address does not have valid Rights");
        _;
    }

    function assignToManager(address _manager, uint _tokenId) public onlyOwner(_tokenId) {
        holders[_tokenId].manager = _manager;   
        holders[_tokenId].racerId = _tokenId;    
        emit RacerAssignEvent(true, 1, msg.sender, _manager, _tokenId, block.timestamp);
    }

    function assignToScholar(address _scholar, uint _tokenId) public ownerOrManager(_tokenId) {
        holders[_tokenId].scholar = _scholar;
        holders[_tokenId].racerId = _tokenId;    
        emit RacerAssignEvent(true, 2, msg.sender, _scholar, _tokenId, block.timestamp);
    }

    function withdrawFromManager(uint _tokenId) public onlyOwner(_tokenId) {
        require (holders[_tokenId].manager != address(0), "Scholarship: Racer is not assigned to any manager.");
        address _manager = holders[_tokenId].manager;
        holders[_tokenId].manager = address(0);
        emit RacerAssignEvent(false, 1, msg.sender, _manager, _tokenId, block.timestamp);
    }

    function withdrawFromScholar(uint _tokenId) public ownerOrManager(_tokenId) {
        require (holders[_tokenId].scholar != address(0), "Scholarship: Racer is not assigned to any scholar.");
        address _scholar = holders[_tokenId].scholar;
        holders[_tokenId].scholar = address(0);
        emit RacerAssignEvent(false, 2, msg.sender, _scholar, _tokenId, block.timestamp);
    }

    function withdrawFromAll(uint _tokenId) public onlyOwner(_tokenId) {
        address _manager = holders[_tokenId].manager;
        address _scholar = holders[_tokenId].scholar;
        holders[_tokenId].manager = address(0);
        holders[_tokenId].scholar = address(0);
        emit RacerAssignEvent(false, 1, msg.sender, _manager, _tokenId, block.timestamp);
        emit RacerAssignEvent(false, 2, msg.sender, _scholar, _tokenId, block.timestamp);
    }

}

interface IERC721 {
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    
    function balanceOf(address _owner) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);
    function safeMint(address to, uint256 tokenId) external;
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function approve(address _approved, uint256 _tokenId) external payable;
    function setApprovalForAll(address _operator, bool _approved) external;
    function getApproved(uint256 _tokenId) external view returns (address);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}
