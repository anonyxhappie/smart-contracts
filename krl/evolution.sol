// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Evolution is Initializable, ERC721HolderUpgradeable, AccessControlUpgradeable, PausableUpgradeable  {
    IERC20 public EOC;
    IERC721 public RACE;
    IERC721 public TRACE;

    uint256 private newLevelDiff;
    uint256 private levelOnePrice;
    uint256 private levelTwoPrice;
    uint256 private timeForWithdraw;

    bytes32 public constant CEO = keccak256("CEO");
    bytes32 public constant CTO = keccak256("CTO");
    bytes32 public constant CFO = keccak256("CFO");
    address internal _safe = 0xd8806d66E24b702e0A56fb972b75D24CAd656821;

    struct Log {
        address from;
        address to;
        uint tokenId;
        uint timestamp;
    }
    mapping(uint8 => uint256) public levels; // tracerId => deposit Log 
    mapping(uint256 => Log) public deposits; // tracerId => deposit Log 
    mapping(uint256 => Log) public withdraws; // tracerId => withdraw Log 
    event RacerDepositEvent(bool action, address from, address to, uint tokenId, uint timestamp);
    // _event - true/deposit, false/withdraw

    function initialize(address _EOC, address _RACE, address _TRACE) public initializer {
        EOC = IERC20(_EOC);
        RACE = IERC721(_RACE);
        TRACE = IERC721(_TRACE);
        newLevelDiff = 100000;
        levels[1] = 18000000 * 10 ** 18;
        levels[2] = 30000000 * 10 ** 18;
        timeForWithdraw = 5 * 1 days;
        
        _setupRole(DEFAULT_ADMIN_ROLE, _safe);
        _setupRole(CEO, address(0x47c06B50C2a6D28Ce3B130384b19a8929f414030));
        _setupRole(CFO, _safe);
        _setupRole(CTO, address(0x5a1a41d613676780f6E9684F1C9Fb89e116013f2));
        // _setupRole(CTO, msg.sender);
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

    function setLevelPrice(uint8 _level, uint _price) public validate {
        levels[_level] = _price;
    }

    function getLevelPrice(uint8 _level) public view returns (uint256) {
        return levels[_level];
    }

    function setNewLevelDiff(uint _newLevelDiff) public validate {
        newLevelDiff = _newLevelDiff;
    }

    function getNewLevelDiff() public view returns (uint256) {
        return newLevelDiff;
    }

    function setTimeForWithdraw(uint _timeForWithdraw) public validate {
        timeForWithdraw = _timeForWithdraw;
    }

    function getTimeForWithdraw() public view returns (uint256) {
        return timeForWithdraw;
    }

    function deposit(uint256 _tokenId) public {
        require(_tokenId < newLevelDiff * 3, "Evolution: Max upgrade limit reached for this Racer");
        require(RACE.ownerOf(_tokenId) == msg.sender, "Evolution: Not authorized to deposit this Racer");
        uint256 _levelPrice = _tokenId / newLevelDiff + 1;
        require(EOC.balanceOf(msg.sender) >= _levelPrice, "Evolution: Insufficient funds");
        
        // transfer 5% to _safe & burn rest
        uint256 _fivePercent = _levelPrice * 5 / 100;
        EOC.transferFrom(msg.sender, address(this), _levelPrice);
        EOC.transfer(_safe, _fivePercent);
        EOC.burn(address(this), _levelPrice - _fivePercent);
        // deposit NFT once in the contract by the user.
        RACE.safeTransferFrom(msg.sender, address(this), _tokenId);
        // mint dummy NFT (reciept) in the depositers wallet. ERC721.
        TRACE.safeMint(msg.sender, _tokenId);
        deposits[_tokenId] = Log(msg.sender, address(this), _tokenId, block.timestamp);
        emit RacerDepositEvent(true, msg.sender, address(this), _tokenId, block.timestamp);
    }

    function withdraw(uint256 _tokenId) public {
        require(TRACE.ownerOf(_tokenId) == msg.sender, "Evolution: Not authorized to withdraw this TRacer");
        require(block.timestamp >= deposits[_tokenId].timestamp + timeForWithdraw, "Evolution: Tracer can not be withdrawn currently");
        // deposit, dummy NFT in the contract by the withdsdastdyasfdyashg
        TRACE.safeTransferFrom(msg.sender, address(this), _tokenId);
        // original NFT gets sent to original depositer.
        RACE.safeTransferFrom(address(this), deposits[_tokenId].from, _tokenId); 

        // mint a new racer - Evolved character 100k+
        RACE.safeMint(msg.sender, _tokenId + newLevelDiff);
        withdraws[_tokenId] = Log(msg.sender, address(this), _tokenId, block.timestamp);
        emit RacerDepositEvent(false, msg.sender, deposits[_tokenId].from, _tokenId, block.timestamp);
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
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function approve(address _approved, uint256 _tokenId) external payable;
    function setApprovalForAll(address _operator, bool _approved) external;
    function getApproved(uint256 _tokenId) external view returns (address);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}
