// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Marketplace2_0 is Initializable, AccessControlUpgradeable, ERC721HolderUpgradeable, PausableUpgradeable  {
    IERC721 public RACE;
    IERC20 public KRL;

    bytes32 public constant CEO = keccak256("CEO");
    bytes32 public constant CTO = keccak256("CTO");
    bytes32 public constant CFO = keccak256("CFO");
    address internal _safe = 0xd8806d66E24b702e0A56fb972b75D24CAd656821;
    uint8 public constant LISTED = 1;
    uint8 public constant SOLD = 2;
    uint8 public constant DELISTED = 3;

    struct Trade {
        uint8 status; // 1  - listed, 2 - sold, 3 - delisted
        address seller;
        address buyer;
        uint price;
        uint racerId;
        uint timestamp;
    }
    mapping(uint256 => Trade) public trades;
    event RacerTradeEvent(uint8 status, address seller, address buyer, uint price, uint tokenId, uint timestamp);

    function initialize(address _RACE, address _KRL) public initializer {
        RACE = IERC721(_RACE);
        KRL = IERC20(_KRL);
        
        __AccessControl_init();
        __Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _safe);
        _setupRole(CEO, address(0x47c06B50C2a6D28Ce3B130384b19a8929f414030));
        _setupRole(CFO, _safe);
        _setupRole(CTO, address(0x5a1a41d613676780f6E9684F1C9Fb89e116013f2));
    }
    
    modifier onlyOwner(uint _tokenId) {
        require(
            RACE.ownerOf(_tokenId) == msg.sender,
            "AccessControl: Address does not have valid Rights");
        _;
    }

    function listRacer(uint _tokenId, uint _price) public onlyOwner(_tokenId) {
        trades[_tokenId].seller = msg.sender;
        trades[_tokenId].buyer = address(0);
        trades[_tokenId].status = LISTED;
        trades[_tokenId].price = _price;
        trades[_tokenId].racerId = _tokenId;   
        trades[_tokenId].timestamp = block.timestamp;
        RACE.safeTransferFrom(msg.sender, address(this), _tokenId);
        emit RacerTradeEvent(LISTED, msg.sender, address(0) , _tokenId, _price, block.timestamp);
    }

    function delistRacer(uint _tokenId) public {
        require(trades[_tokenId].status == LISTED, "TR: Racer not listed");
        require(trades[_tokenId].seller == msg.sender, "TR: Unauthorized");
        RACE.safeTransferFrom(address(this), msg.sender, _tokenId);
        
        trades[_tokenId].status = DELISTED;
        trades[_tokenId].timestamp = block.timestamp;
        emit RacerTradeEvent(DELISTED, msg.sender, address(0) , _tokenId, trades[_tokenId].price, block.timestamp);
    }

    function buyRacer(uint _tokenId) public {
        require(trades[_tokenId].status == LISTED, "TR: Racer not listed");
        require(KRL.balanceOf(msg.sender) >= trades[_tokenId].price, "TR: Insufficient funds");
        
        // transfer 5% to _safe & send rest to owner
        uint256 _fivePercent = trades[_tokenId].price * 5 / 100;
        KRL.transferFrom(msg.sender, address(this), trades[_tokenId].price);
        KRL.transfer(_safe, _fivePercent);
        KRL.transfer(trades[_tokenId].seller, trades[_tokenId].price - _fivePercent);
        RACE.safeTransferFrom(address(this), msg.sender, _tokenId);
        
        trades[_tokenId].buyer = msg.sender;
        trades[_tokenId].status = SOLD;
        trades[_tokenId].timestamp = block.timestamp;
        emit RacerTradeEvent(SOLD, trades[_tokenId].seller, msg.sender, _tokenId, trades[_tokenId].price, block.timestamp);
    }

}

interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    function burn(address account, uint amount) external;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

interface IERC721 {
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    
    function balanceOf(address _owner) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);
    function safeMint(address to, uint256 tokenId) external;
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function safeTransfer(address _to, uint256 _tokenId) external payable;
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function approve(address _approved, uint256 _tokenId) external payable;
    function setApprovalForAll(address _operator, bool _approved) external;
    function getApproved(uint256 _tokenId) external view returns (address);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}
